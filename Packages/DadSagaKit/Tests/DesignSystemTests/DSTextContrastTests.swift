@testable import DesignSystem
import Testing

/// ADR-0033: secondary text reaches AA on the grounds it is drawn on, in both modes and with Increase Contrast.
@Suite("Secondary text contrast")
struct DSTextContrastTests {
    @Test("Given secondary text, when it is on the background or the surface, then it reaches AA in every mode")
    func secondaryText() {
        for pair in [DSText.secondary, DSText.secondaryIncreased] {
            for ground in DSTintContrastTests.lightGrounds {
                #expect(WCAG.contrast(pair.light, ground) >= WCAG.smallText, "light \(hex(pair.light)) on \(hex(ground))")
            }
            for ground in DSTintContrastTests.darkGrounds {
                #expect(WCAG.contrast(pair.dark, ground) >= WCAG.smallText, "dark \(hex(pair.dark)) on \(hex(ground))")
            }
        }
    }

    @Test("Given Increase Contrast, when secondary text changes, then it moves towards the primary text")
    func increasedContrastIsStronger() {
        #expect(WCAG.contrast(DSText.secondaryIncreased.light, 0xF2F2F7) > WCAG.contrast(DSText.secondary.light, 0xF2F2F7))
        #expect(WCAG.contrast(DSText.secondaryIncreased.dark, 0x000000) > WCAG.contrast(DSText.secondary.dark, 0x000000))
    }
}
