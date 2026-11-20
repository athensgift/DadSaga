import Application
import CoreGraphics
import FilmKit
import Foundation
import ImageIO

/// Decodes a scene's photo for the film, no larger than the film's frame.
struct SagaFilmPhotoLoader: Sendable {
    let getPhoto: any GetPhotoUseCase

    /// The photo, upright as the store returns it and already decoded, so the encoder never decodes on a frame. A
    /// photo that can't be read comes back black: its scene keeps its words on the dark, and the film is still made
    /// (ADR-0037 §2).
    @concurrent
    func image(id: String, spec: FilmSpec) async throws -> CGImage {
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard let data = await getPhoto.execute(id: id, maxPixelSize: max(spec.width, spec.height)),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, options)
        else { return try Self.blank() }
        return image
    }

    /// A 2 × 2 black picture.
    private static func blank() throws -> CGImage {
        let context = CGContext(
            data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
        context?.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        context?.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        guard let image = context?.makeImage() else { throw SagaFilmRenderError.pictureNotDrawn }
        return image
    }
}
