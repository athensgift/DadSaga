import Presentation
import Testing

/// How a skill's mark is drawn: its symbol fills from its own bottom with every card and never to its top, and never
/// changes size (ADR-0059 §2).
@Suite("SkillMarkLook")
struct SkillMarkLookTests {
    @Test("Given a skill not grown yet, when drawn, then nothing is coloured in: the whole symbol is pale")
    func notGrown() {
        #expect(SkillMarkLook(growth: 0).fillLevel == 0)
    }

    @Test("Given ever more growth, when drawn, then the colour stands higher each time and never reaches the top")
    func risesWithTheSkill() {
        let levels = [0, 0.05, 0.2, 0.5, 0.75, 0.999, 1].map { SkillMarkLook(growth: $0).fillLevel }
        for (lower, higher) in zip(levels, levels.dropFirst()) {
            #expect(higher > lower)
        }
        // The top of the symbol always stays pale, however much the skill has grown.
        #expect(levels.allSatisfy { $0 <= SkillMarkLook.highestLevel })
        #expect(SkillMarkLook.highestLevel < 0.9)
    }

    @Test("Given one quest of 20 XP on a curve half grown at 150, when drawn, then the colour is clearly in the symbol")
    func firstCardShows() {
        let oneCard = SkillMarkLook(growth: 20.0 / 170.0)
        // About a third of the way up the symbol: under a quarter, only the tip of the heart would be coloured.
        #expect(oneCard.fillLevel > 0.3)
        #expect(oneCard.fillLevel < 0.4)
        // Even the smallest growth starts from a level the eye can see.
        #expect(SkillMarkLook(growth: 0.001).fillLevel >= SkillMarkLook.lowestLevel)
    }

    @Test("Given a second and a third quest, when drawn, then each raises the colour by a step the eye can see")
    func eachEarlyCardShows() {
        let levels = [20.0, 40, 60].map { SkillMarkLook(growth: $0 / ($0 + 150)).fillLevel }
        for (lower, higher) in zip(levels, levels.dropFirst()) {
            // More than 4% of the symbol's height: about 1 pt of a symbol 20 pt tall.
            #expect(higher - lower > 0.04)
        }
    }

    @Test("Given a symbol's square, when drawn in its circle, then even its corners stay well inside")
    func symbolStaysInsideItsCircle() {
        #expect(SkillMarkLook.symbolScale * 2.0.squareRoot() < 0.8)
    }

    @Test("Given a growth out of range, when drawn, then it is held between 0 and 1")
    func clamped() {
        #expect(SkillMarkLook(growth: -1) == SkillMarkLook(growth: 0))
        #expect(SkillMarkLook(growth: 3).growth == 1)
    }
}
