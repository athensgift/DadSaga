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

@Suite("GetAdventureUseCase")
struct GetAdventureUseCaseTests {
    @Test("Given a 10-month-old, when executing, then the second world is current and age-appropriate quests are available")
    func tenMonthOld() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let birth = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1)))
        let sut = DefaultGetAdventureUseCase(
            repository: StubContentRepository(result: .success(Stub.catalog)),
            calendar: calendar
        )

        let adventure = try await sut.execute(for: Child(name: "Νίκος", birthDate: birth), on: today)

        #expect(adventure.ageInMonths == 10)
        #expect(adventure.currentWorld?.id == "w2")
        #expect(adventure.unlockedWorlds.map(\.id) == ["w1", "w2"])
        #expect(Set(adventure.availableQuests.map(\.id)) == ["q1", "q2"])
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
                      skill: .care, xp: 100, minAgeMonths: 12)
        ],
        firsts: []
    )
}
