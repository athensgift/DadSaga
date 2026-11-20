import AVFoundation
import Foundation

/// Plays a track's start with `AVAudioPlayer` (ADR-0046 §3). The audio session is left at the default, like the
/// film's player: the Ring/Silent switch silences it.
@MainActor
public struct SagaMusicPreviewer: SagaMusicPreviewing {
    static let fadeSeconds = 1.5

    public init() {}

    public func play(_ url: URL, seconds: Double) async {
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        defer { player.stop() }
        player.play()
        let length = min(seconds, player.duration)
        // `try?` swallows cancellation, so check before fading: a stopped preview stops at once.
        try? await Task.sleep(for: .seconds(max(0, length - Self.fadeSeconds)))
        guard !Task.isCancelled else { return }
        player.setVolume(0, fadeDuration: Self.fadeSeconds)
        try? await Task.sleep(for: .seconds(Self.fadeSeconds))
    }
}
