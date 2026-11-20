import Application
import Foundation

/// Keeps the film sheet's dates switch in the app's own defaults (ADR-0041 §5). A missing value reads as on.
public struct UserDefaultsSagaFilmDatesRepository: SagaFilmDatesRepository, @unchecked Sendable {
    // UserDefaults is thread-safe; it is just not marked Sendable.
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "sagaFilm.showsDates") {
        self.defaults = defaults
        self.key = key
    }

    public func showsDates() async -> Bool {
        defaults.object(forKey: key) as? Bool ?? true
    }

    public func setShowsDates(_ showsDates: Bool) async {
        defaults.set(showsDates, forKey: key)
    }
}
