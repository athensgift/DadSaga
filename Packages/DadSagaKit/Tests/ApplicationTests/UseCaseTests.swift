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
            childCount: 1,
            catalog: Stub.catalog,
            on: CalendarDay(today, in: .gmt)
        )

        #expect(adventure.ageInMonths == 10)
        #expect(!adventure.isBeyondContent)
        #expect(adventure.currentWorld?.id == "w2")
        #expect(adventure.unlockedWorlds.map(\.id) == ["w1", "w2"])
        #expect(adventure.availableBosses.isEmpty)
    }

    @Test("Given one child or two, when building the adventure, then a sibling-only boss comes only with two")
    func familySize() {
        let birth = Date(timeIntervalSince1970: 0)
        let today = Date(timeIntervalSince1970: 14 * 31 * 86_400)
        let child = Child(name: "Νίκος", birthDay: CalendarDay(birth, in: .gmt))

        let alone = Adventure(for: child, childCount: 1, catalog: Stub.catalog, on: CalendarDay(today, in: .gmt))
        let siblings = Adventure(for: child, childCount: 2, catalog: Stub.catalog, on: CalendarDay(today, in: .gmt))

        #expect(alone.availableBosses.map(\.id) == ["b1"])
        #expect(siblings.availableBosses.map(\.id) == ["b1", "b-sibling"])
    }

    @Test("Given a child older than every world, when building the adventure, then nothing is offered")
    func olderThanContent() {
        let today = Date(timeIntervalSince1970: 1_000_000_000)
        let child = Child(name: "Άννα", birthDay: CalendarDay(today.addingTimeInterval(-5 * 365 * 86_400), in: .gmt))

        let adventure = Adventure(for: child, childCount: 1, catalog: Stub.catalog, on: CalendarDay(today, in: .gmt))

        #expect(adventure.isBeyondContent)
        #expect(adventure.currentWorld == nil)
        #expect(adventure.unlockedWorlds.map(\.id) == ["w1", "w2"])
        #expect(adventure.availableBosses.isEmpty)
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
            World(id: "w1", order: 1, title: text, tagline: text, minAgeMonths: 0, maxAgeMonths: 8),
            World(id: "w2", order: 2, title: text, tagline: text, minAgeMonths: 9, maxAgeMonths: 24)
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
                      skill: .care, xp: 100, minAgeMonths: 12, requiresSibling: true)
        ],
        firsts: []
    )
}
