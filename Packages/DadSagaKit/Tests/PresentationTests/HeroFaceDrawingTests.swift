import CoreGraphics
@testable import HeroArt
import SwiftUI
import Testing

// The dad's features as the screen draws them (ADR-0044), read back from the pixels. Found on a device on 2026-11-26:
// the short beard began below the top of the smile, and the shaved head's shadow stood out above the scalp.

@MainActor
struct HeroFaceDrawingTests {
    /// Points to pixels.
    nonisolated private static let scale: CGFloat = 4
    /// The head is drawn 24 pt above its view's centre; this canvas puts the centre of the head at (30, 30).
    nonisolated private static let canvas: CGFloat = 60
    nonisolated private static let headTop: CGFloat = 10

    @Test("Given a short beard, when the hero smiles, then the beard is behind the whole smile")
    func shortBeardIsBehindTheSmile() throws {
        let face = try Pixels(features: HeroFeatures(beard: .short))
        // Just above the middle of the smile, whose top edge dips to y 39; the forehead is plain skin.
        let aboveSmile = CGPoint(x: 30, y: 38)
        let forehead = face.red(at: CGPoint(x: 30, y: 20))
        #expect(face.alpha(at: aboveSmile) == 255)
        #expect(forehead > 0.5, "the forehead should be skin: red \(forehead)")
        let red = face.red(at: aboveSmile)
        #expect(red < 0.5, "skin shows between the smile and the beard: red \(red)")
    }

    @Test("Given a shaved head, when drawn, then nothing shows above the scalp")
    func shavedHairStaysOnTheHead() throws {
        let face = try Pixels(features: HeroFeatures(hair: .shaved, beard: .none))
        let rows = 0..<Int((Self.headTop - 0.5) * Self.scale)
        let columns = 0..<Int(Self.canvas * Self.scale)
        var drawn: [String] = []
        for row in rows {
            for column in columns where face.alpha(column: column, row: row) > 0 { drawn.append("(\(column), \(row))") }
        }
        #expect(drawn.isEmpty, "\(drawn.count) pixels above the head, the first at \(drawn.first ?? "") px")
        // The head is where the rows above assume, and the shadow is on it: darker than the skin below it.
        #expect(face.alpha(at: CGPoint(x: 30, y: Self.headTop + 0.5)) > 0)
        let shadow = face.red(at: CGPoint(x: 30, y: 12))
        let skin = face.red(at: CGPoint(x: 30, y: 22))
        #expect(shadow < skin - 0.02, "no shadow on the scalp: red \(shadow), skin \(skin)")
    }

    /// The head alone, rendered at `scale` on a transparent canvas.
    private struct Pixels {
        let bytes: [UInt8]
        let width: Int

        @MainActor
        init(features: HeroFeatures) throws {
            let view = HeroHead(pose: .rest, isCheering: false, glasses: .none)
                .environment(\.heroFeatures, features)
                .offset(y: 24)
                .frame(width: HeroFaceDrawingTests.canvas, height: HeroFaceDrawingTests.canvas)
            let renderer = ImageRenderer(content: view)
            renderer.scale = HeroFaceDrawingTests.scale
            let image = try #require(renderer.cgImage)
            width = image.width
            let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
            var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
            let context = try #require(CGContext(
                data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            self.bytes = bytes
        }

        func alpha(column: Int, row: Int) -> UInt8 { bytes[(row * width + column) * 4 + 3] }

        /// The alpha of a point, in points from the canvas's top left.
        func alpha(at point: CGPoint) -> UInt8 {
            alpha(column: Int(point.x * HeroFaceDrawingTests.scale), row: Int(point.y * HeroFaceDrawingTests.scale))
        }

        /// The red of a point, in points from the canvas's top left: skin is light, the beard dark.
        func red(at point: CGPoint) -> Double {
            let index = (Int(point.y * HeroFaceDrawingTests.scale) * width + Int(point.x * HeroFaceDrawingTests.scale)) * 4
            return Double(bytes[index]) / max(Double(bytes[index + 3]), 1)
        }
    }
}
