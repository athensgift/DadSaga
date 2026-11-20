import ImageIO
import SwiftUI

/// A photo decoded for the screen: upright, no larger than it is shown, and its shape (width over height).
/// It is decorative to VoiceOver; the control around it says what it is.
public struct DecodedImage {
    public let image: Image
    /// The same picture, for UIKit (the full-screen viewer's zooming).
    public let cgImage: CGImage
    public let aspectRatio: CGFloat

    /// Decodes `data` (JPEG, HEIC, PNG…) off the calling actor, no larger than `maxPixelSize` on its longest side,
    /// so a 48 MP photo never lands on the main thread at full size. `nil` if it is not an image.
    public static func decode(_ data: Data, maxPixelSize: Int) async -> DecodedImage? {
        guard let cgImage = await downsample(data, maxPixelSize: max(maxPixelSize, 1)), cgImage.height > 0 else {
            return nil
        }
        return DecodedImage(cgImage: cgImage)
    }

    /// Whether `data` is an image this can decode, without decoding it.
    public static func isImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceGetType(source) != nil && CGImageSourceGetCount(source) > 0
    }

    private init(cgImage: CGImage) {
        image = Image(decorative: cgImage, scale: 1)
        self.cgImage = cgImage
        aspectRatio = CGFloat(cgImage.width) / CGFloat(cgImage.height)
    }

    @concurrent
    private static func downsample(_ data: Data, maxPixelSize: Int) async -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

public extension Image {
    /// An image from small encoded data, decoded where it is called, or `nil` if it cannot be decoded.
    /// For the widget, which draws once and synchronously from a thumbnail; an app screen uses `DecodedImage.decode`.
    init?(imageData: Data) {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        self.init(decorative: image, scale: 1)
    }
}
