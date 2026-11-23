import Application
import Domain
import Foundation
import Testing

@Suite("GetSagaFilmUseCase")
struct SagaFilmUseCaseTests {
    static let text = Stub.text
    static let catalog = ContentCatalog(
        worlds: [
            World(id: "w1", order: 1, title: text, tagline: text, span: .months(min: 0, max: 8)),
            World(id: "w2", order: 2, title: text, tagline: text, span: .months(min: 9, max: 24)),
            World(id: "w3", order: 3, title: text, tagline: text, span: .months(min: 25, max: 41))
        ],
        quests: [Quest(id: "q1", worldID: "w1", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0)],
        bosses: [BossFight(id: "b1", worldID: "w2", title: text, intro: text, guide: [], badge: text,
                           skill: .care, xp: 100, minAgeMonths: 9)],
        firsts: [FirstMoment(id: "f-walk", order: 1, emoji: "👣", title: text, xp: 30, companionTrait: "walk")],
        gear: [
            GearItem(id: "g-cloth", skill: .care, look: "burpCloth", title: text),
            GearItem(id: "g-hat", skill: .care, look: "hat", title: text)
        ],
        titles: [
            DadTitle(id: "t0", order: 0, minCards: 0, minXP: 0, name: text),
            DadTitle(id: "t1", order: 1, minCards: 1, minXP: 20, gearIDs: ["g-cloth"], name: text),
            DadTitle(id: "t2", order: 2, minCards: 2, minXP: 100, gearIDs: ["g-hat"], name: text)
        ]
    )
    static let music = Soundtrack(
        id: "theme",
        title: LocalizedText(el: "Θέμα", en: "Theme"),
        mood: LocalizedText(el: "Απαλό", en: "Gentle"),
        artist: "Dad",
        licence: .original,
        audioURL: URL(fileURLWithPath: "/theme.m4a")
    )
    static let lullaby = Soundtrack(
        id: "lullaby",
        title: LocalizedText(el: "Νανούρισμα", en: "Lullaby"),
        mood: LocalizedText(el: "Αργό", en: "Slow"),
        artist: "Dad",
        licence: .original,
        audioURL: URL(fileURLWithPath: "/lullaby.m4a")
    )

