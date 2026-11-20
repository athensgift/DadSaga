import Application
import Domain
import Foundation
import Presentation
import Synchronization

/// A saga for the film sheet's tests: Anna, two years and five days old, with a first year in the cave and a second
/// in the plains, and her baby brother with nothing yet.
enum FilmStub {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// 10 March 2024, 09:00 UTC.
    static let birth = Date(timeIntervalSince1970: 1_710_061_200)
    /// Five days after Anna's second birthday, at noon.
    static let today = Date(timeIntervalSince1970: 1_710_061_200 + (730 + 5) * 86_400 + 3 * 3_600)

    static let anna = Child(name: "Άννα", birthDate: birth, gender: .girl, skinTone: .medium)
    static let niko = Child(name: "Νίκος", birthDate: today.addingTimeInterval(-40 * 86_400))
    static let profile = PlayerProfile(children: [anna], heroClassID: "h-cool", dadSkinTone: .mediumDark)
    static let family = PlayerProfile(children: [anna, niko], heroClassID: "h-cool", dadSkinTone: .mediumDark)

    static let theme = Soundtrack(
        id: "theme", title: "Saga Theme", artist: "DadSaga", licence: .original,
        audioURL: URL(filePath: "/music/saga-theme.m4a")
    )

    static let catalog = ContentCatalog(
        worlds: [
            World(id: "w1", order: 1, title: LocalizedText(el: "Σπηλιά", en: "Cave"),
                  tagline: LocalizedText(el: "Οι πρώτες μέρες", en: "The early days"), minAgeMonths: 0, maxAgeMonths: 11),
            World(id: "w2", order: 2, title: LocalizedText(el: "Πεδιάδες", en: "Plains"),
                  tagline: LocalizedText(el: "Όλα κινούνται", en: "Everything moves"), minAgeMonths: 12, maxAgeMonths: nil)
        ],
        quests: [
            Quest(id: "q1", worldID: "w1", title: LocalizedText(el: "Βόλτα", en: "Walk"),
                  description: LocalizedText(el: "δ", en: "d"), skill: .care, xp: 20, minAgeMonths: 0)
        ],
        bosses: [
            BossFight(id: "b1", worldID: "w1", title: LocalizedText(el: "Πρώτος πυρετός", en: "First fever"),
                      intro: LocalizedText(el: "ι", en: "i"), guide: [],
                      badge: LocalizedText(el: "Πυρετομάχος", en: "Fever fighter"), skill: .care, xp: 100, minAgeMonths: 0)
        ],
        firsts: [
            FirstMoment(id: "f-smile", order: 1, emoji: "😊", title: LocalizedText(el: "Πρώτο χαμόγελο", en: "First smile"),
                        xp: 30, companionTrait: "smile"),
            FirstMoment(id: "f-steps", order: 2, emoji: "👣", title: LocalizedText(el: "Πρώτα βήματα", en: "First steps"),
                        xp: 40, companionTrait: "walk")
        ],
        heroClasses: [
            HeroClass(id: "h-cool", order: 1, title: LocalizedText(el: "Cool Μπαμπάς", en: "Cool Dad"),
                      tagline: LocalizedText(el: "τ", en: "t"), look: "cool")
        ],
        gear: [
            GearItem(id: "g1", skill: .care, minXP: 50, look: "burpCloth", title: LocalizedText(el: "Πανάκι", en: "Burp cloth"))
        ]
    )

    static func months(_ count: Int) -> Date {
        calendar.date(byAdding: .month, value: count, to: birth) ?? birth
    }

    /// Year one: a smile with a note and a photo, two walks (one with a photo) and a boss. Year two: first steps with
    /// neither note nor photo, and two walks (one with a photo).
    static let annasSaga: [ProgressEvent] = [
        ProgressEvent(kind: .first(id: "f-smile"), childID: anna.id, date: months(2),
                      note: "Χαμογέλασε στον παππού", photoID: "p-smile"),
        ProgressEvent(kind: .quest(id: "q1"), childID: anna.id, date: months(3), photoID: "p-walk-1"),
        ProgressEvent(kind: .quest(id: "q1"), childID: anna.id, date: months(4)),
        ProgressEvent(kind: .boss(id: "b1"), childID: anna.id, date: months(6)),
        ProgressEvent(kind: .first(id: "f-steps"), childID: anna.id, date: months(14)),
        ProgressEvent(kind: .quest(id: "q1"), childID: anna.id, date: months(15), photoID: "p-walk-2"),
        ProgressEvent(kind: .quest(id: "q1"), childID: anna.id, date: months(20))
    ]
}

/// The film's query from stubs. The scenes, the periods on offer and the default period come from the real Domain
/// rules, so the sheet's tests follow the same rules as the app.
/// The film dates switch in memory, shared by the fake query and the sheet's set use case: on until set.
final class FakeSagaFilmDates: SagaFilmDatesRepository, Sendable {
    private let stored = Mutex<Bool?>(nil)
    /// Every value saved, in order.
    private let saved = Mutex<[Bool]>([])

    var saves: [Bool] { saved.withLock(\.self) }

    func showsDates() async -> Bool { stored.withLock { $0 ?? true } }

    func setShowsDates(_ showsDates: Bool) async {
        stored.withLock { $0 = showsDates }
        saved.withLock { $0.append(showsDates) }
    }
}

