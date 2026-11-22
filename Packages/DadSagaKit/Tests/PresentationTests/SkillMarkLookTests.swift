import Presentation
import Testing

/// How a skill's mark is drawn: it grows but never fills, never empties and never outshines its symbol (ADR-0059 §2).
@Suite("SkillMarkLook")
struct SkillMarkLookTests {
    @Test("Given a skill not grown yet, when drawn, then the symbol is 72% of its circle, in colour, with some wash")
    func notGrown() {
        let look = SkillMarkLook(growth: 0)
        #expect(look.symbolScale == 0.72)
        #expect(look.washOpacity > 0)
        #expect(look.glowOpacity == 0)
    }

    @Test("Given ever more growth, when drawn, then symbol, wash and glow grow with it, and the symbol never fills the circle")
    func growsWithTheSkill() {
        let looks = [0, 0.2, 0.5, 0.75, 0.999].map(SkillMarkLook.init(growth:))
        for (smaller, larger) in zip(looks, looks.dropFirst()) {
            #expect(larger.symbolScale > smaller.symbolScale)
            #expect(larger.washOpacity > smaller.washOpacity)
            #expect(larger.glowOpacity > smaller.glowOpacity)
            #expect(larger.glowRadius > smaller.glowRadius)
        }
        #expect(looks.allSatisfy { $0.symbolScale < 1 })
    }

    @Test("Given any growth, when drawn, then the wash stays at or under the tint's wash, so the symbol keeps its contrast")
    func washNeverAboveTheTint() {
        for growth in stride(from: 0.0, through: 1.0, by: 0.05) {
            #expect(SkillMarkLook(growth: growth).washOpacity <= SkillMarkLook.maxWashOpacity)
        }
        #expect(SkillMarkLook.maxWashOpacity == 0.15)
    }

    @Test("Given a growth out of range, when drawn, then it is held between 0 and 1")
    func clamped() {
        #expect(SkillMarkLook(growth: -1) == SkillMarkLook(growth: 0))
        #expect(SkillMarkLook(growth: 3).growth == 1)
    }
}
