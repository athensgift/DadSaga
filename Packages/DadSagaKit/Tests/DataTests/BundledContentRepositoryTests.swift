import Domain
import Testing
@testable import Data

@Suite("BundledContentRepository")
struct BundledContentRepositoryTests {
    let repository = BundledContentRepository()

    @Test("Given the bundled JSON, when fetching, then it decodes, maps and passes validation")
    func loadsAndValidates() async throws {
        let catalog = try await repository.fetchCatalog()
        #expect(catalog.worlds.count == 4)
        #expect(catalog.quests.count == 55)
        #expect(catalog.bosses.count == 16)
        #expect(catalog.firsts.count == 24)
    }

    @Test("Given the bundled JSON, when fetching, then tips, evergreen quests and audiences are read")
    func readsNewFields() async throws {
        let catalog = try await repository.fetchCatalog()
        #expect(catalog.quests.compactMap(\.tip).count == 40)
        #expect(catalog.quests.compactMap(\.tip).filter(\.isMedical).count == 12)
        #expect(catalog.quests.filter(\.isEvergreen).count == 14)
        #expect(catalog.bosses.filter { !$0.onlyFor.isEmpty }.map(\.id) == ["b-w3-new-sibling"])
        #expect(catalog.boss(id: "b-w3-new-sibling")?.onlyFor == [.youngerSibling])
    }

    @Test("Given the bundled heroes, when fetching, then each dad is drawn with his own look")
    func heroLooks() async throws {
        let catalog = try await repository.fetchCatalog()
        #expect(catalog.heroClasses.map(\.look) == ["hero", "cool", "strong", "smart", "chef", "fixer"])
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
        let minimum = Dictionary(uniqueKeysWithValues: catalog.worlds.map { world in
            if case .months(let min, _) = world.span { (world.id, min) } else { (world.id, 0) }
        })
        for quest in catalog.quests {
            let world = try #require(minimum[quest.worldID])
            #expect(quest.minAgeMonths >= world, "\(quest.id) unlocks before its world")
        }
        for boss in catalog.bosses {
            let world = try #require(minimum[boss.worldID])
            #expect(boss.minAgeMonths >= world, "\(boss.id) unlocks before its world")
        }
    }

    @Test("Given the bundled content, when reading the look options, then each part lists every option once, in order")
    func appearanceOptions() async throws {
        let catalog = try await repository.fetchCatalog()
        for part in DadAppearance.Part.allCases {
            let ids = catalog.appearanceOptions.filter { $0.part == part }.map(\.id)
            #expect(ids == DadAppearance.optionIDs(for: part), "\(part)")
        }
        let beard = catalog.appearanceOptions.filter { $0.part == .beard }.map(\.title.el)
        #expect(beard == ["Καθόλου", "Κοντά", "Γεμάτα"])
    }

