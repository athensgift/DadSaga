import CoreGraphics
@testable import Data
import Domain
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
import Vision

/// Vision on the device (ADR-0046). Its numbers differ by device and OS, so only their shape is checked.
@Suite("VisionPhotoAnalyzer")
struct VisionPhotoAnalyzerTests {
    let analyzer = VisionPhotoAnalyzer()

    @Test("Given bytes that aren't a photo, when looking at them, then nothing is found and nothing throws")
    func notAPhoto() async {
        let bytes = Data("not a photo".utf8)

        #expect(await analyzer.rating(of: bytes) == nil)
        #expect(await analyzer.faces(in: bytes).isEmpty)
        #expect(await analyzer.salientObjects(in: bytes).isEmpty)
    }

    @Test("Given a photo of a bright square on dark, when looking at it, then whatever is found is in range")
    func answersInRange() async throws {
        let photo = try Self.jpeg()

        if let rating = await analyzer.rating(of: photo) {
            #expect((-1...1).contains(rating.score))
        }
        let regions = await analyzer.salientObjects(in: photo) + analyzer.faces(in: photo).map(\.region)
        for region in regions {
            #expect(region.left >= -1e-6 && region.top >= -1e-6 && region.right <= 1 + 1e-6 && region.bottom <= 1 + 1e-6)
        }
    }

    @Test("Given Vision's box from the lower left, when mapped, then it is the same box from the top left")
    func boxFromTheTopLeft() {
        let region = VisionPhotoAnalyzer.region(NormalizedRect(x: 0.1, y: 0.6, width: 0.2, height: 0.3))

        #expect(abs(region.left - 0.1) < 1e-9 && abs(region.top - 0.1) < 1e-9)
        #expect(abs(region.width - 0.2) < 1e-9 && abs(region.height - 0.3) < 1e-9)
    }

    /// 400 × 300, dark, with a bright square in its top left quarter.
    private static func jpeg() throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: 400, height: 300, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: 0.1, green: 0.1, blue: 0.15, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        context.setFillColor(CGColor(srgbRed: 1, green: 0.8, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 40, y: 180, width: 100, height: 100))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
