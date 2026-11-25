import UIKit
import XCTest

/// A label's contrast against a shaded ground, read from the screen like Xcode's audit, but with the shades of the
/// ground counted as one colour.
///
/// The audit's detector (`AXAuditContrastDetectionManager`) reads five rows across the middle of the element and
/// compares its two most frequent exact colours, taking them for the ground and the text. That holds on a flat ground.
/// iOS 27 shades a Liquid Glass fill by a level or two of 255 from top to bottom, so one row in five lands on a second
/// shade, which outnumbers the label's pixels: the audit compares the fill with itself and fails whatever the label's
/// colour. Measured on iOS 27.2, from the detector itself (ADR-0035):
/// - "I did it!": two shades of the blue fill, 1.01:1; the white label, 4% of the pixels, is never compared;
/// - "Add a child": two shades of the glass, 1.02:1; its label is the accent itself, `#3755CD`, 6.0:1 on the glass;
/// - a stock `.glass` button on a plain ground fails the same way with a black label (20:1), and passes with the
///   same colours once the label is heavy enough to outnumber the second shade.
@MainActor
enum LabelContrast {
    /// WCAG AA for small text.
    static let smallText = 4.5
    /// Colours closer than this are shades of one ground: the shades of glass are 1.01–1.04:1 apart.
    private static let oneGround = 1.1

    /// The label's contrast where the audit compared the ground with itself: the two most frequent colours are shades
    /// of one ground, and the label is the most frequent colour that is not. `nil` where the audit did read two
    /// different colours, so its own verdict stands, or where there is nothing but ground.
    static func ratioOnShadedGround(of element: XCUIElement) -> Double? {
        let colours = sampledColours(of: element.screenshot().image).sorted { $0.value > $1.value }.map(\.key)
        guard colours.count > 1, contrast(colours[0], colours[1]) < oneGround,
              let label = colours.first(where: { contrast($0, colours[0]) >= oneGround })
        else { return nil }
        return contrast(label, colours[0])
    }

    /// How often each colour occurs on the rows the audit reads: five, from 30% to 70% of the height, without the
    /// outer eighths of the width.
    private static func sampledColours(of image: UIImage) -> [UInt32: Int] {
        guard let cgImage = image.cgImage else { return [:] }
        let (width, height) = (cgImage.width, cgImage.height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let isDrawn = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard isDrawn else { return [:] }
        var counts: [UInt32: Int] = [:]
        for row in [0.3, 0.4, 0.5, 0.6, 0.7].map({ Int(Double(height) * $0) }) {
            for column in (width / 8)..<(width - width / 8) {
                let pixel = (row * width + column) * 4
                let colour = UInt32(pixels[pixel]) << 16 | UInt32(pixels[pixel + 1]) << 8 | UInt32(pixels[pixel + 2])
                counts[colour, default: 0] += 1
            }
        }
        return counts
    }

    private static func contrast(_ first: UInt32, _ second: UInt32) -> Double {
        let (lighter, darker) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func luminance(_ rgb: UInt32) -> Double {
        let linear = [rgb >> 16 & 0xFF, rgb >> 8 & 0xFF, rgb & 0xFF].map { channel -> Double in
            let srgb = Double(channel) / 255
            return srgb <= 0.039_28 ? srgb / 12.92 : pow((srgb + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }
}
