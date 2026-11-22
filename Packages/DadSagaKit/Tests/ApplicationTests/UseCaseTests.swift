import Application
import Domain
import Foundation
import Testing

@Suite("LoadContentCatalogUseCase")
struct LoadContentCatalogUseCaseTests {
    @Test("Given a repository with content, when executing, then the catalog is returned")
    func returnsCatalog() async throws {
        let sut = DefaultLoadContentCatalogUseCase(repository: StubContentRepository(result: .success(Stub.catalog)))
        let catalog = try await sut.execute()
        #expect(catalog == Stub.catalog)
    }

    @Test("Given a failing repository, when executing, then the error is propagated")
    func propagatesError() async {
        let sut = DefaultLoadContentCatalogUseCase(repository: StubContentRepository(result: .failure(StubError.boom)))
        await #expect(throws: StubError.boom) {
            try await sut.execute()
        }
    }
}

@Suite("Adventure")
struct AdventureTests {
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    @Test("Given a 10-month-old, when building the adventure, then the second world is current and has no bosses yet")
    func tenMonthOld() throws {
        let birth = try #require(utc.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let today = try #require(utc.date(from: DateComponents(year: 2026, month: 11, day: 1)))

        let adventure = Adventure(
            for: Child(name: "Νίκος", birthDay: CalendarDay(birth, in: .gmt)),
            family: .everyone,
            catalog: Stub.catalog,
            on: CalendarDay(today, in: .gmt)
        )

        #expect(adventure.age == .months(10))
        #expect(!adventure.isBeyondContent)
        #expect(adventure.currentWorld?.id == "w2")
        #expect(adventure.unlockedWorlds.map(\.id) == ["w1", "w2"])
    }

    @Test("Given a child not born yet and content without a world before birth, when building the adventure, then no world fits")
    func notBornWithoutWorldZero() {
        let child = Child(name: "Μπέμπης", birthDay: nil)

        let adventure = Adventure(for: child, family: .everyone, catalog: Stub.catalog, on: .day(2026, 11, 21))

        #expect(adventure.age == .beforeBirth)
        #expect(adventure.isBeyondContent)
        #expect(adventure.currentWorld == nil)
        #expect(adventure.unlockedWorlds.isEmpty)
    }

    @Test("Given a child older than every world, when building the adventure, then nothing is offered")
    func olderThanContent() {
        let today = Date(timeIntervalSince1970: 1_000_000_000)
        let child = Child(name: "Άννα", birthDay: CalendarDay(today.addingTimeInterval(-5 * 365 * 86_400), in: .gmt))

        let adventure = Adventure(for: child, family: .everyone, catalog: Stub.catalog, on: CalendarDay(today, in: .gmt))

        #expect(adventure.isBeyondContent)
        #expect(adventure.currentWorld == nil)
        #expect(adventure.unlockedWorlds.map(\.id) == ["w1", "w2"])
    }
}

enum StubError: Error { case boom }

struct StubContentRepository: ContentRepository {
    let result: Result<ContentCatalog, StubError>

    func fetchCatalog() async throws -> ContentCatalog {
        try result.get()
    }
}

enum Stub {
    static let text = LocalizedText(el: "x", en: "x")
    static let catalog = ContentCatalog(
        worlds: [
            World(id: "w1", order: 1, title: text, tagline: text, span: .months(min: 0, max: 8)),
            World(id: "w2", order: 2, title: text, tagline: text, span: .months(min: 9, max: 24))
        ],
        quests: [
            Quest(id: "q1", worldID: "w1", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0),
            Quest(id: "q2", worldID: "w2", title: text, description: text, skill: .play, xp: 20, minAgeMonths: 9),
            Quest(id: "q3", worldID: "w2", title: text, description: text, skill: .play, xp: 20, minAgeMonths: 15)
        ],
        bosses: [
            BossFight(id: "b1", worldID: "w2", title: text, intro: text, guide: [], badge: text,
                      skill: .care, xp: 100, minAgeMonths: 12),
            BossFight(id: "b-sibling", worldID: "w2", title: text, intro: text, guide: [], badge: text,
                      skill: .care, xp: 100, minAgeMonths: 12, onlyFor: [.youngerSibling])
        ],
        firsts: []
    )
}

/// The profile's kept standing, in memory (ADR-0055 §3). Starts as a saga begun with titles.
actor InMemoryStanding: StandingRepository {
    private(set) var kept: KeptStanding
    private(set) var writes = 0
    var failsToKeep = false

    init(_ kept: KeptStanding = .fresh) {
        self.kept = kept
    }

    func fetchKept() async throws -> KeptStanding { kept }

    func keep(titleID: String?, gearIDs: [String]) async throws {
        if failsToKeep { throw StubError.boom }
        writes += 1
        kept.titleID = titleID ?? kept.titleID
        kept.gearIDs = gearIDs
    }

    func markSeen(titleID: String) async throws {
        writes += 1
        kept.seenTitleID = titleID
    }

    func failKeeping() { failsToKeep = true }
}

extension ProgressChange {
    /// What the change gave in XP: the app never shows it (ADR-0055 §7), the tests check it.
    var gainedXP: Int { after.totalXP - before.totalXP }
}