    let calendar: Calendar
    let anna: Child
    let niko: Child
    let profiles = SpyProfileRepository()
    let progress = SpyProgressRepository()

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        self.calendar = calendar
        let birth = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15)) ?? .distantPast
        anna = Child(name: "Άννα", birthDay: CalendarDay(birth, in: .gmt))
        niko = Child(name: "Νίκος", birthDay: CalendarDay(birth, in: .gmt))
    }

    func date(months: Int, days: Int = 0) -> Date {
        let birth = anna.birthDay?.start(in: calendar.timeZone) ?? .distantPast
        let month = calendar.date(byAdding: .month, value: months, to: birth) ?? .distantPast
        return calendar.date(byAdding: .day, value: days, to: month) ?? .distantPast
    }

    let choices = InMemorySagaFilmChoicesRepository()

    func sut(
        soundtracks: [Soundtrack] = [Self.music, Self.lullaby], standing: InMemoryStanding = InMemoryStanding()
    ) -> DefaultGetSagaFilmUseCase {
        DefaultGetSagaFilmUseCase(
            contentRepository: StubContentRepository(result: .success(Self.catalog)),
            profileRepository: profiles,
            progressRepository: progress,
            outfitRepository: SpyOutfitRepository(),
            standingRepository: standing,
            soundtrackRepository: StubSoundtrackRepository(soundtracks: soundtracks),
            choicesRepository: choices,
            timeZone: calendar.timeZone
        )
    }

    func family() async throws {
        await profiles.seed(PlayerProfile(children: [anna, niko], heroClassID: "h"))
    }

    func record(_ kind: ProgressEvent.Kind, months: Int, child: Child? = nil) async throws {
        try await progress.add(ProgressEvent(kind: kind, childID: (child ?? anna).id, date: date(months: months)))
    }

    @Test("Given the partner's entries, when reading the film, then they play; the hero, title and medals are the dad's")
    func partnersEntriesPlayTheHeroIsHis() async throws {
        try await family()
        try await record(.quest(id: "q1"), months: 1)
        let theirs = [
            ProgressEvent(authorID: .partner, kind: .boss(id: "b1"), childID: anna.id, date: date(months: 10)),
            ProgressEvent(authorID: .partner, kind: .first(id: "f-walk"), childID: anna.id, date: date(months: 11))
        ]
        for event in theirs { try await progress.add(event) }

        let film = try #require(try await sut().execute(childID: anna.id, period: .everything, on: date(months: 26)))

        let played = film.storyboard.scenes.compactMap { if case .entry(let entry) = $0.kind { entry.id } else { nil } }
        #expect(played == theirs.map(\.id))
        #expect(film.childFirsts.map(\.id) == ["f-walk"])
        #expect(film.title?.id == "t1")
        #expect(film.medalCount == 0)
        #expect(film.storyboard.scenes.last?.kind == .credits(SagaCredits(questsDone: 1, bossesBeaten: 0)))
    }

    @Test("Given nothing stored, when reading the film, then it shows its dates; once turned off, it doesn't")
    func datesSwitch() async throws {
        try await family()
        #expect(try await #require(sut().execute(childID: nil, period: nil, on: date(months: 26))).showsDates)

        await DefaultSetSagaFilmDatesUseCase(repository: choices).execute(showsDates: false)

        #expect(try await !#require(sut().execute(childID: nil, period: nil, on: date(months: 26))).showsDates)
    }

    @Test("Given no track chosen, when reading the film, then it offers every track in order and has the first")
    func firstTrackByDefault() async throws {
        try await family()

        let film = try #require(try await sut().execute(childID: nil, period: nil, on: date(months: 26)))

        #expect(film.soundtracks == [Self.music, Self.lullaby])
        #expect(film.soundtrack == Self.music)
    }

    @Test("Given a track chosen, when reading the film, then it is the film's music")
    func chosenTrack() async throws {
        try await family()

        await DefaultSetSagaFilmMusicUseCase(repository: choices).execute(soundtrackID: "lullaby")

        let film = try #require(try await sut().execute(childID: nil, period: nil, on: date(months: 26)))
        #expect(film.soundtrack == Self.lullaby)
    }

    @Test("Given a chosen track no longer bundled, when reading the film, then it has the first")
    func chosenTrackGone() async throws {
        try await family()

        await DefaultSetSagaFilmMusicUseCase(repository: choices).execute(soundtrackID: "gone")

        let film = try #require(try await sut().execute(childID: nil, period: nil, on: date(months: 26)))
        #expect(film.soundtrack == Self.music)
    }

    @Test("Given no family yet, when reading the film, then there is none")
    func noFamily() async throws {
        #expect(try await sut().execute(childID: nil, period: nil, on: date(months: 26)) == nil)
    }

    @Test("Given no choice, or a child no longer in the family, when reading the film, then it is about the first child")
    func childFallsBackToFirst() async throws {
        try await family()

        #expect(try await sut().execute(childID: nil, period: .everything, on: date(months: 26))?.child == anna)
        #expect(try await sut().execute(childID: UUID(), period: .everything, on: date(months: 26))?.child == anna)
        #expect(try await sut().execute(childID: niko.id, period: .everything, on: date(months: 26))?.child == niko)
    }

    @Test("Given the second birthday a few days ago, when reading the film with no period, then it tells the second year")
    func defaultsToTheOccasion() async throws {
        try await family()
        try await record(.quest(id: "q1"), months: 18)

        let film = try await sut().execute(childID: nil, period: nil, on: date(months: 24, days: 5))

        #expect(film?.period == .year(2))
    }

    @Test("Given no occasion today, or a period not started, when reading the film, then it tells everything")
    func fallsBackToEverything() async throws {
        try await family()
        try await record(.quest(id: "q1"), months: 18)

        #expect(try await sut().execute(childID: nil, period: nil, on: date(months: 40))?.period == .everything)
        #expect(try await sut().execute(childID: nil, period: .year(9), on: date(months: 26))?.period == .everything)
    }

    @Test("Given gear and firsts earned after the first year, when reading its film, then the hero and child are as then")
    func asOfThePeriodsEnd() async throws {
        try await family()
        try await record(.quest(id: "q1"), months: 3)
        try await record(.boss(id: "b1"), months: 14)
        try await record(.first(id: "f-walk"), months: 13)

        let film = try #require(try await sut().execute(childID: nil, period: .year(1), on: date(months: 26)))
        let everything = try #require(try await sut().execute(childID: nil, period: .everything, on: date(months: 26)))

        #expect(film.equippedGear.map(\.id) == ["g-cloth"])
        #expect(film.medalCount == 0)
        #expect(film.childFirsts.isEmpty)
        #expect(film.storyboard.childAge == .months(11))
        #expect(everything.equippedGear.map(\.id) == ["g-hat"])
        #expect(everything.childFirsts.map(\.id) == ["f-walk"])
        #expect(everything.medalCount == 1)
    }

    @Test("Given a title kept above what the entries reach, when reading films, then a past one has its title then, today's his")
    func titleAsOfTheFilmsEnd() async throws {
        try await family()
        try await record(.quest(id: "q1"), months: 3)
        try await record(.boss(id: "b1"), months: 14)
        let standing = InMemoryStanding(KeptStanding(titleID: "t2", seenTitleID: "t2"))
        // Only the quest is left: the boss's entry was deleted after it brought t2.
        try await progress.delete(id: try #require(try await progress.fetchEvents().last?.id))

        let yearOne = try #require(try await sut(standing: standing).execute(
            childID: nil, period: .year(1), on: date(months: 26)
        ))
        let everything = try #require(try await sut(standing: standing).execute(
            childID: nil, period: .everything, on: date(months: 26)
        ))

        #expect(yearOne.title?.id == "t1")
        #expect(everything.title?.id == "t2")
        #expect(everything.equippedGear.map(\.id) == ["g-hat"])
    }

    @Test("Given gear, a medal and a first from the first year, when reading the third year's film, then they all show")
    func earlierYearsCarryOver() async throws {
        try await family()
        try await record(.quest(id: "q1"), months: 3)
        try await record(.boss(id: "b1"), months: 10)
        try await record(.first(id: "f-walk"), months: 11)
        try await record(.quest(id: "q1"), months: 25)

        let film = try #require(try await sut().execute(childID: nil, period: .year(3), on: date(months: 26)))

        #expect(film.period == .year(3))
        #expect(film.equippedGear.map(\.id) == ["g-hat"])
        #expect(film.medalCount == 1)
        #expect(film.childFirsts.map(\.id) == ["f-walk"])
        #expect(film.storyboard.childAge == .months(26))
    }

    @Test("Given a boss and a first with Niko, when reading Anna's film, then the medal shows but the first is Niko's own")
    func medalsAreTheDadsFirstsTheChilds() async throws {
        try await family()
        try await record(.quest(id: "q1"), months: 3)
        try await record(.boss(id: "b1"), months: 10, child: niko)
        try await record(.first(id: "f-walk"), months: 11, child: niko)

        let film = try #require(try await sut().execute(childID: anna.id, period: .everything, on: date(months: 26)))

        #expect(film.medalCount == 1)
        #expect(film.childFirsts.isEmpty)
    }

    @Test("Given quests in two years and another child's, when reading a year's film, then its credits count that year only")
    func creditsOfThePeriod() async throws {
        try await family()
        try await record(.quest(id: "q1"), months: 2)
        try await record(.quest(id: "q1"), months: 5)
        try await record(.quest(id: "q1"), months: 15)
        try await record(.quest(id: "q1"), months: 6, child: niko)

        let film = try #require(try await sut().execute(childID: anna.id, period: .year(1), on: date(months: 26)))

        #expect(film.storyboard.scenes.last?.kind == .credits(SagaCredits(questsDone: 2, bossesBeaten: 0)))
        #expect(film.availablePeriods == [.year(1), .year(2), .world(id: "w1"), .world(id: "w2"), .everything])
        #expect(film.soundtrack == Self.music)
    }

    @Test("Given no bundled music, when reading the film, then it fails as broken, not as an empty saga")
    func noSoundtrack() async throws {
        try await family()
        await #expect(throws: SagaFilmError.noSoundtrack) {
            try await sut(soundtracks: []).execute(childID: nil, period: nil, on: date(months: 26))
        }
    }
}

struct StubSoundtrackRepository: SoundtrackRepository {
    let soundtracks: [Soundtrack]

    func fetchSoundtracks() async throws -> [Soundtrack] {
        soundtracks
    }
}

/// What the film sheet remembers, in memory: dates on and no track until set.
final class InMemorySagaFilmChoicesRepository: SagaFilmChoicesRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storedShowsDates: Bool?
    private var storedSoundtrackID: String?

    func showsDates() async -> Bool { lock.withLock { storedShowsDates ?? true } }
    func setShowsDates(_ showsDates: Bool) async { lock.withLock { storedShowsDates = showsDates } }
    func soundtrackID() async -> String? { lock.withLock { storedSoundtrackID } }
    func setSoundtrackID(_ id: String) async { lock.withLock { storedSoundtrackID = id } }
}
