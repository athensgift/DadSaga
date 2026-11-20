import AVFoundation
import CoreGraphics

/// Reads a written film back: its tracks, timing, format, the colour of a pixel at a moment and how loud it is.
public enum FilmProbe {
    public struct Pixel: Sendable {
        public let red: Int
        public let green: Int
        public let blue: Int
    }

    /// How the video track says it is encoded.
    public struct VideoFormat: Sendable {
        public let isH264: Bool
        /// The H.264 `profile_idc`: 100 is High.
        public let profile: UInt8?
        public let primaries: String?
        public let transfer: String?
        public let matrix: String?
    }

    public static func videoTrack(_ url: URL) async throws -> AVAssetTrack? {
        try await AVURLAsset(url: url).loadTracks(withMediaType: .video).first
    }

    public static func audioTrack(_ url: URL) async throws -> AVAssetTrack? {
        try await AVURLAsset(url: url).loadTracks(withMediaType: .audio).first
    }

    public static func videoFormat(_ url: URL) async throws -> VideoFormat? {
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
    public static func frameCount(_ url: URL) async throws -> Int {
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
    public static func pixel(_ url: URL, at seconds: Double, across: Double = 0.5, down: Double = 0.5) async throws -> Pixel {
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
    public static func loudness(_ url: URL, from start: Double, to end: Double) async throws -> Double {
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
