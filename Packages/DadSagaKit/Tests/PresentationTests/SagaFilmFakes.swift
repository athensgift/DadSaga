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

    static let anna = Child(name: "Άννα", birthDay: CalendarDay(birth, in: .gmt), gender: .girl, skinTone: .medium)
    static let niko = Child(name: "Νίκος", birthDay: CalendarDay(today.addingTimeInterval(-40 * 86_400), in: .gmt))
    static let profile = PlayerProfile(children: [anna], heroClassID: "h-cool", dadSkinTone: .mediumDark)
    static let family = PlayerProfile(children: [anna, niko], heroClassID: "h-cool", dadSkinTone: .mediumDark)

    static let theme = Soundtrack(
        id: "theme",
        title: LocalizedText(el: "Το θέμα της ιστορίας", en: "Saga Theme"),
        mood: LocalizedText(el: "Απαλό και αισιόδοξο", en: "Gentle and hopeful"),
        artist: "DadSaga",
        licence: .original,
        audioURL: URL(filePath: "/music/saga-theme.m4a")
    )
    static let lullaby = Soundtrack(
        id: "lullaby",
        title: LocalizedText(el: "Νανούρισμα για μουσικό κουτί", en: "Music Box Lullaby"),
        mood: LocalizedText(el: "Τρυφερό και αργό, για ήσυχες στιγμές", en: "Tender and slow, for quiet moments"),
        artist: "DadSaga",
        licence: .original,
        audioURL: URL(filePath: "/music/music-box-lullaby.m4a")
    )
    /// The bundled tracks, in order: the first is the default.
    static let music = [theme, lullaby]

    static let catalog = ContentCatalog(
        worlds: [
            World(id: "w1", order: 1, title: LocalizedText(el: "Σπηλιά", en: "Cave"),
                  tagline: LocalizedText(el: "Οι πρώτες μέρες", en: "The early days"), span: .months(min: 0, max: 11)),
            World(id: "w2", order: 2, title: LocalizedText(el: "Πεδιάδες", en: "Plains"),
                  tagline: LocalizedText(el: "Όλα κινούνται", en: "Everything moves"), span: .months(min: 12, max: nil))
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
            GearItem(id: "g1", skill: .care, look: "burpCloth", title: LocalizedText(el: "Πανάκι", en: "Burp cloth"))
        ],
        titles: [
            DadTitle(id: "t0", order: 0, minCards: 0, minXP: 0, name: LocalizedText(el: "Σε αναμονή", en: "In waiting")),
            DadTitle(id: "t1", order: 1, minCards: 1, minXP: 20, gearIDs: ["g1"],
                     name: LocalizedText(el: "Νέος στο ταξίδι", en: "New to the journey")),
            DadTitle(id: "t2", order: 2, minCards: 5, minXP: 100, name: LocalizedText(el: "Σίγουρα χέρια", en: "Steady hands"))
        ]
    )

    static func months(_ count: Int) -> Date {
        calendar.date(byAdding: .month, value: count, to: birth) ?? birth
    }

    /// Year one: a smile with a note and a photo, two walks (one with a photo) and a boss. Year two: first steps with
    /// neither note nor photo, and two walks (one with a photo).
    static let annasSaga: [ProgressEvent] = [
        ProgressEvent(kind: .first(id: "f-smile"), childID: anna.id, date: months(2),
                      note: "Χαμογέλασε στον παππού", photoIDs: ["p-smile"]),
        ProgressEvent(kind: .quest(id: "q1"), childID: anna.id, date: months(3), photoIDs: ["p-walk-1"]),
        ProgressEvent(kind: .quest(id: "q1"), childID: anna.id, date: months(4)),
        ProgressEvent(kind: .boss(id: "b1"), childID: anna.id, date: months(6)),
        ProgressEvent(kind: .first(id: "f-steps"), childID: anna.id, date: months(14)),
        ProgressEvent(kind: .quest(id: "q1"), childID: anna.id, date: months(15), photoIDs: ["p-walk-2"]),
        ProgressEvent(kind: .quest(id: "q1"), childID: anna.id, date: months(20))
    ]
}

/// What the film sheet remembers, in memory, shared by the fake query and the sheet's set use cases: dates on and no
/// track until set.
final class FakeSagaFilmChoices: SagaFilmChoicesRepository, Sendable {
    enum Save: Equatable, Sendable {
        case dates(Bool)
        case music(String)
    }

    private let storedShowsDates = Mutex<Bool?>(nil)
    private let storedSoundtrackID = Mutex<String?>(nil)
    /// Every value saved, in order.
    private let saved = Mutex<[Save]>([])

    var saves: [Save] { saved.withLock(\.self) }

    func showsDates() async -> Bool { storedShowsDates.withLock { $0 ?? true } }

    func setShowsDates(_ showsDates: Bool) async {
        storedShowsDates.withLock { $0 = showsDates }
        saved.withLock { $0.append(.dates(showsDates)) }
    }

    func soundtrackID() async -> String? { storedSoundtrackID.withLock(\.self) }

