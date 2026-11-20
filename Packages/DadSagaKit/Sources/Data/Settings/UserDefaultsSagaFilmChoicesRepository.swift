import Application
import Foundation

/// Keeps what the film sheet remembers in the app's own defaults (ADR-0041 §5, ADR-0046 §4).
public struct UserDefaultsSagaFilmChoicesRepository: SagaFilmChoicesRepository, @unchecked Sendable {
    // UserDefaults is thread-safe; it is just not marked Sendable.
    private let defaults: UserDefaults
    /// Unchanged since ADR-0041, so a stored switch carries over. A missing value reads as on.
    private static let showsDatesKey = "sagaFilm.showsDates"
    /// A missing value reads as `nil`: nothing chosen yet.
    private static let soundtrackIDKey = "sagaFilm.soundtrackID"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func showsDates() async -> Bool {
        defaults.object(forKey: Self.showsDatesKey) as? Bool ?? true
    }

    public func setShowsDates(_ showsDates: Bool) async {
        defaults.set(showsDates, forKey: Self.showsDatesKey)
    }

    public func soundtrackID() async -> String? {
        defaults.string(forKey: Self.soundtrackIDKey)
    }

    public func setSoundtrackID(_ id: String) async {
        defaults.set(id, forKey: Self.soundtrackIDKey)
    }
}
