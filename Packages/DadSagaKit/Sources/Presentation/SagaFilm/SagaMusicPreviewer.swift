import AVFoundation
import Foundation

/// Plays a track's start with `AVAudioPlayer` (ADR-0046 §3). The audio session is left at the default, like the
/// film's player: the Ring/Silent switch silences it.
@MainActor
public struct SagaMusicPreviewer: SagaMusicPreviewing {
    static let fadeSeconds = 1.5

    private let deck = Deck()

    public init() {}

    public func play(_ url: URL, seconds: Double) async {
        await deck.play(url, seconds: seconds, fadeSeconds: Self.fadeSeconds)
    }
}

/// Owns the one preview that plays, off the main thread: loading the file and `play()`, which activates the audio
/// session and can take hundreds of milliseconds when it pauses another app's audio, would otherwise freeze the
/// screen. Being one actor keeps "only one plays at a time": a new preview starts only after the last one's
/// `player.play()` returned, and stops it first.
private actor Deck {
    private var current: AVAudioPlayer?

    func play(_ url: URL, seconds: Double, fadeSeconds: Double) async {
        // A preview stopped before it began plays nothing: playing would pause another app's audio for no sound. It
        // also leaves alone a newer preview that reached the deck first.
        guard !Task.isCancelled else { return }
        current?.stop()
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        current = player
        defer {
            player.stop()
            if current === player { current = nil }
        }
        // Checked again because loading took time. When it can't play (during a call, say), the button offers
        // listening again at once instead of 20 s of silence.
        guard !Task.isCancelled, player.play() else { return }
        let length = min(seconds, player.duration)
        // `try?` swallows cancellation, so check before fading: a stopped preview stops at once.
        try? await Task.sleep(for: .seconds(max(0, length - fadeSeconds)))
        guard !Task.isCancelled else { return }
        player.setVolume(0, fadeDuration: fadeSeconds)
        try? await Task.sleep(for: .seconds(fadeSeconds))
    }
}
