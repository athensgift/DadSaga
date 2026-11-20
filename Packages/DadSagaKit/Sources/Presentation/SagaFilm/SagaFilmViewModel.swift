import Application
import Domain
import Foundation
import Localization
import Observation

/// Presenter for the film sheet (ADR-0036, ADR-0037 §4): the dad chooses a child, a period, a format and the music
/// (ADR-0046), the film is made, and he watches and shares it. It builds the film's script and hands it to a
/// `SagaFilmRendering`, and plays music through a `SagaMusicPreviewing`, so it knows nothing of how a film is drawn or
/// a sound played.
@MainActor
@Observable
public final class SagaFilmViewModel: Identifiable {
    /// What the sheet reads and remembers.
    public struct UseCases: Sendable {
        let getFilm: any GetSagaFilmUseCase
        let setDates: any SetSagaFilmDatesUseCase
        let setMusic: any SetSagaFilmMusicUseCase
        /// Chooses the film's further photos as it is made (ADR-0047 §2).
        let choosePhotos: any ChooseSagaFilmPhotosUseCase

        public init(
            getFilm: any GetSagaFilmUseCase,
            setDates: any SetSagaFilmDatesUseCase,
            setMusic: any SetSagaFilmMusicUseCase,
            choosePhotos: any ChooseSagaFilmPhotosUseCase
        ) {
            self.getFilm = getFilm
            self.setDates = setDates
            self.setMusic = setMusic
            self.choosePhotos = choosePhotos
        }
    }

    public private(set) var state: SagaFilmViewState = .loading
    /// The sheet's title, whatever it shows.
    public var title: String { strings.text("Saga film") }

    /// The film last asked for, so "Try again" asks for the same one.
    private var request: SagaFilmRequest
    private let useCases: UseCases
    private let renderer: any SagaFilmRendering
    private let previewer: any SagaMusicPreviewing
    private let locale: Locale
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    /// What the choices are about; `nil` until it has loaded.
    private var film: SagaFilm?
    private var format = SagaFilmFormat.vertical
    /// The dates switch: taken from the first film loaded, then the sheet's own, so another child or period doesn't
    /// reset it (ADR-0041 §5). `nil` until a film has loaded.
    private var showsDates: Bool?
    /// The chosen track: taken from the first film loaded, then the sheet's own, like `showsDates` (ADR-0046 §4).
    private var soundtrackID: String?
    /// The last save of a choice, so dates and music are saved one after another and the newest wins.
    private var saving: Task<Void, Never>?
    /// The track playing for the dad to hear, if any (ADR-0046 §3).
    private var listening: Task<Void, Never>?
    /// Counts the previews started, so one ending late never clears a newer one.
    private var listens = 0
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
    /// How long the button plays a track's start.
    private static let previewSeconds = 20.0

