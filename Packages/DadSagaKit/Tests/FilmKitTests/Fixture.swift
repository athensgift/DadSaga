import CoreGraphics
import FilmKit
import Foundation
import Synchronization

/// Pictures and films made in the test, so no binary fixtures are needed. Sounds come from `FilmTone`.
enum Fixture {
    struct Failure: Error {}

    static let portrait = FilmSpec(width: 180, height: 320)
    static let landscape = FilmSpec(width: 320, height: 180)

    static func temporaryURL(_ name: String = UUID().uuidString, extension pathExtension: String = "mp4") -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("filmkit-\(name)").appendingPathExtension(pathExtension)
    }

    /// Clips of one colour each; all but the first come in with `transition`.
    static func solids(_ colors: [FilmColor], frames: Int = 30, transition: FilmTransition = .cut) -> [FilmClip] {
        colors.enumerated().map { index, color in
            FilmClip(frames: frames, picture: .solid(color), transitionIn: index == 0 ? .cut : transition)
        }
    }

    /// A film of one colour per clip.
    static func solidFilm(
        _ colors: [FilmColor],
        frames: Int = 30,
        spec: FilmSpec = portrait,
        music: FilmMusic? = nil
    ) -> FilmTimeline {
        FilmTimeline(spec: spec, clips: solids(colors, frames: frames), music: music)
    }

    /// Writes the film to a temporary file, which the test deletes.
    static func encode(_ timeline: FilmTimeline) async throws -> URL {
        let url = temporaryURL()
        try await FilmEncoder().encode(timeline, to: url)
        return url
    }

    static let red = FilmColor(red: 1, green: 0, blue: 0)
    static let green = FilmColor(red: 0, green: 1, blue: 0)
    static let blue = FilmColor(red: 0, green: 0, blue: 1)

    /// One pixel of a generated image; opaque unless said otherwise.
    struct Paint {
        var red: UInt8 = 0
        var green: UInt8 = 0
        var blue: UInt8 = 0
        var alpha: UInt8 = 255

        static let clear = Paint(alpha: 0)
        static let white = Paint(red: 255, green: 255, blue: 255)
        static let grey = Paint(red: 90, green: 90, blue: 90)
    }

    /// An image `width` × `height`; `color` gives each pixel's colour from its column and row.
    static func image(width: Int, height: Int, color: (Int, Int) -> Paint) throws -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            for column in 0..<width {
                let paint = color(column, row)
                let index = (row * width + column) * 4
                bytes[index] = paint.red
                bytes[index + 1] = paint.green
                bytes[index + 2] = paint.blue
                bytes[index + 3] = paint.alpha
            }
        }
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let image = bytes.withUnsafeMutableBytes { raw in
            CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )?.makeImage()
        }
        guard let image else { throw Failure() }
        return image
    }
}

/// Makes images and counts how many of them are still in memory, to see what an encode holds on to.
final class ImageLedger: Sendable {
    private struct Count {
        var alive = 0
        var most = 0
    }

    private let count = Mutex(Count())

    /// The most images that were alive at once.
    var most: Int { count.withLock { $0.most } }
    var alive: Int { count.withLock { $0.alive } }

    /// A grey image whose pixels tell the ledger when they are freed.
    func image(width: Int, height: Int) throws -> CGImage {
        let size = width * height * 4
        let pixels = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 16)
        pixels.initializeMemory(as: UInt8.self, repeating: 90, count: size)
        let provider = CGDataProvider(
            dataInfo: Unmanaged.passRetained(self).toOpaque(), data: pixels, size: size
        ) { info, data, _ in
            data.deallocate()
            guard let info else { return }
            Unmanaged<ImageLedger>.fromOpaque(info).takeRetainedValue().count.withLock { $0.alive -= 1 }
        }
        let image = provider.flatMap { provider in
            CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
            )
        }
        guard let image else { throw Fixture.Failure() }
        count.withLock {
            $0.alive += 1
            $0.most = max($0.most, $0.alive)
        }
        return image
    }
}
