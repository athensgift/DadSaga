import Presentation
import Testing

/// How a skill's mark is drawn: its symbol sits inside its circle, and it grows but never fills, never empties and
/// never outshines its symbol (ADR-0059 §2).
@Suite("SkillMarkLook")
struct SkillMarkLookTests {
    @Test("Given a skill not grown yet, when drawn, then the symbol is 44% of its circle, in colour, with some wash and no glow")
    func notGrown() {
        let look = SkillMarkLook(growth: 0)
        #expect(look.symbolScale == 0.44)
        #expect(look.washOpacity > 0)
        #expect(look.glowOpacity == 0)
        #expect(look.glowRadius == 0)
    }

    @Test("Given any growth, when drawn, then the symbol sits inside its circle with room around it, wide or tall")
    func symbolSitsInsideItsCircle() {
        for growth in stride(from: 0.0, through: 1.0, by: 0.05) {
            let scale = SkillMarkLook(growth: growth).symbolScale
            #expect(scale >= SkillMarkLook.restingSymbolScale)
            #expect(scale <= SkillMarkLook.largestSymbolScale)
            // Even the corners of the symbol's square stay well inside the circle: at most 85% of the way to its edge.
            #expect(scale * 2.0.squareRoot() <= 0.85)
        }
    }

    @Test("Given a skill from new to fully grown, when drawn, then the wash and the glow change far more than the symbol")
    func growthShowsBehindTheSymbol() {
        let new = SkillMarkLook(growth: 0)
        let grown = SkillMarkLook(growth: 0.999)
        #expect(grown.symbolScale / new.symbolScale < 1.4)
        #expect(grown.washOpacity / new.washOpacity > 3)
        #expect(grown.glowOpacity > 0.65)
    }

    @Test("Given ever more growth, when drawn, then symbol, wash and glow grow with it, and the symbol never reaches 60%")
    func growsWithTheSkill() {
        let looks = [0, 0.2, 0.5, 0.75, 0.999].map(SkillMarkLook.init(growth:))
        for (smaller, larger) in zip(looks, looks.dropFirst()) {
            #expect(larger.symbolScale > smaller.symbolScale)
            #expect(larger.washOpacity > smaller.washOpacity)
            #expect(larger.glowOpacity > smaller.glowOpacity)
            #expect(larger.glowRadius > smaller.glowRadius)
        }
        #expect(looks.allSatisfy { $0.symbolScale < SkillMarkLook.largestSymbolScale })
    }

    @Test("Given any growth, when drawn, then the wash stays at or under the tint's wash, so the symbol keeps its contrast")
    func washNeverAboveTheTint() {
        for growth in stride(from: 0.0, through: 1.0, by: 0.05) {
            #expect(SkillMarkLook(growth: growth).washOpacity <= SkillMarkLook.maxWashOpacity)
        }
        #expect(SkillMarkLook.maxWashOpacity == 0.15)
    }

    @Test("Given one quest of 20 XP on a curve half grown at 150, when drawn, then the mark has visibly changed")
    func firstCardShows() {
        let new = SkillMarkLook(growth: 0)
        let oneCard = SkillMarkLook(growth: 20.0 / 170.0)
        // Mostly behind the symbol: the wash nearly doubles and a glow appears around it, wide enough to see.
        #expect(oneCard.washOpacity / new.washOpacity > 1.7)
        #expect(oneCard.washOpacity - new.washOpacity > 0.03)
        #expect(oneCard.glowOpacity > 0.2)
        #expect(oneCard.glowRadius > 0.1)
        // The symbol grows a little too, never by much.
        #expect(oneCard.symbolScale > new.symbolScale)
        #expect(oneCard.symbolScale - new.symbolScale < 0.08)
    }

    @Test("Given a growth out of range, when drawn, then it is held between 0 and 1")
    func clamped() {
        #expect(SkillMarkLook(growth: -1) == SkillMarkLook(growth: 0))
        #expect(SkillMarkLook(growth: 3).growth == 1)
    }
}
