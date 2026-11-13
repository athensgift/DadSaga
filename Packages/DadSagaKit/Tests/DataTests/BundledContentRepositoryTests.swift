import Domain
import Testing
@testable import Data

@Suite("BundledContentRepository")
struct BundledContentRepositoryTests {
    let repository = BundledContentRepository()

    @Test("Given the bundled JSON, when fetching, then it decodes, maps and passes validation")
    func loadsAndValidates() async throws {
        let catalog = try await repository.fetchCatalog()
        #expect(catalog.worlds.count == 2)
        #expect(catalog.quests.count == 20)
        #expect(catalog.bosses.count == 4)
        #expect(catalog.firsts.count == 14)
    }

    @Test("Given the bundled content, when checking each world, then it has quests and at least one boss")
    func everyWorldHasContent() async throws {
        let catalog = try await repository.fetchCatalog()
        for world in catalog.worlds {
            #expect(catalog.quests.contains { $0.worldID == world.id }, "\(world.id) has no quests")
            #expect(catalog.bosses.contains { $0.worldID == world.id }, "\(world.id) has no boss")
        }
    }

    @Test("Given the bundled content, when checking ages, then no quest or boss unlocks before its world")
    func itemAgesFitTheirWorld() async throws {
        let catalog = try await repository.fetchCatalog()
        let worlds = Dictionary(uniqueKeysWithValues: catalog.worlds.map { ($0.id, $0) })
        for quest in catalog.quests {
            let world = try #require(worlds[quest.worldID])
            #expect(quest.minAgeMonths >= world.minAgeMonths, "\(quest.id) unlocks before its world")
        }
        for boss in catalog.bosses {
            let world = try #require(worlds[boss.worldID])
            #expect(boss.minAgeMonths >= world.minAgeMonths, "\(boss.id) unlocks before its world")
        }
    }

    @Test("Given the bundled content, when checking text, then nothing is empty in either language")
    func noEmptyText() async throws {
        let catalog = try await repository.fetchCatalog()
        let texts = catalog.worlds.flatMap { [$0.title, $0.tagline] }
            + catalog.quests.flatMap { [$0.title, $0.description] }
            + catalog.bosses.flatMap { [$0.title, $0.intro, $0.badge] + $0.guide }
            + catalog.firsts.map(\.title)
        for text in texts {
            #expect(!text.el.isEmpty && !text.en.isEmpty)
        }
    }
}

@Suite("Mapping")
struct MappingTests {
    let text = LocalizedTextDTO(el: "α", en: "a")

    @Test("Given a quest DTO with a known skill, when mapping, then the Domain quest has that skill")
    func mapsSkill() throws {
        let dto = QuestDTO(id: "q", worldID: "w", title: text, description: text, skill: "resilience", xp: 10, minAgeMonths: 0)
        let quest = try dto.toDomain()
        #expect(quest.skill == .resilience)
        #expect(quest.title == LocalizedText(el: "α", en: "a"))
    }

    @Test("Given a quest DTO with an unknown skill, when mapping, then unknownSkill is thrown")
    func unknownSkill() {
        let dto = QuestDTO(id: "q", worldID: "w", title: text, description: text, skill: "juggling", xp: 10, minAgeMonths: 0)
        #expect(throws: ContentDataError.unknownSkill(itemID: "q", skill: "juggling")) {
            try dto.toDomain()
        }
    }
}

@Suite("ContentValidator")
struct ContentValidatorTests {
    let text = LocalizedText(el: "x", en: "x")

    @Test("Given a quest pointing to a missing world, when validating, then unknownWorld is thrown")
    func unknownWorld() {
        let catalog = ContentCatalog(
            worlds: [],
            quests: [Quest(id: "q", worldID: "nope", title: text, description: text, skill: .care, xp: 1, minAgeMonths: 0)],
            bosses: [],
            firsts: []
        )
        #expect(throws: ContentDataError.unknownWorld(itemID: "q", worldID: "nope")) {
            try ContentValidator.validate(catalog)
        }
    }

    @Test("Given two items with the same id, when validating, then duplicateID is thrown")
    func duplicateID() {
        let catalog = ContentCatalog(
            worlds: [],
            quests: [],
            bosses: [],
            firsts: [
                FirstMoment(id: "dup", order: 1, emoji: "", title: text, xp: 1, companionTrait: nil),
                FirstMoment(id: "dup", order: 2, emoji: "", title: text, xp: 1, companionTrait: nil)
            ]
        )
        #expect(throws: ContentDataError.duplicateID("dup")) {
            try ContentValidator.validate(catalog)
        }
    }
}
