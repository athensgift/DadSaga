import AVFoundation

public enum FilmError: Error, Equatable {
    case emptyTimeline
    /// A width or height that is not positive and even, or a rate that is not positive.
    case invalidSpec(FilmSpec)
    /// A fade-out that is negative or not a number.
    case invalidFadeOut
    case musicHasNoAudio(URL)
    /// Music too short to loop under a film.
    case musicTooShort(URL)
    /// Music that ends before its file says it does: a damaged file.
    case musicUnreadable(URL)
    case writerFailed(String)
    /// The device ran out of room while the film was being written.
    case notEnoughSpace
}

/// Writes a `FilmTimeline` to an MP4 file (ADR-0036 §3).
///
/// Every frame is drawn with Core Image into a buffer from the writer's pool and appended through the async
/// `PixelBufferReceiver`; the music is appended at the same time from another child task, so the writer can interleave
/// the two. Images load one clip ahead. The work runs off the caller's actor (`@concurrent`). Cancelling the calling
/// task stops the writer, deletes the file and throws `CancellationError`; a failure in either track stops the other
/// and deletes the file too. A full disk is `FilmError.notEnoughSpace`, whatever the writer called it.
public struct FilmEncoder: Sendable {
    public init() {}

    /// Anything already at `url` is deleted first, once the timeline has passed its checks.
    ///
    /// - Parameter progress: called off the main actor after each frame with a rising value below 1, and with 1 once
    ///   the file is complete. A film that fails or is cancelled never reaches 1.
    @concurrent
    public func encode(
        _ timeline: FilmTimeline,
        to url: URL,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws {
        try timeline.validate()
        try? FileManager.default.removeItem(at: url)
        let spec = timeline.spec
        let frameCount = timeline.frameCount
        let duration = CMTime(value: CMTimeValue(frameCount), timescale: CMTimeScale(spec.framesPerSecond))

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true
        // Asking for a receiver adds its input to the writer, so the inputs are never passed to `writer.add`. An input
        // added twice gets a second track that no one feeds, and the writer then holds the fed one back for ever,
        // waiting to interleave the two: `append` stops returning a few dozen frames in.
        let video = Handoff(writer.inputPixelBufferReceiver(
            for: Self.input(.video, settings: Self.videoSettings(spec)),
            pixelBufferAttributes: Self.pixelAttributes(spec)
        ))
        let audio = timeline.music.map { music in
            (music, Handoff(writer.inputReceiver(for: Self.input(.audio, settings: Self.audioSettings(spec)))))
        }

        do {
            try writer.start()
            writer.startSession(atSourceTime: .zero)
            try await withThrowingTaskGroup { group in
                group.addTask {
                    // Finishing the file is the last step, so the last frame stops short of 1.
                    try await VideoTrack.append(timeline, to: video.value) { written in
                        progress(Double(written) / Double(frameCount + 1))
                    }
                }
                if let (music, receiver) = audio {
                    group.addTask {
                        try await MusicBed.append(music, duration: duration, spec: spec, to: receiver.value)
                    }
                }
                // Leaving at the first failure cancels the other track; `waitForAll` would let it write to its end.
                for try await _ in group {}
            }
            writer.endSession(atSourceTime: duration)
            await writer.finishWriting()
            guard writer.status == .completed else {
                throw FilmError.writerFailed(writer.error?.localizedDescription ?? "status \(writer.status.rawValue)")
            }
            progress(1)
        } catch {
            // Asked while the part of the film already written still takes its room: deleting it first would free
            // enough for the probe to pass on a full disk.
            let isFull = !Task.isCancelled && Self.ranOutOfSpace(error, writerError: writer.error, beside: url)
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: url)
            if Task.isCancelled { throw CancellationError() }
            throw isFull ? FilmError.notEnoughSpace : error
        }
    }

    /// Whether `error`, or an error under it, says the disk is full.
    public static func isOutOfSpace(_ error: any Error) -> Bool {
        var next: NSError? = error as NSError
        while let current = next {
            switch (current.domain, current.code) {
            case (AVFoundationErrorDomain, AVError.Code.diskFull.rawValue),
                 (NSCocoaErrorDomain, NSFileWriteOutOfSpaceError),
                 (NSPOSIXErrorDomain, Int(ENOSPC)):
                return true
            default:
                next = current.userInfo[NSUnderlyingErrorKey] as? NSError
            }
        }
        return false
    }

    /// The writer often reports a full disk only as an unknown error. So when the writer itself failed, a small
    /// write beside the film tells which it was, without asking iOS for the free space, a required-reason API (as a
    /// copy of the saga does, ADR-0057 §6).
    private static func ranOutOfSpace(_ error: any Error, writerError: (any Error)?, beside url: URL) -> Bool {
        if isOutOfSpace(error) { return true }
        guard let writerError else { return false }
        if isOutOfSpace(writerError) { return true }
        let probe = url.deletingLastPathComponent().appending(path: "space-probe-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: probe) }
        do {
            try Data(count: 256 * 1024).write(to: probe)
            return false
        } catch {
            return isOutOfSpace(error)
        }
    }

    private static func input(_ mediaType: AVMediaType, settings: [String: Any]) -> AVAssetWriterInput {
        let input = AVAssetWriterInput(mediaType: mediaType, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        return input
    }

    private static func pixelAttributes(_ spec: FilmSpec) -> CVPixelBufferCreationAttributes {
        CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA),
            size: CVImageSize(width: spec.width, height: spec.height)
        )
    }

    private static func videoSettings(_ spec: FilmSpec) -> [String: Any] {
        [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: spec.width,
            AVVideoHeightKey: spec.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: spec.videoBitRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: spec.framesPerSecond,
                AVVideoMaxKeyFrameIntervalKey: spec.framesPerSecond * 2
            ],
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ]
        ]
    }

    private static func audioSettings(_ spec: FilmSpec) -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: spec.audioSampleRate,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: spec.audioBitRate
        ]
    }
}

private extension FilmTimeline {
    /// Refuses what the writer would choke on or loop over: `FilmError` instead of a crash, a hang or a broken file.
    func validate() throws {
        guard frameCount > 0 else { throw FilmError.emptyTimeline }
        guard spec.isEncodable else { throw FilmError.invalidSpec(spec) }
        if let music, !(music.fadeOutSeconds.isFinite && music.fadeOutSeconds >= 0) {
            throw FilmError.invalidFadeOut
        }
    }
}

/// Moves one of the writer's receivers into the one child task that appends to it. The receivers aren't `Sendable`,
/// and region checking can't follow a value from the encoder into a task group's child; each box is made once and used
/// by exactly one task, and the encoder never touches the receiver again.
private struct Handoff<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