    @Test("Given the bundled content, when checking text, then nothing is empty in either language")
    func noEmptyText() async throws {
        let catalog = try await repository.fetchCatalog()
        var texts: [LocalizedText] = []
        texts += catalog.worlds.flatMap { [$0.title, $0.tagline] }
        texts += catalog.quests.flatMap { [$0.title, $0.description] }
        texts += catalog.bosses.flatMap { [$0.title, $0.intro, $0.badge] + $0.guide }
        texts += catalog.firsts.map(\.title)
        texts += catalog.quests.compactMap(\.tip).flatMap { [$0.title] + $0.steps }
        texts += catalog.appearanceOptions.map(\.title)
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

    @Test("Given a quest DTO with a medical tip, when mapping, then the tip keeps its steps and medical flag")
    func mapsTip() throws {
        var dto = QuestDTO(id: "q", worldID: "w", title: text, description: text, skill: "care", xp: 10, minAgeMonths: 0)
        dto.tip = QuestTipDTO(title: text, steps: [text, LocalizedTextDTO(el: "β", en: "b")], medical: true)
        dto.evergreen = true
        let quest = try dto.toDomain()
        let tip = try #require(quest.tip)
        #expect(tip.steps.map(\.en) == ["a", "b"])
        #expect(tip.isMedical)
        #expect(quest.isEvergreen)
    }

    @Test("Given a quest DTO without tip or flags, when mapping, then it has no tip and is not evergreen")
    func mapsDefaults() throws {
        let dto = QuestDTO(id: "q", worldID: "w", title: text, description: text, skill: "care", xp: 10, minAgeMonths: 0)
        let quest = try dto.toDomain()
        #expect(quest.tip == nil)
        #expect(!quest.isEvergreen)
    }

    @Test("Given DTOs with former ids, when mapping, then the Domain items keep them; without, they have none")
    func mapsFormerIDs() throws {
        var quest = QuestDTO(id: "q", worldID: "w", title: text, description: text, skill: "care", xp: 10, minAgeMonths: 0)
        #expect(try quest.toDomain().formerIDs.isEmpty)
        quest.formerIDs = ["q-old"]
        #expect(try quest.toDomain().formerIDs == ["q-old"])
        var hero = HeroClassDTO(id: "h", order: 1, title: text, tagline: text, look: "hero")
        hero.formerIDs = ["h-old"]
        #expect(hero.toDomain().has(id: "h-old"))
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

    @Test("Given a quest whose tip has no steps, when validating, then emptyTip is thrown")
    func emptyTip() {
        let world = World(id: "w", order: 1, title: text, tagline: text, span: .months(min: 0, max: nil))
        let catalog = ContentCatalog(
            worlds: [world],
            quests: [Quest(id: "q", worldID: "w", title: text, description: text, skill: .care, xp: 1, minAgeMonths: 0,
                           tip: QuestTip(title: text, steps: []))],
            bosses: [],
            firsts: []
        )
        #expect(throws: ContentDataError.emptyTip(itemID: "q")) {
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

    @Test("Given a renamed first whose former id is another first's id, when validating, then duplicateID is thrown")
    func formerIDClashesWithAnID() {
        let catalog = ContentCatalog(
            worlds: [],
            quests: [],
            bosses: [],
            firsts: [
                FirstMoment(id: "f-smile", order: 1, emoji: "", title: text, xp: 1, companionTrait: nil),
                FirstMoment(id: "f-grin", order: 2, emoji: "", title: text, xp: 1, companionTrait: nil, formerIDs: ["f-smile"])
            ]
        )
        #expect(throws: ContentDataError.duplicateID("f-smile")) {
            try ContentValidator.validate(catalog)
        }
    }

    @Test("Given one former id listed by two items, when validating, then duplicateID is thrown")
    func formerIDListedTwice() {
        let catalog = ContentCatalog(
            worlds: [],
            quests: [],
            bosses: [],
            firsts: [],
            gear: [
                GearItem(id: "mug", skill: .care, minXP: 1, look: "mug", title: text, formerIDs: ["cup"]),
                GearItem(id: "flask", skill: .care, minXP: 2, look: "mug", title: text, formerIDs: ["cup"])
            ]
        )
        #expect(throws: ContentDataError.duplicateID("cup")) {
            try ContentValidator.validate(catalog)
        }
    }
}

@Suite("Look options content")
struct AppearanceContentTests {
    let text = LocalizedText(el: "x", en: "x")

    /// Every option the Domain knows, as the content would list it.
    var allOptions: [DadAppearanceOption] {
        DadAppearance.Part.allCases.flatMap { part in
            DadAppearance.optionIDs(for: part).map { DadAppearanceOption(part: part, id: $0, title: text) }
        }
    }

    func validate(_ options: [DadAppearanceOption]) throws {
        try ContentValidator.validate(ContentCatalog(worlds: [], quests: [], bosses: [], firsts: [], appearanceOptions: options))
    }

    @Test("Given an option DTO with an unknown part, when mapping, then unknownAppearanceOption is thrown")
    func unknownPart() {
        let dto = AppearanceOptionDTO(part: "hat", id: "cap", title: LocalizedTextDTO(el: "α", en: "a"))
        #expect(throws: ContentDataError.unknownAppearanceOption(part: "hat", id: "cap")) { try dto.toDomain() }
    }

    @Test("Given every option once, when validating, then it passes")
    func complete() throws {
        try validate(allOptions)
    }

    @Test("Given a beard the app can't draw, when validating, then unknownAppearanceOption is thrown")
    func unknownID() {
        #expect(throws: ContentDataError.unknownAppearanceOption(part: "beard", id: "goatee")) {
            try validate(allOptions + [DadAppearanceOption(part: .beard, id: "goatee", title: text)])
        }
    }

    @Test("Given no name for round glasses, when validating, then missingAppearanceOption is thrown")
    func missingID() {
        #expect(throws: ContentDataError.missingAppearanceOption(part: "glasses", id: "round")) {
            try validate(allOptions.filter { !($0.part == .glasses && $0.id == "round") })
        }
    }

    @Test("Given short hair listed twice, when validating, then duplicateID is thrown for that part")
    func repeatedID() {
        #expect(throws: ContentDataError.duplicateID("hair.short")) {
            try validate(allOptions + [DadAppearanceOption(part: .hair, id: "short", title: text)])
        }
    }
}
