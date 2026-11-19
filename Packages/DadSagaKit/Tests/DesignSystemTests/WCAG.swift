import Foundation

/// WCAG 2.2 contrast, from 0xRRGGBB values.
enum WCAG {
    /// AA for small text.
    static let smallText = 4.5

    static func contrast(_ first: UInt32, _ second: UInt32) -> Double {
        let (lighter, darker) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))
        return (lighter + 0.05) / (darker + 0.05)
    }

    static func blend(_ top: UInt32, over bottom: UInt32, opacity: Double) -> UInt32 {
        let mixed = zip(channels(top), channels(bottom)).map { UInt32(($0 * opacity + $1 * (1 - opacity)).rounded()) }
        return mixed[0] << 16 | mixed[1] << 8 | mixed[2]
    }

    private static func luminance(_ rgb: UInt32) -> Double {
        let linear = channels(rgb).map { value -> Double in
            let srgb = value / 255
            return srgb <= 0.039_28 ? srgb / 12.92 : pow((srgb + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }

    private static func channels(_ rgb: UInt32) -> [Double] {
        [Double(rgb >> 16 & 0xFF), Double(rgb >> 8 & 0xFF), Double(rgb & 0xFF)]
    }
}

func hex(_ rgb: UInt32) -> String {
    "#" + String(rgb, radix: 16, uppercase: true)
}
