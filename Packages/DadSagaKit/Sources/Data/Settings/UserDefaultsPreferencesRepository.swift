import Application
import Domain
import Foundation

/// Keeps the dad's preferences in the app's own defaults. Only the app reads them (ADR-0030).
public struct UserDefaultsPreferencesRepository: PreferencesRepository, @unchecked Sendable {
    // UserDefaults is thread-safe; it is just not marked Sendable.
    private let defaults: UserDefaults
    private let appearanceKey: String
    private let hapticsKey: String

    public init(
        defaults: UserDefaults = .standard,
        appearanceKey: String = "preferences.appearance",
        hapticsKey: String = "preferences.haptics"
    ) {
        self.defaults = defaults
        self.appearanceKey = appearanceKey
        self.hapticsKey = hapticsKey
    }

    /// Anything unknown or missing reads as the default.
    public func fetch() async -> Preferences {
        let appearance: Appearance = switch defaults.string(forKey: appearanceKey) {
        case "light": .light
        case "dark": .dark
        default: .system
        }
        let haptics = defaults.object(forKey: hapticsKey) as? Bool ?? Preferences.default.hapticsEnabled
        return Preferences(appearance: appearance, hapticsEnabled: haptics)
    }

    public func save(_ preferences: Preferences) async {
        let appearance = switch preferences.appearance {
        case .system: "system"
        case .light: "light"
        case .dark: "dark"
        }
        defaults.set(appearance, forKey: appearanceKey)
        defaults.set(preferences.hapticsEnabled, forKey: hapticsKey)
    }
}
