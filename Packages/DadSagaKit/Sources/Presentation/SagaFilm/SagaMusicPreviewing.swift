import Foundation

/// Plays a track for the dad to hear before he chooses it (ADR-0046 §3). The view model holds this protocol, so it
/// needs no AVFoundation; `SagaMusicPreviewer` is the implementation.
@MainActor
public protocol SagaMusicPreviewing: Sendable {
    /// Plays `url` from its start for at most `seconds`, fading out at the end. Returns once it has played, or as
    /// soon as its task is cancelled, with the sound stopped either way. Never throws: a file that can't be played
    /// returns at once.
    func play(_ url: URL, seconds: Double) async
}
