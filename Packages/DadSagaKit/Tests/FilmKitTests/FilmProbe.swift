import AVFoundation
import CoreGraphics
import FilmKit
import Synchronization

/// Reads a written film back: its tracks, timing, format, the colour of a pixel at a moment and how loud it is.
enum FilmProbe {
    struct Pixel {
        let red: Int
        let green: Int
        let blue: Int
    }

    /// How the video track says it is encoded.
    struct VideoFormat {
        let isH264: Bool
        /// The H.264 `profile_idc`: 100 is High.
        let profile: UInt8?
        let primaries: String?
        let transfer: String?
        let matrix: String?
    }

    static func videoTrack(_ url: URL) async throws -> AVAssetTrack? {
        try await AVURLAsset(url: url).loadTracks(withMediaType: .video).first
    }

    static func audioTrack(_ url: URL) async throws -> AVAssetTrack? {
        try await AVURLAsset(url: url).loadTracks(withMediaType: .audio).first
    }

    static func videoFormat(_ url: URL) async throws -> VideoFormat? {
        guard let format = try await videoTrack(url)?.load(.formatDescriptions).first else { return nil }
        func text(_ key: CFString) -> String? {
            CMFormatDescriptionGetExtension(format, extensionKey: key) as? String
        }
        let atoms = CMFormatDescriptionGetExtension(
            format, extensionKey: kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms
        ) as? [String: Any]
        let configuration = atoms?["avcC"] as? Data
        return VideoFormat(
            isH264: format.mediaSubType == .h264,
            profile: configuration.flatMap { $0.count > 1 ? $0[$0.startIndex + 1] : nil },
            primaries: text(kCMFormatDescriptionExtension_ColorPrimaries),
            transfer: text(kCMFormatDescriptionExtension_TransferFunction),
            matrix: text(kCMFormatDescriptionExtension_YCbCrMatrix)
        )
    }

    /// The number of video frames, counted from the file's samples.
    static func frameCount(_ url: URL) async throws -> Int {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { return 0 }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        reader.add(output)
        reader.startReading()
        var count = 0
        while let sample = output.copyNextSampleBuffer() {
            count += CMSampleBufferGetNumSamples(sample)
        }
        return count
    }

    /// The pixel `across` and `down` the frame, from (0, 0) at the top left to (1, 1) at the bottom right, at `seconds`.
    static func pixel(_ url: URL, at seconds: Double, across: Double = 0.5, down: Double = 0.5) async throws -> Pixel {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let (image, _) = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600))
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        bytes.withUnsafeMutableBytes { raw in
            let context = CGContext(
                data: raw.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        let column = min(image.width - 1, Int(across * Double(image.width)))
        let row = min(image.height - 1, Int(down * Double(image.height)))
        let index = (row * image.width + column) * 4
        return Pixel(red: Int(bytes[index]), green: Int(bytes[index + 1]), blue: Int(bytes[index + 2]))
    }

    /// The sound's root mean square between two moments, from 0 (silence) to 1.
    static func loudness(_ url: URL, from start: Double, to end: Double) async throws -> Double {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return 0 }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ])
        reader.add(output)
        reader.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 48_000),
            end: CMTime(seconds: end, preferredTimescale: 48_000)
        )
        reader.startReading()
        var squares = 0.0
        var total = 0
        while let sample = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(sample) else { continue }
            var values = [Int16](repeating: 0, count: CMBlockBufferGetDataLength(block) / 2)
            values.withUnsafeMutableBytes { raw in
                guard let base = raw.baseAddress else { return }
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: raw.count, destination: base)
            }
            squares += values.reduce(0) { $0 + pow(Double($1) / Double(Int16.max), 2) }
            total += values.count
        }
        return total == 0 ? 0 : (squares / Double(total)).squareRoot()
    }
}

/// Pictures and sounds made in the test, so no binary fixtures are needed.
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

    /// A stereo sine tone, written as a CAF file.
    static func tone(seconds: Double, at url: URL) throws {
        let frames = AVAudioFrameCount(seconds * 48_000)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channels = buffer.floatChannelData
        else { throw Failure() }
        var settings = format.settings
        settings[AVLinearPCMIsNonInterleaved] = false
        let file = try AVAudioFile(forWriting: url, settings: settings)
        buffer.frameLength = frames
        for frame in 0..<Int(frames) {
            let sample = Float(0.3 * sin(2 * Double.pi * 440 * Double(frame) / 48_000))
            channels[0][frame] = sample
            channels[1][frame] = sample
        }
        try file.write(from: buffer)
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
