import Application
import Domain
import Foundation
import Localization
import Observation

/// Presenter for the film sheet (ADR-0036, ADR-0037 §4): the dad chooses a child, a period and a format, the film is
/// made, and he watches and shares it. It builds the film's script and hands it to a `SagaFilmRendering`, so it knows
/// nothing of how a film is drawn or written.
@MainActor
@Observable
public final class SagaFilmViewModel: Identifiable {
    public private(set) var state: SagaFilmViewState = .loading
    /// The sheet's title, whatever it shows.
    public var title: String { strings.text("Saga film") }

    /// The film last asked for, so "Try again" asks for the same one.
    private var request: SagaFilmRequest
    private let getFilm: any GetSagaFilmUseCase
    private let setDates: any SetSagaFilmDatesUseCase
    private let choosePhotos: any ChooseSagaFilmPhotosUseCase
    private let renderer: any SagaFilmRendering
    private let locale: Locale
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    /// What the choices are about; `nil` until it has loaded.
    private var film: SagaFilm?
    private var format = SagaFilmFormat.vertical
    /// The dates switch: taken from the first film loaded, then the sheet's own, so another child or period doesn't
    /// reset it (ADR-0041 §5). `nil` until a film has loaded.
    private var showsDates: Bool?
    /// The last save of the switch, so saves run one after another and the newest wins.
    private var savingDates: Task<Void, Never>?
    /// Why the last film wasn't finished, shown over the choices until the dad changes one or makes it again.
    private var notice: String?
    private var filmTask: Task<(url: URL, script: SagaFilmScript), any Error>?
    /// Counts the films started, so progress and results of an earlier one are never shown for a later one.
    private var generation = 0
    /// Counts the films asked for, so only the newest answer is shown, and none once a film is being made.
    private var loads = 0
    private var leftTheApp = false
    /// When the last film failed for a reason the sheet didn't know, while the choices still say so.
    private var failedAt: Date?
    /// iOS stops an app's drawing as it leaves the screen, so a film can fail a moment before the sheet hears that
    /// the app left. For this long after a failure, the app going to the background still explains it.
    private static let leavingGrace: TimeInterval = 3

    public init(
        request: SagaFilmRequest,
        getFilm: any GetSagaFilmUseCase,
        setDates: any SetSagaFilmDatesUseCase,
        choosePhotos: any ChooseSagaFilmPhotosUseCase,
        renderer: any SagaFilmRendering,
        locale: Locale = .current,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.request = request
        self.getFilm = getFilm
        self.setDates = setDates
        self.choosePhotos = choosePhotos
        self.renderer = renderer
        self.locale = locale
        self.calendar = calendar
        self.now = now
    }

    /// Loads the film the sheet was opened for. Appearing again, from under the share sheet say, changes nothing.
    public func onAppear() async {
        guard case .loading = state else { return }
        await load(request)
    }

    /// Tries again after the film couldn't be read.
    public func reload() async {
        guard case .unavailable = state else { return }
        await load(request)
    }

    /// Another child's film, for the period the day suggests for them.
    public func selectChild(id: UUID) async {
        guard case .ready = state, id != film?.child.id else { return }
        await load(SagaFilmRequest(childID: id, period: nil))
    }

    public func selectPeriod(id: String) async {
        guard case .ready = state, let film, id != film.period.choiceID,
              let period = periods(of: film).first(where: { $0.choiceID == id })
        else { return }
        await load(SagaFilmRequest(childID: film.child.id, period: period))
    }

    public func selectFormat(_ format: SagaFilmFormat) {
        guard case .ready = state, format != self.format else { return }
        self.format = format
        showChoices(notice: nil)
    }

