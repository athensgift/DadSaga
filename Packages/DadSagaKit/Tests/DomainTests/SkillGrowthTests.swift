import Domain
import Foundation
import Testing

/// How much each skill has grown: `xp / (xp + halfGrownXP)`, from the entries alone, never full (ADR-0059 §2).
@Suite("Skill growth")
struct SkillGrowthTests {
    static let text = Fixtures.text
    static let child = UUID()
    static let catalog = ContentCatalog(
        worlds: [World(id: "w1", order: 1, title: text, tagline: text, span: .months(min: 0, max: 24))],
        quests: [
            Quest(id: "q", worldID: "w1", title: text, description: text, skill: .patience, xp: 100, minAgeMonths: 0)
        ],
        bosses: [
            BossFight(id: "b", worldID: "w1", title: text, intro: text, guide: [], badge: text, skill: .care, xp: 400,
                      minAgeMonths: 0)
        ],
        firsts: [FirstMoment(id: "f", order: 1, emoji: "👣", title: text, xp: 50, companionTrait: nil)],
        skillCurves: Skill.allCases.map { SkillCurve(skill: $0, halfGrownXP: 400) }
    )

    static func growth(_ kinds: [ProgressEvent.Kind]) -> [SkillGrowth] {
        let events = kinds.map { ProgressEvent(kind: $0, childID: child, date: .now) }
        return SkillGrowth.all(DadProgress(events: events, catalog: catalog), catalog: catalog)
    }

    @Test("Given no entries, when growing, then all four skills are there in their fixed order, none grown")
    func noEntries() {
        let growth = Self.growth([])
        #expect(growth.map(\.skill) == [.care, .play, .patience, .resilience])
        #expect(growth.allSatisfy { $0.value == 0 })
    }

    @Test(
        "Given a skill's XP, when growing, then it is half grown at halfGrownXP, three quarters at three times, never full",
        arguments: [(0, 0.0), (400, 0.5), (1200, 0.75), (100, 0.2)]
    )
    func curve(xp: Int, value: Double) {
        let growth = SkillGrowth(skill: .care, xp: xp, curve: SkillCurve(skill: .care, halfGrownXP: 400))
        #expect(abs(growth.value - value) < 0.000_001)
    }

    @Test("Given ever more XP, when growing, then each card raises it and it never reaches 1")
    func neverFull() {
        let curve = SkillCurve(skill: .play, halfGrownXP: 400)
        let values = [30, 60, 1000, 100_000, 10_000_000].map { SkillGrowth(skill: .play, xp: $0, curve: curve).value }
        #expect(values == values.sorted())
        #expect(Set(values).count == values.count)
        #expect(values.allSatisfy { $0 < 1 })
    }

    @Test("Given a boss and a quest, when growing, then each grows its own skill, in place, and the rest stay at 0")
    func eachCardItsSkill() {
        let growth = Self.growth([.boss(id: "b"), .quest(id: "q")])
        #expect(growth.map(\.skill) == [.care, .play, .patience, .resilience])
        #expect(growth.map(\.value) == [0.5, 0, 0.2, 0])
    }

    @Test("Given a first, when growing, then no skill grows: a first has none")
    func firstGrowsNothing() {
        #expect(Self.growth([.first(id: "f")]).allSatisfy { $0.value == 0 })
    }

    @Test("Given a quest that is then undone, when growing, then its skill is back where it was: it follows the entries")
    func followsTheEntries() {
        let before = Self.growth([.quest(id: "q")])
        let after = Self.growth([])
        #expect(before[2].value > 0)
        #expect(after[2].value == 0)
    }

    @Test("Given content without a curve for a skill, when growing, then it doesn't grow rather than fail")
    func noCurve() {
        #expect(SkillGrowth(skill: .care, xp: 500, curve: nil).value == 0)
    }
}
