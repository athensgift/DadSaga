import CoreGraphics
import DesignSystem
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@Suite("Decoded image")
struct DecodedImageTests {
    /// A plain JPEG of the given size, made here.
    static func jpeg(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(red: 0.9, green: 0.7, blue: 0.4, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test("Given a portrait photo, when it is decoded small, then it keeps its shape")
    func keepsShape() async throws {
        let decoded = try #require(await DecodedImage.decode(Self.jpeg(width: 600, height: 800), maxPixelSize: 80))
        #expect(abs(decoded.aspectRatio - 0.75) < 0.02)
    }

    @Test("Given bytes that are not an image, when they are checked or decoded, then they are refused")
    func refusesNonImages() async {
        let text = Data("not a photo".utf8)
        #expect(!DecodedImage.isImage(text))
        #expect(await DecodedImage.decode(text, maxPixelSize: 100) == nil)
    }

    @Test("Given a photo, when it is checked, then it is an image")
    func acceptsPhotos() throws {
        #expect(DecodedImage.isImage(try Self.jpeg(width: 40, height: 30)))
    }
}
