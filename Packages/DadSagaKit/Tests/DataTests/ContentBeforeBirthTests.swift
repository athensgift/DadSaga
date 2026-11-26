import Domain
import Testing
@testable import Data

/// The content's new shape (ADR-0053 §7): a world before birth, `onlyFor`, `situational`, `evergreen`, `retired` and
/// `beforeBirth`, and what the load rejects.
@Suite("Content before birth and audiences")
struct ContentBeforeBirthTests {
    let text = LocalizedTextDTO(el: "x", en: "x")
    let domainText = LocalizedText(el: "x", en: "x")

    func world(_ id: String = "w0", beforeBirth: Bool? = nil, min: Int? = nil, max: Int? = nil) -> WorldDTO {
        var dto = WorldDTO(id: id, order: 0, title: text, tagline: text)
        dto.beforeBirth = beforeBirth
        dto.minAgeMonths = min
        dto.maxAgeMonths = max
        return dto
    }

    @Test("Given a world before birth without ages, when mapping, then its span is before birth; with ages, months")
    func mapsWorldSpans() throws {
        #expect(try world(beforeBirth: true).toDomain().span == .beforeBirth)
        #expect(try world(min: 9, max: 24).toDomain().span == .months(min: 9, max: 24))
        #expect(try world(min: 42).toDomain().span == .months(min: 42, max: nil))
    }

    @Test("Given a world with neither, or before birth with ages, when mapping, then invalidWorldAges is thrown")
    func rejectsWorldAges() {
        #expect(throws: ContentDataError.invalidWorldAges(worldID: "w0")) { try world().toDomain() }
        #expect(throws: ContentDataError.invalidWorldAges(worldID: "w0")) { try world(beforeBirth: true, min: 0).toDomain() }
    }

    @Test("Given audience words and flags, when mapping, then quests, bosses and firsts carry them")
    func mapsFlags() throws {
        var quest = QuestDTO(id: "q", worldID: "w", title: text, description: text, skill: "care", xp: 10, minAgeMonths: 0)
        quest.onlyFor = ["partner", "olderSibling"]
        quest.retired = true
        let mapped = try quest.toDomain()
        #expect(mapped.onlyFor == [.partner, .olderSibling])
        #expect(mapped.isRetired)

        var boss = BossFightDTO(id: "b", worldID: "w", title: text, intro: text, guide: [text], badge: text,
                                skill: "care", xp: 100, minAgeMonths: 0)
        #expect(try boss.toDomain().onlyFor.isEmpty)
        boss.onlyFor = ["youngerSibling"]
        boss.situational = true
        boss.evergreen = true
        let bossFight = try boss.toDomain()
        #expect(bossFight.onlyFor == [.youngerSibling])
        #expect(bossFight.isSituational && bossFight.isEvergreen)

        var first = FirstMomentDTO(id: "f", order: 1, emoji: "✨", title: text, xp: 30, companionTrait: nil)
        #expect(!first.toDomain().isBeforeBirth && !first.toDomain().isRetired)
        first.beforeBirth = true
        first.retired = true
        #expect(first.toDomain().isBeforeBirth && first.toDomain().isRetired)
    }

    @Test("Given an unknown audience word, when mapping, then unknownAudience is thrown")
    func unknownAudience() {
        var quest = QuestDTO(id: "q", worldID: "w", title: text, description: text, skill: "care", xp: 10, minAgeMonths: 0)
        quest.onlyFor = ["twoHomes"]
        #expect(throws: ContentDataError.unknownAudience(itemID: "q", audience: "twoHomes")) { try quest.toDomain() }
    }

    func catalog(
        worlds: [World], questAge: Int = 0, questWorld: String = "w0", questIsWeekly: Bool = true
    ) -> ContentCatalog {
        ContentCatalog(
            worlds: worlds,
            quests: [Quest(id: "q", worldID: questWorld, title: domainText, description: domainText, skill: .care, xp: 1,
                           minAgeMonths: questAge, isWeekly: questIsWeekly)],
            bosses: [],
            firsts: [],
            skillCurves: SkillCurve.forEverySkill,
            appearanceOptions: DadAppearance.Part.allCases.flatMap { part in
                DadAppearance.optionIDs(for: part).map { DadAppearanceOption(part: part, id: $0, title: domainText) }
            }
        )
    }

    var harbour: World { World(id: "w0", order: 0, title: domainText, tagline: domainText, span: .beforeBirth) }
    var swamp: World { World(id: "w1", order: 1, title: domainText, tagline: domainText, span: .months(min: 0, max: 8)) }

    @Test("Given one world before birth, first by order, with its cards at 0 months, when validating, then it passes")
    func validWorldZero() throws {
        try ContentValidator.validate(catalog(worlds: [harbour, swamp]))
    }

    @Test("Given two worlds before birth, or one that isn't first, when validating, then misplacedBeforeBirthWorld is thrown")
    func misplacedWorldZero() {
        let second = World(id: "w9", order: 5, title: domainText, tagline: domainText, span: .beforeBirth)
        #expect(throws: ContentDataError.misplacedBeforeBirthWorld(worldID: "w9")) {
            try ContentValidator.validate(catalog(worlds: [harbour, swamp, second]))
        }
        let late = World(id: "w0", order: 2, title: domainText, tagline: domainText, span: .beforeBirth)
        #expect(throws: ContentDataError.misplacedBeforeBirthWorld(worldID: "w0")) {
            try ContentValidator.validate(catalog(worlds: [late, swamp]))
        }
    }

    @Test("Given a World 0 card above 0 months, when validating, then agedBeforeBirth is thrown")
    func agedCard() {
        #expect(throws: ContentDataError.agedBeforeBirth(itemID: "q")) {
            try ContentValidator.validate(catalog(worlds: [harbour, swamp], questAge: 2))
        }
    }

    @Test("Given a world whose only quest is never weekly, when validating, then noWeeklyQuest is thrown")
    func worldWithoutWeeklyQuest() {
        #expect(throws: ContentDataError.noWeeklyQuest(worldID: "w0")) {
            try ContentValidator.validate(catalog(worlds: [harbour, swamp], questIsWeekly: false))
        }
    }
}
