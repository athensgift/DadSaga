/// Whether the app follows the iPhone's light or dark look, or always uses one of them (ADR-0030).
public enum Appearance: Hashable, Sendable, CaseIterable {
    case system, light, dark
}

/// How the dad likes the app to look and feel on this iPhone. Not part of the saga: starting over keeps it.
public struct Preferences: Hashable, Sendable {
    public var appearance: Appearance
    /// Taps for cheers and celebrations.
    public var hapticsEnabled: Bool

    public init(appearance: Appearance = .system, hapticsEnabled: Bool = true) {
        self.appearance = appearance
        self.hapticsEnabled = hapticsEnabled
    }

    public static let `default` = Preferences()
}
