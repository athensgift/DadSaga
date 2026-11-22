import Domain
import Testing
@testable import Data

extension SkillCurve {
    /// One curve for each skill, as valid content has.
    static let forEverySkill = Skill.allCases.map { SkillCurve(skill: $0, halfGrownXP: 400) }
}

/// `skills.json`: how fast each skill's mark on home grows (ADR-0059 §2).
@Suite("Skill curves content")
struct SkillContentTests {
    let text = LocalizedText(el: "x", en: "x")

    func validate(_ curves: [SkillCurve]) throws {
        try ContentValidator.validate(ContentCatalog(
            worlds: [], quests: [], bosses: [], firsts: [], skillCurves: curves,
            appearanceOptions: DadAppearance.Part.allCases.flatMap { part in
                DadAppearance.optionIDs(for: part).map { DadAppearanceOption(part: part, id: $0, title: text) }
            }
        ))
    }

    @Test("Given the bundled content, when loading, then each skill has one curve, half grown at 150 for now")
    func bundled() async throws {
        let catalog = try await BundledContentRepository().fetchCatalog()
        #expect(catalog.skillCurves.map(\.skill).sorted { $0.rawValue < $1.rawValue }
            == Skill.allCases.sorted { $0.rawValue < $1.rawValue })
        for skill in Skill.allCases {
            #expect(catalog.curve(for: skill)?.halfGrownXP == 150)
        }
    }

    @Test("Given one curve for each skill, when validating, then it passes")
    func complete() throws {
        try validate(SkillCurve.forEverySkill)
    }

    @Test("Given a skill without a curve, when validating, then missingSkillCurve is thrown")
    func missing() {
        #expect(throws: ContentDataError.missingSkillCurve(skill: "play")) {
            try validate(SkillCurve.forEverySkill.filter { $0.skill != .play })
        }
    }

    @Test("Given a skill with two curves, when validating, then duplicateID is thrown for it")
    func twice() {
        #expect(throws: ContentDataError.duplicateID("care")) {
            try validate(SkillCurve.forEverySkill + [SkillCurve(skill: .care, halfGrownXP: 300)])
        }
    }

    @Test("Given a curve half grown at 0 XP, when validating, then invalidSkillCurve is thrown")
    func notAboveZero() {
        let curves = SkillCurve.forEverySkill.map { $0.skill == .patience ? SkillCurve(skill: .patience, halfGrownXP: 0) : $0 }
        #expect(throws: ContentDataError.invalidSkillCurve(skill: "patience")) { try validate(curves) }
    }

    @Test("Given a curve for a skill the app doesn't know, when mapping, then unknownSkill is thrown")
    func unknownSkill() {
        #expect(throws: ContentDataError.unknownSkill(itemID: "skills", skill: "cooking")) {
            try SkillCurveDTO(skill: "cooking", halfGrownXP: 400).toDomain()
        }
    }
}
