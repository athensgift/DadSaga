import AVFoundation

/// The film's sound: the music looped or trimmed to the film's length with a fade at its end, read as PCM and appended
/// to the writer's audio input. Everything here stays inside the one task that calls `append`.
enum MusicBed {
    /// The shortest music that is looped; anything shorter would be repeated thousands of times under a film.
    static let shortestLoop = CMTime(value: 1, timescale: 2)
    /// How far before the film's end the sound may stop and still count as whole: about two AAC packets.
    static let endTolerance = CMTime(value: 1, timescale: 20)

    static func append(
        _ music: FilmMusic,
        duration: CMTime,
        spec: FilmSpec,
        to receiver: AVAssetWriterInput.SampleBufferReceiver
    ) async throws {
        // Finished however this ends: the writer holds the pictures back for as long as it expects more sound.
        defer { receiver.finish() }
        // Exact timing, so a loop starts where the music really ends.
        let source = AVURLAsset(url: music.url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        guard let sourceTrack = try await source.loadTracks(withMediaType: .audio).first else {
            throw FilmError.musicHasNoAudio(music.url)
        }
        // The track's own range: the file may hold other, longer tracks, and its sound may not start at zero.
        let sourceRange = try await sourceTrack.load(.timeRange)
        guard sourceRange.duration.isNumeric, sourceRange.duration >= shortestLoop else {
            throw FilmError.musicTooShort(music.url)
        }

        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw FilmError.musicHasNoAudio(music.url) }
        var cursor = CMTime.zero
        while cursor < duration {
            let chunk = CMTimeMinimum(sourceRange.duration, duration - cursor)
            try track.insertTimeRange(CMTimeRange(start: sourceRange.start, duration: chunk), of: sourceTrack, at: cursor)
            cursor = CMTimeAdd(cursor, chunk)
        }

        let fade = CMTimeMinimum(CMTime(seconds: music.fadeOutSeconds, preferredTimescale: 600), duration)
        let parameters = AVMutableAudioMixInputParameters(track: track)
        if fade > .zero {
            let ending = CMTimeRange(start: duration - fade, duration: fade)
            parameters.setVolumeRamp(fromStartVolume: 1, toEndVolume: 0, timeRange: ending)
        }
        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]

        let reader = try AVAssetReader(asset: composition)
        let output = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: spec.audioSampleRate,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ])
        output.audioMix = mix
        reader.timeRange = CMTimeRange(start: .zero, duration: duration)
        // Like the writer's receivers, asking for a provider adds its output to the reader.
        let provider = reader.outputProvider(for: output)
        try reader.start()
        var end = CMTime.zero
        while let sample = try await provider.next() {
            try Task.checkCancellation()
            end = CMTimeMaximum(end, sample.presentationTimeStamp + sample.duration)
            try await receiver.append(sample)
        }
        // A damaged file can run out of sound early; the film must not go quiet without a word.
        guard reader.status == .completed, duration - end <= endTolerance else {
            throw reader.error ?? FilmError.musicUnreadable(music.url)
        }
    }
}
