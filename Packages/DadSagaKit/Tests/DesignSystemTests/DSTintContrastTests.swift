@testable import DesignSystem
import Foundation
import Testing

/// ADR-0032: every tint is readable as text and as a fill, in both modes.
@Suite("Tint contrast")
struct DSTintContrastTests {
    /// The system grouped background and surface the tints sit on, as iOS draws them.
    private static let lightGrounds: [UInt32] = [0xF2F2F7, 0xFFFFFF]
    private static let darkGrounds: [UInt32] = [0x000000, 0x1C1C1E]
    /// WCAG 2.2 AA for small text.
    private static let minimum = 4.5

    @Test("Given each tint in light mode, when it is text on the background, the surface or its own wash, then it reaches AA")
    func lightText() {
        for tint in DSTint.all {
            for ground in Self.grounds(for: tint.light, on: Self.lightGrounds) {
                #expect(Self.contrast(tint.light, ground) >= Self.minimum, "\(hex(tint.light)) on \(hex(ground))")
            }
        }
    }

    @Test("Given each tint in dark mode, when it is text on the background, the surface or its own wash, then it reaches AA")
    func darkText() {
        for tint in DSTint.all {
            for ground in Self.grounds(for: tint.dark, on: Self.darkGrounds) {
                #expect(Self.contrast(tint.dark, ground) >= Self.minimum, "\(hex(tint.dark)) on \(hex(ground))")
            }
        }
    }

    @Test("Given each tint as a fill, when onTint is drawn on it, then it reaches AA in both modes")
    func onTint() {
        for tint in DSTint.all {
            #expect(Self.contrast(DSTint.onTint.light, tint.light) >= Self.minimum, "light \(hex(tint.light))")
            #expect(Self.contrast(DSTint.onTint.dark, tint.dark) >= Self.minimum, "dark \(hex(tint.dark))")
        }
    }

    @Test("Given the accent as the app tint, when the system draws a white symbol on it, then it reaches 3:1 in both modes")
    func systemSymbolsOnAccent() {
        #expect(Self.contrast(0xFFFFFF, DSTint.accent.light) >= 3)
        #expect(Self.contrast(0xFFFFFF, DSTint.accent.dark) >= 3)
    }

    // MARK: WCAG 2.2

    /// The plain grounds, and each one under the tint's own wash.
    private static func grounds(for tint: UInt32, on plain: [UInt32]) -> [UInt32] {
        plain + plain.map { blend(tint, over: $0, opacity: DSTint.washOpacity) }
    }

    private static func contrast(_ first: UInt32, _ second: UInt32) -> Double {
        let (lighter, darker) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func luminance(_ rgb: UInt32) -> Double {
        let linear = channels(rgb).map { value -> Double in
            let srgb = value / 255
            return srgb <= 0.039_28 ? srgb / 12.92 : pow((srgb + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }

    private static func blend(_ top: UInt32, over bottom: UInt32, opacity: Double) -> UInt32 {
        let mixed = zip(channels(top), channels(bottom)).map { UInt32(($0 * opacity + $1 * (1 - opacity)).rounded()) }
        return mixed[0] << 16 | mixed[1] << 8 | mixed[2]
    }

    private static func channels(_ rgb: UInt32) -> [Double] {
        [Double(rgb >> 16 & 0xFF), Double(rgb >> 8 & 0xFF), Double(rgb & 0xFF)]
    }
}

private func hex(_ rgb: UInt32) -> String {
    "#" + String(rgb, radix: 16, uppercase: true)
}
