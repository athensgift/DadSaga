@testable import DesignSystem
import Foundation
import Testing

/// ADR-0032: every tint is readable as text and as a fill, in both modes.
@Suite("Tint contrast")
struct DSTintContrastTests {
    /// The system grouped background and surface the tints sit on, as iOS draws them.
    static let lightGrounds: [UInt32] = [0xF2F2F7, 0xFFFFFF]
    static let darkGrounds: [UInt32] = [0x000000, 0x1C1C1E]

    @Test("Given each tint in light mode, when it is text on the background, the surface or its own wash, then it reaches AA")
    func lightText() {
        for tint in DSTint.all {
            for ground in Self.grounds(for: tint.light, on: Self.lightGrounds) {
                #expect(WCAG.contrast(tint.light, ground) >= WCAG.smallText, "\(hex(tint.light)) on \(hex(ground))")
            }
        }
    }

    @Test("Given each tint in dark mode, when it is text on the background, the surface or its own wash, then it reaches AA")
    func darkText() {
        for tint in DSTint.all {
            for ground in Self.grounds(for: tint.dark, on: Self.darkGrounds) {
                #expect(WCAG.contrast(tint.dark, ground) >= WCAG.smallText, "\(hex(tint.dark)) on \(hex(ground))")
            }
        }
    }

    @Test("Given each tint as a fill, when onTint is drawn on it, then it reaches AA in both modes")
    func onTint() {
        for tint in DSTint.all {
            #expect(WCAG.contrast(DSTint.onTint.light, tint.light) >= WCAG.smallText, "light \(hex(tint.light))")
            #expect(WCAG.contrast(DSTint.onTint.dark, tint.dark) >= WCAG.smallText, "dark \(hex(tint.dark))")
        }
    }

    @Test("Given the accent as the app tint, when the system draws a white symbol on it, then it reaches 3:1 in both modes")
    func systemSymbolsOnAccent() {
        #expect(WCAG.contrast(0xFFFFFF, DSTint.accent.light) >= 3)
        #expect(WCAG.contrast(0xFFFFFF, DSTint.accent.dark) >= 3)
    }

    @Test("Given a skill's symbol half coloured in, when drawn on its wash, then its pale part and its level both show")
    func ghostOnWash() {
        // On the surface, where the skills' panel draws them (ADR-0059 §2).
        for (accent, surface) in [(DSTint.accent.light, UInt32(0xFFFFFF)), (DSTint.accent.dark, 0x1C1C1E)] {
            let wash = WCAG.blend(accent, over: surface, opacity: DSTint.washOpacity)
            let ghost = WCAG.blend(accent, over: wash, opacity: DSTint.ghostOpacity)
            // The whole shape shows on the circle, and the coloured part stands out from the pale part: 2:1 each.
            // 3:1 for one would leave the other under 2:1.
            #expect(WCAG.contrast(ghost, wash) >= 2, "pale \(hex(ghost)) on \(hex(wash))")
            #expect(WCAG.contrast(accent, ghost) >= 2, "\(hex(accent)) beside \(hex(ghost))")
            #expect(WCAG.contrast(ghost, wash) * WCAG.contrast(accent, ghost) < 6)
        }
    }

    // MARK: Grounds

    /// The plain grounds, and each one under the tint's own wash.
    private static func grounds(for tint: UInt32, on plain: [UInt32]) -> [UInt32] {
        plain + plain.map { WCAG.blend(tint, over: $0, opacity: DSTint.washOpacity) }
    }
}
