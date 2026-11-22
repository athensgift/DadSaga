import Presentation
import Testing

/// How a skill's mark is drawn: its circle fills from the bottom with every card and never to the top, and its symbol
/// never changes size (ADR-0059 §2).
@Suite("SkillMarkLook")
struct SkillMarkLookTests {
    @Test("Given a skill not grown yet, when drawn, then nothing has filled: a pale circle with its symbol")
    func notGrown() {
        #expect(SkillMarkLook(growth: 0).fillLevel == 0)
    }

    @Test("Given ever more growth, when drawn, then the colour stands higher each time and never reaches the top")
    func risesWithTheSkill() {
        let levels = [0, 0.05, 0.2, 0.5, 0.75, 0.999, 1].map { SkillMarkLook(growth: $0).fillLevel }
        for (lower, higher) in zip(levels, levels.dropFirst()) {
            #expect(higher > lower)
        }
        // A pale cap is always left at the top, however much the skill has grown.
        #expect(levels.allSatisfy { $0 <= SkillMarkLook.highestLevel })
        #expect(SkillMarkLook.highestLevel < 0.9)
    }

    @Test("Given one quest of 20 XP on a curve half grown at 150, when drawn, then the colour is clearly in the circle")
    func firstCardShows() {
        let oneCard = SkillMarkLook(growth: 20.0 / 170.0)
        // About a quarter of the way up: under that, the bottom of a circle is a sliver.
        #expect(oneCard.fillLevel > 0.2)
        #expect(oneCard.fillLevel < 0.3)
        // Even the smallest growth starts from a level the eye can see.
        #expect(SkillMarkLook(growth: 0.001).fillLevel >= SkillMarkLook.lowestLevel)
    }

    @Test("Given a second and a third quest, when drawn, then each raises the colour by a step the eye can see")
    func eachEarlyCardShows() {
        let levels = [20.0, 40, 60].map { SkillMarkLook(growth: $0 / ($0 + 150)).fillLevel }
        for (lower, higher) in zip(levels, levels.dropFirst()) {
            // More than 5% of the circle's height: about 2 pt of a 36 pt circle.
            #expect(higher - lower > 0.05)
        }
    }

    @Test("Given any growth, when drawn, then the symbol is the same size, inside its circle with room around it")
    func symbolNeverChangesSize() {
        #expect(SkillMarkLook.symbolScale == 0.5)
        // Even the corners of the symbol's square stay well inside the circle.
        #expect(SkillMarkLook.symbolScale * 2.0.squareRoot() < 0.75)
    }

    @Test("Given a card's celebration gone, when the colour rises, then it takes about a second")
    func risesGently() {
        #expect(SkillMarkLook.riseDuration == 1)
    }

    @Test("Given a growth out of range, when drawn, then it is held between 0 and 1")
    func clamped() {
        #expect(SkillMarkLook(growth: -1) == SkillMarkLook(growth: 0))
        #expect(SkillMarkLook(growth: 3).growth == 1)
    }
}