    /// Turns the film's dates on or off at once, and remembers it for the next films. Saves run one after another,
    /// so the newest choice is the one kept; the returned task ends once this one is saved.
    @discardableResult
    public func setShowsDates(_ showsDates: Bool) -> Task<Void, Never>? {
        guard case .ready = state, showsDates != self.showsDates else { return nil }
        self.showsDates = showsDates
        showChoices(notice: nil)
        let previous = savingDates
        let saving = Task { [setDates] in
            await previous?.value
            await setDates.execute(showsDates: showsDates)
        }
        savingDates = saving
        return saving
    }

    /// Makes the film of the choices on screen and shows it. Returns once it is made, cancelled or has failed.
    ///
    /// - Parameter reduceMotion: the system's Reduce Motion as it is now; the film keeps its photos still (ADR-0036 §9).
    public func makeFilm(reduceMotion: Bool) async {
        guard case .ready(let setup) = state, setup.makeTitle != nil, let film else { return }
        generation += 1
        let current = generation
        // A choice still loading no longer counts: the film is of the choices on screen.
        loads += 1
        leftTheApp = false
        let builder = SagaFilmScriptBuilder(locale: locale, calendar: calendar)
        let format = format
        let showsDates = showsDates ?? film.showsDates
        state = .making(making(progress: 0))
        // The further photos are chosen first, only as the film is made (ADR-0046 §4); the sheet showed the same
        // scenes, so nothing on it changes.
        let task = Task { [choosePhotos, renderer, weak self] in
            let chosen = await choosePhotos.execute(film)
            let script = builder.script(for: chosen, format: format, reduceMotion: reduceMotion, showsDates: showsDates)
            let url = try await renderer.render(script) { [weak self] value in
                self?.show(progress: value, of: current)
            }
            return (url: url, script: script)
        }
        filmTask = task
        let result = await task.result
        // Closing the sheet meanwhile has already put the choices back and thrown the film away.
        guard generation == current else { return }
        filmTask = nil
        switch result {
        case .success(let made):
            state = .made(
                SagaFilmMade(
                    url: made.url,
                    title: made.script.title,
                    format: made.script.format,
                    shareTitle: strings.text("Share or save"),
                    note: keepingNote,
                    anotherTitle: strings.text("Make another")
                )
            )
        case .failure where leftTheApp:
            showChoices(notice: leftNotice)
        case .failure(let error) where error is CancellationError:
            showChoices(notice: nil)
        case .failure:
            showChoices(notice: strings.text("Couldn't make the film. Please try again."))
            failedAt = now()
        }
    }

    /// Stops the film being made and goes back to the choices, without a word.
    public func cancel() {
        filmTask?.cancel()
    }

    /// iOS doesn't draw for an app in the background, so the film stops; the choices then say why (ADR-0036 §10).
    public func appWentToBackground() {
        switch state {
        case .making:
            leftTheApp = true
            filmTask?.cancel()
        case .ready:
            guard let failedAt, now().timeIntervalSince(failedAt) <= Self.leavingGrace else { return }
            showChoices(notice: leftNotice)
        case .loading, .unavailable, .made:
            break
        }
    }

    /// From the finished film back to the choices. The film isn't kept.
    public func makeAnother() async {
        guard case .made = state else { return }
        // The film goes first, so nothing made after this can be deleted with it.
        await renderer.discardFilms()
        guard case .made = state else { return }
        showChoices(notice: nil)
    }

    /// The sheet was dismissed: stops a film being made, waits until it has stopped, and deletes every film. Safe to
    /// call more than once.
    public func close() async {
        generation += 1
        loads += 1
        let task = filmTask
        filmTask = nil
        task?.cancel()
        _ = await task?.result
        switch state {
        case .making, .made: showChoices(notice: nil)
        case .loading, .unavailable, .ready: break
        }
        await renderer.discardFilms()
    }

    // MARK: Building

    private var strings: Strings { Strings(locale: locale) }

    private var leftNotice: String {
        strings.text("The film stopped when you left DadSaga.")
    }

    private var keepingNote: String {
        strings.text("Made on this iPhone from your photos and notes. It isn't kept: share it or save it to Photos.")
    }