actor FakeGetSagaFilm: GetSagaFilmUseCase {
    nonisolated let dates: FakeSagaFilmDates
    private let profile: PlayerProfile?
    private let events: [ProgressEvent]
    private var soundtrack: Soundtrack?
    /// The period of every film asked for; `nil` leaves it to the day.
    private(set) var asked: [SagaPeriod?] = []
    /// Yields when a held answer has been asked for.
    nonisolated let reached: AsyncStream<Void>
    private var holdsNext = false
    private let reachedSignal: AsyncStream<Void>.Continuation
    private let release: AsyncStream<Void>
    private let releaseSignal: AsyncStream<Void>.Continuation

    init(profile: PlayerProfile? = FilmStub.profile, events: [ProgressEvent] = FilmStub.annasSaga,
         soundtrack: Soundtrack? = FilmStub.theme, dates: FakeSagaFilmDates = FakeSagaFilmDates()) {
        self.dates = dates
        self.profile = profile
        self.events = events
        self.soundtrack = soundtrack
        (reached, reachedSignal) = AsyncStream.makeStream()
        (release, releaseSignal) = AsyncStream.makeStream()
    }

    /// The next film asked for is answered only after `letGo()`, like a slow store.
    func holdNext() {
        holdsNext = true
    }

    nonisolated func letGo() {
        releaseSignal.yield()
    }

    func bundle(_ soundtrack: Soundtrack) {
        self.soundtrack = soundtrack
    }

    func execute(childID: UUID?, period: SagaPeriod?, on date: Date) async throws -> SagaFilm? {
        asked.append(period)
        if holdsNext {
            holdsNext = false
            reachedSignal.yield()
            var waiting = release.makeAsyncIterator()
            _ = await waiting.next()
        }
        guard let profile, let child = profile.child(childID) else { return nil }
        guard let soundtrack else { throw SagaFilmError.noSoundtrack }
        let catalog = FilmStub.catalog
        let calendar = FilmStub.calendar
        let chosen = period
            ?? SagaOccasions.latest(for: child, events: events, catalog: catalog, on: date, calendar: calendar)?.period
            ?? .everything
        let storyboard = [chosen, .everything].lazy.compactMap { [events] in
            SagaStoryboard.make(events: events, child: child, period: $0, catalog: catalog, now: date, calendar: calendar)
        }.first
        guard let storyboard else { return nil }
        let progress = DadProgress(events: events.filter { $0.date < storyboard.asOf }, catalog: catalog)
        let firsts = progress.capturedFirstIDs(for: child.id)
        return SagaFilm(
            profile: profile,
            child: child,
            catalog: catalog,
            storyboard: storyboard,
            availablePeriods: SagaPeriod.available(
                for: child, events: events, catalog: catalog, now: date, calendar: calendar
            ),
            medalCount: progress.allDefeatedBossIDs.count,
            childFirsts: catalog.firsts.filter { firsts.contains($0.id) },
            equippedGear: catalog.gear.filter { (progress.skillXP[$0.skill] ?? 0) >= $0.minXP },
            soundtrack: soundtrack,
            showsDates: await dates.showsDates()
        )
    }
}

/// Stands in for the film's renderer: it keeps the scripts it is given and writes a small file where a film would
/// be. It can report progress and then wait, until the test lets it go or the film is cancelled, and it can fail.
actor FakeFilmRenderer: SagaFilmRendering {
    enum Ending {
        case film
        case failure
        /// Waits after its progress: `letGo()` finishes the film, cancelling stops it.
        case wait
    }

    nonisolated let folder = FileManager.default.temporaryDirectory
        .appending(path: "saga-film-fake-\(UUID().uuidString)", directoryHint: .isDirectory)
    /// Yields each time a render has reported all of its progress.
    nonisolated let reported: AsyncStream<Void>

    private(set) var scripts: [SagaFilmScript] = []
    private var ending = Ending.film
    private var steps: [Double] = [0.5, 1]
    private let reportedSignal: AsyncStream<Void>.Continuation
    private let release: AsyncStream<Void>
    private let releaseSignal: AsyncStream<Void>.Continuation

    init() {
        (reported, reportedSignal) = AsyncStream.makeStream()
        (release, releaseSignal) = AsyncStream.makeStream()
    }

    func end(_ ending: Ending, reporting steps: [Double] = [0.5, 1]) {
        self.ending = ending
        self.steps = steps
    }

    nonisolated func letGo() {
        releaseSignal.yield()
    }

    /// The films in the folder now, with symbolic links in their paths resolved.
    nonisolated var films: [URL] {
        let files = FileManager.default
        let folders = (try? files.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return folders
            .flatMap { (try? files.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)) ?? [] }
            .map { $0.resolvingSymlinksInPath() }
    }

    func render(_ script: SagaFilmScript, progress: @escaping @MainActor @Sendable (Double) -> Void) async throws -> URL {
        await discardFilms()
        scripts.append(script)
        for step in steps {
            await progress(step)
        }
        reportedSignal.yield()
        switch ending {
        case .film: break
        case .failure: throw StubError.boom
        case .wait:
            // Ends when the test lets go, or with `nil` when the task is cancelled.
            var waiting = release.makeAsyncIterator()
            _ = await waiting.next()
            try Task.checkCancellation()
        }
        let film = folder.appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: script.title + ".mp4", directoryHint: .notDirectory)
        try FileManager.default.createDirectory(at: film.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("film".utf8).write(to: film)
        return film
    }

    func discardFilms() async {
        try? FileManager.default.removeItem(at: folder)
    }
}