    func setSoundtrackID(_ id: String) async {
        storedSoundtrackID.withLock { $0 = id }
        saved.withLock { $0.append(.music(id)) }
    }
}

/// The film's query from stubs. The scenes, the periods on offer and the default period come from the real Domain
/// rules, so the sheet's tests follow the same rules as the app.
actor FakeGetSagaFilm: GetSagaFilmUseCase {
    nonisolated let choices: FakeSagaFilmChoices
    private let profile: PlayerProfile?
    private let events: [ProgressEvent]
    private var soundtracks: [Soundtrack]
    /// The period of every film asked for; `nil` leaves it to the day.
    private(set) var asked: [SagaPeriod?] = []
    /// Yields when a held answer has been asked for.
    nonisolated let reached: AsyncStream<Void>
    private var holdsNext = false
    private let reachedSignal: AsyncStream<Void>.Continuation
    private let release: AsyncStream<Void>
    private let releaseSignal: AsyncStream<Void>.Continuation

    init(profile: PlayerProfile? = FilmStub.profile, events: [ProgressEvent] = FilmStub.annasSaga,
         soundtracks: [Soundtrack] = FilmStub.music, choices: FakeSagaFilmChoices = FakeSagaFilmChoices()) {
        self.choices = choices
        self.profile = profile
        self.events = events
        self.soundtracks = soundtracks
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

    func bundle(_ soundtracks: [Soundtrack]) {
        self.soundtracks = soundtracks
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
        // The remembered track, or the first, like the real query.
        guard let first = soundtracks.first else { throw SagaFilmError.noSoundtrack }
        let chosenID = await choices.soundtrackID()
        let soundtrack = soundtracks.first { $0.id == chosenID } ?? first
        let catalog = FilmStub.catalog
        let calendar = FilmStub.calendar
        let chosen = period
            ?? SagaOccasions.latest(for: child, events: events, catalog: catalog, on: date, timeZone: calendar.timeZone)?.period
            ?? .everything
        let storyboard = [chosen, .everything].lazy.compactMap { [events] in
            SagaStoryboard.make(
                events: events, child: child, period: $0, catalog: catalog, now: date, timeZone: calendar.timeZone
            )
        }.first
        guard let storyboard else { return nil }
        let progress = DadProgress(events: events.filter { $0.date < storyboard.asOf }, catalog: catalog)
        let firsts = progress.capturedFirstIDs(for: child.id)
        let standing = DadStanding.asOf(progress, catalog: catalog)
        return SagaFilm(
            profile: profile,
            child: child,
            catalog: catalog,
            storyboard: storyboard,
            availablePeriods: SagaPeriod.available(
                for: child, events: events, catalog: catalog, now: date, timeZone: calendar.timeZone
            ),
            medalCount: progress.allDefeatedBossIDs.count,
            childFirsts: catalog.firsts.filter { firsts.contains($0.id) },
            equippedGear: GearRules.equipped(standing.gear),
            title: standing.title,
            soundtracks: soundtracks,
            soundtrack: soundtrack,
            showsDates: await choices.showsDates()
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

/// Keeps the film's photos as the sheet showed them.
struct KeepFilmPhotos: ChooseSagaFilmPhotosUseCase {
    func execute(_ film: SagaFilm) async -> SagaFilm { film }
}

/// Finds the same subject in every photo, or none.
struct FixedPhotoSubject: FindPhotoSubjectUseCase {
    var subject: PhotoFraming?

    func execute(photo imageData: Data) async -> PhotoFraming? { subject }
}

/// Stands in for the music player: it keeps what it is asked to play, and each play sounds until the test finishes it
/// or its task is cancelled, like a preview stopped by the sheet.
@MainActor
final class FakeMusicPreviewer: SagaMusicPreviewing {
    /// Every track asked for, in order.
    private(set) var played: [URL] = []
    /// The track sounding now, if any.
    private(set) var sounding: URL?
    /// Yields each track as it starts.
    nonisolated let started: AsyncStream<URL>
    /// Yields each track once its play has returned, finished or stopped.
    nonisolated let returned: AsyncStream<URL>
    private var current: (number: Int, end: AsyncStream<Void>.Continuation)?
    private let startedSignal: AsyncStream<URL>.Continuation
    private let returnedSignal: AsyncStream<URL>.Continuation

    init() {
        (started, startedSignal) = AsyncStream.makeStream()
        (returned, returnedSignal) = AsyncStream.makeStream()
    }

    /// The track sounding now plays to its end.
    func finish() {
        current?.end.finish()
    }

    func play(_ url: URL, seconds: Double) async {
        played.append(url)
        let number = played.count
        let (end, endSignal) = AsyncStream<Void>.makeStream()
        current = (number, endSignal)
        sounding = url
        startedSignal.yield(url)
        // Ends when the test finishes it, or with `nil` when the task is cancelled.
        var waiting = end.makeAsyncIterator()
        _ = await waiting.next()
        if current?.number == number {
            current = nil
            sounding = nil
        }
        returnedSignal.yield(url)
    }
}