    private func load(_ request: SagaFilmRequest) async {
        loads += 1
        let current = loads
        self.request = request
        let film = try? await getFilm.execute(childID: request.childID, period: request.period, on: now())
        guard current == loads else { return }
        guard let film else { return showUnavailable() }
        self.film = film
        if showsDates == nil { showsDates = film.showsDates }
        showChoices(notice: nil)
    }

    private func showUnavailable() {
        state = .unavailable(
            SagaFilmNotice(
                message: strings.text("The film can't be made right now."),
                actionTitle: strings.text("Try again")
            )
        )
    }

    private func showChoices(notice: String?) {
        self.notice = notice
        failedAt = nil
        guard let film else { return }
        state = .ready(setup(for: film))
    }

    /// Progress only rises, and only for the film being made now.
    private func show(progress value: Double, of generation: Int) {
        guard generation == self.generation, case .making(let shown) = state, value > shown.progress else { return }
        state = .making(making(progress: min(1, value)))
    }

    private func making(progress: Double) -> SagaFilmMaking {
        SagaFilmMaking(
            title: strings.text("Making your film…"),
            progress: progress,
            progressText: progress.formatted(.percent.precision(.fractionLength(0)).locale(locale)),
            note: strings.text("Keep DadSaga open while it's made."),
            cancelTitle: strings.text("Cancel")
        )
    }

    private func setup(for film: SagaFilm) -> SagaFilmSetup {
        let texts = SagaFilmTexts(locale: locale, calendar: calendar)
        let children = film.profile.children
        let hasSomething = film.hasSomethingToShow
        return SagaFilmSetup(
            childLabel: strings.text("Child"),
            periodLabel: strings.text("Period"),
            formatLabel: strings.text("Format"),
            note: keepingNote,
            children: children.count > 1 ? children.map { SagaFilmChildChoice(id: $0.id, name: $0.name) } : [],
            selectedChildID: film.child.id,
            periods: periods(of: film).map { period in
                SagaFilmPeriodChoice(id: period.choiceID, title: texts.periodTitle(period, catalog: film.catalog))
            },
            selectedPeriodID: film.period.choiceID,
            formats: [
                SagaFilmFormatChoice(id: .vertical, title: strings.text("Vertical"), symbol: "rectangle.portrait"),
                SagaFilmFormatChoice(id: .wide, title: strings.text("Wide"), symbol: "rectangle")
            ],
            selectedFormat: format,
            datesLabel: strings.text("Dates in the film"),
            datesNote: strings.text(
                "Dates also tell how old your child is. Turn them off for a film you'll share beyond the family."
            ),
            showsDates: showsDates ?? film.showsDates,
            notice: notice,
            makeTitle: hasSomething ? strings.text(notice == nil ? "Make the film" : "Make it again") : nil,
            emptyMessage: hasSomething
                ? nil
                : strings.text("Photos and moments you capture will show up here as a film.")
        )
    }

    /// The periods on offer, and the film's own if it is not one of them (one with nothing in it), so the choice
    /// shown is always in the list.
    private func periods(of film: SagaFilm) -> [SagaPeriod] {
        let available = film.availablePeriods
        guard !available.contains(film.period) else { return available }
        return available.filter { $0 != .everything } + [film.period] + available.filter { $0 == .everything }
    }
}

private extension SagaFilm {
    /// A film needs a scene of its own or something for its credits: an opening and credits alone say nothing.
    var hasSomethingToShow: Bool {
        storyboard.scenes.contains { scene in
            switch scene.kind {
            case .entry, .photo: true
            case .credits(let credits): credits.questsDone > 0 || credits.bossesBeaten > 0
            case .opening, .chapter: false
            }
        }
    }
}

private extension SagaPeriod {
    /// Stable for a period, so a choice survives a reload: "year-2", "world-w2-plains", "everything".
    var choiceID: String {
        switch self {
        case .year(let number): "year-\(number)"
        case .world(let id): "world-\(id)"
        case .everything: "everything"
        }
    }
}
