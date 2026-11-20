import AVFoundation

/// A sound made in the test, so no audio fixture is needed.
public enum FilmTone {
    public struct Failure: Error {}

    /// Writes a stereo 440 Hz sine tone as a CAF file.
    public static func write(seconds: Double, to url: URL) throws {
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
