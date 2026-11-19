import Foundation

/// The saga film's music and its credits (`soundtracks.json`), in a target of their own so only the app carries them:
/// the widget links `Data` and never plays music (ADR-0036 §8). Read through `BundledSoundtrackRepository`.
public enum SagaMusic {
    public static let bundle = Bundle.module
}
