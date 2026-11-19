import Domain

/// The light/dark choice as screens show it.
public enum AppearanceChoice: CaseIterable, Hashable, Sendable {
    case system, light, dark
}

/// The dad's preferences as the root and Settings hold them (ADR-0030).
public struct PreferencesChoice: Equatable, Sendable {
    public var appearance: AppearanceChoice
    /// Whether cheers and celebrations tap the iPhone.
    public var isHapticsEnabled: Bool

    public init(appearance: AppearanceChoice = .system, isHapticsEnabled: Bool = true) {
        self.appearance = appearance
        self.isHapticsEnabled = isHapticsEnabled
    }
}

extension PreferencesChoice {
    init(_ preferences: Preferences) {
        self.init(appearance: AppearanceChoice(preferences.appearance), isHapticsEnabled: preferences.hapticsEnabled)
    }

    var domain: Preferences {
        Preferences(appearance: appearance.domain, hapticsEnabled: isHapticsEnabled)
    }
}

extension AppearanceChoice {
    init(_ appearance: Appearance) {
        switch appearance {
        case .system: self = .system
        case .light: self = .light
        case .dark: self = .dark
        }
    }

    var domain: Appearance {
        switch self {
        case .system: .system
        case .light: .light
        case .dark: .dark
        }
    }
}