    public init(
        request: SagaFilmRequest,
        useCases: UseCases,
        renderer: any SagaFilmRendering,
        previewer: any SagaMusicPreviewing,
        locale: Locale = .current,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.request = request
        self.useCases = useCases
        self.renderer = renderer
        self.previewer = previewer
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
              let period = film.choosablePeriods.first(where: { $0.choiceID == id })
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
        return save { [setDates = useCases.setDates] in await setDates.execute(showsDates: showsDates) }
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
        stopListening()
        let builder = SagaFilmScriptBuilder(locale: locale, calendar: calendar)
        let format = format
        let showsDates = showsDates ?? film.showsDates
        let music = music ?? film.soundtrack
        state = .making(making(progress: 0))
        // The further photos are chosen first, only as the film is made (ADR-0047 §4); the sheet showed the same
        // scenes, so nothing on it changes.
        let task = Task { [choosePhotos = useCases.choosePhotos, renderer, weak self] in
            let chosen = await choosePhotos.execute(film)
            let script = builder.script(
                for: chosen, format: format, reduceMotion: reduceMotion, showsDates: showsDates, music: music
            )
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
                    note: setupBuilder.keepingNote,
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
        stopListening()
        switch state {
        case .making:
            leftTheApp = true
            filmTask?.cancel()
        case .ready:
            guard let failedAt, now().timeIntervalSince(failedAt) <= Self.leavingGrace else { return refreshChoices() }
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
        let preview = listening
        stopListening()
        await preview?.value
        let task = filmTask
        filmTask = nil
        task?.cancel()
        _ = await task?.result
        switch state {
        case .making, .made: showChoices(notice: nil)
        case .ready: refreshChoices()
        case .loading, .unavailable: break
        }
        await renderer.discardFilms()
    }

    // MARK: Building

    private var strings: Strings { Strings(locale: locale) }

    private var leftNotice: String {
        strings.text("The film stopped when you left DadSaga.")
    }

    private var setupBuilder: SagaFilmSetupBuilder {
        SagaFilmSetupBuilder(locale: locale, calendar: calendar)
    }

    /// The chosen track, or the film's own until one is chosen; `nil` until a film has loaded.
    private var music: Soundtrack? {
        guard let film else { return nil }
        return film.soundtracks.first { $0.id == soundtrackID } ?? film.soundtrack
    }

    private func load(_ request: SagaFilmRequest) async {
        loads += 1
        let current = loads
        self.request = request
        let film = try? await useCases.getFilm.execute(childID: request.childID, period: request.period, on: now())
        guard current == loads else { return }
        guard let film else { return showUnavailable() }
        self.film = film
        if showsDates == nil { showsDates = film.showsDates }
        if soundtrackID == nil { soundtrackID = film.soundtrack.id }
        showChoices(notice: nil)
    }

    private func showUnavailable() {
        stopListening()
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
        guard let film, let music else { return }
        state = .ready(setupBuilder.setup(for: film, choices: choices(music: music, of: film)))
    }

    /// Shows the choices as they are now, keeping the notice and when the last film failed.
    private func refreshChoices() {
        guard case .ready = state, let film, let music else { return }
        state = .ready(setupBuilder.setup(for: film, choices: choices(music: music, of: film)))
    }

    private func choices(music: Soundtrack, of film: SagaFilm) -> SagaFilmChoices {
        SagaFilmChoices(
            format: format,
            showsDates: showsDates ?? film.showsDates,
            music: music,
            isListening: listening != nil,
            notice: notice
        )
    }

    /// Saves after the save before, so the newest choice is the one kept.
    private func save(_ operation: @escaping @Sendable () async -> Void) -> Task<Void, Never> {
        let previous = saving
        let task = Task {
            await previous?.value
            await operation()
        }
        saving = task
        return task
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
}

// MARK: - Music

/// Choosing and hearing the film's music (ADR-0046 §2, §3).
extension SagaFilmViewModel {
    /// Chooses the film's music and remembers it for the next films. A track playing switches to the new one, from
    /// its start; nothing starts playing otherwise. The returned task ends once this choice is saved.
    @discardableResult
    public func selectMusic(id: String) -> Task<Void, Never>? {
        guard case .ready = state, let film, id != music?.id,
              let track = film.soundtracks.first(where: { $0.id == id })
        else { return nil }
        soundtrackID = id
        if listening != nil {
            stopListening()
            startListening(track.audioURL)
        }
        showChoices(notice: nil)
        return save { [setMusic = useCases.setMusic] in await setMusic.execute(soundtrackID: id) }
    }

    /// Plays the chosen track's start, as the film will open (ADR-0046 §3). Nothing plays until the dad asks.
    public func listenToMusic() {
        guard case .ready = state, listening == nil, let music else { return }
        startListening(music.audioURL)
        refreshChoices()
    }

    public func stopMusic() {
        guard listening != nil else { return }
        stopListening()
        refreshChoices()
    }

    private func startListening(_ url: URL) {
        listens += 1
        let current = listens
        listening = Task { [previewer, weak self] in
            await previewer.play(url, seconds: Self.previewSeconds)
            self?.endListening(current)
        }
    }

    /// A preview that played to its end offers listening again, unless a newer one started meanwhile.
    private func endListening(_ current: Int) {
        guard current == listens else { return }
        listening = nil
        refreshChoices()
    }

    private func stopListening() {
        listens += 1
        listening?.cancel()
        listening = nil
    }
}
