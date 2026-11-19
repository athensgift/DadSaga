import AVFoundation
import CoreGraphics

/// The film's pictures, frame by frame.
///
/// A clip's images load while the clip before it is written, and are let go when their clip ends, so at most two
/// clips' images are decoded at once (ADR-0036 §3). A clip that fades in does so from the last frame already written,
/// not from the previous clip's images.
enum VideoTrack {
    /// - Parameter written: called after each frame with the number of frames written so far.
    static func append(
        _ timeline: FilmTimeline,
        to receiver: AVAssetWriterInput.PixelBufferReceiver,
        written report: @Sendable (Int) -> Void
    ) async throws {
        // Finished however this ends: the writer holds the music back for as long as it expects more pictures.
        defer { receiver.finish() }
        guard let pool = receiver.pixelBufferPool else { throw FilmError.writerFailed("no pixel buffer pool") }
        let clips = timeline.clips
        let compositor = FrameCompositor(spec: timeline.spec)
        var written = 0
        var lastFrame: CVReadOnlyPixelBuffer?
        var images = try await load(clips.first)
        for (index, clip) in clips.enumerated() {
            async let upcoming = load(clips.dropFirst(index + 1).first)
            let shot = compositor.shot(of: clip, picture: images?.picture, overlay: images?.overlay)
            for local in 0..<clip.frames {
                try Task.checkCancellation()
                let fade = local < clip.fadeFrames ? lastFrame.map { earlier in
                    FadeIn(frame: earlier, progress: Double(local + 1) / Double(clip.fadeFrames + 1))
                } : nil
                let frame = try autoreleasepool {
                    let image = compositor.frame(of: shot, local: local)
                    let buffer = try pool.makeMutablePixelBuffer()
                    buffer.withUnsafeBuffer { compositor.render(image, fade: fade, into: $0) }
                    return CVReadOnlyPixelBuffer(buffer)
                }
                let time = CMTime(value: CMTimeValue(written), timescale: CMTimeScale(timeline.spec.framesPerSecond))
                try await receiver.append(frame, with: time)
                written += 1
                report(written)
                if local == clip.frames - 1 {
                    lastFrame = frame
                }
            }
            images = try await upcoming
        }
    }

    private struct Images: Sendable {
        let picture: CGImage?
        let overlay: CGImage?
    }

    private static func load(_ clip: FilmClip?) async throws -> Images? {
        guard let clip else { return nil }
        async let overlay = clip.overlay?()
        var picture: CGImage?
        if case .image(let loader) = clip.picture {
            picture = try await loader()
        }
        return Images(picture: picture, overlay: try await overlay)
    }
}
