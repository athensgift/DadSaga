import Application
import CoreGraphics
import FilmKit
import Foundation
import ImageIO

/// Decodes a scene's photo for the film, as the store keeps it, and aims its glide at its subject.
struct SagaFilmPhotoLoader: Sendable {
    /// Which way a photo glides: towards its close-up, or away from it.
    enum Glide {
        case inward, outward
    }

    /// How close the camera may come to a photo's subject (ADR-0047 §3).
    static let subjectZoomLimit = 1.4
    /// Where a glide ends when the photo has no subject: a little closer, towards the upper middle, where faces
    /// usually are. Near enough to the middle that the glide never moves a photo's edge into the frame.
    static let closeUp = FilmCamera(zoom: 1.12, centerX: 0.5, centerY: 0.45)

    let getPhoto: any GetPhotoUseCase
    let findSubject: any FindPhotoSubjectUseCase

    /// The photo, upright as the store returns it and already decoded, so the encoder never decodes on a frame. It is
    /// asked for at the size the store keeps, a little over the film's 1920: its file comes back as it is, never as a
    /// JPEG of a JPEG (ADR-0042 §1), and `FilmKit` scales it as it draws.
    ///
    /// A photo that can't be read comes back black: a first's or a boss's scene keeps its words on the dark, and the
    /// film is still made (ADR-0037 §2). A photo shown alone is checked before the film starts and left out
    /// (ADR-0075), so black alone is only the last resort, for a file whose header reads and whose pixels don't.
    ///
    /// The subject is looked for here, one clip ahead of the one being written, so it costs the film no time of its
    /// own. `glide` is the way the photo glides when no child is found in it: with a child, it always moves in on
    /// them. `nil` for a photo that stays still: its subject isn't looked for.
    @concurrent
    func photo(id: String, spec: FilmSpec, glide: Glide?) async throws -> FilmPhoto {
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard let data = await getPhoto.execute(id: id, maxPixelSize: StoredPhoto.longestSide),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, options)
        else { return FilmPhoto(try Self.blank(), motion: glide.map { Self.motion($0, closeUp: Self.closeUp) }) }
        guard var glide else { return FilmPhoto(image) }
        var closeUp = Self.closeUp
        if let framing = await findSubject.execute(photo: data) {
            let subject = framing.region
            closeUp = FilmCamera.closest(
                on: FilmRegion(left: subject.left, top: subject.top, width: subject.width, height: subject.height),
                pictureSize: CGSize(width: image.width, height: image.height),
                spec: spec,
                maxZoom: Self.subjectZoomLimit
            )
            if framing.showsChild {
                glide = .inward
            }
        }
        return FilmPhoto(image, motion: Self.motion(glide, closeUp: closeUp))
    }

    /// In, from the whole photo to its close-up, or out again.
    static func motion(_ glide: Glide, closeUp: FilmCamera) -> FilmMotion {
        switch glide {
        case .inward: .kenBurns(start: FilmCamera(), end: closeUp)
        case .outward: .kenBurns(start: closeUp, end: FilmCamera())
        }
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
