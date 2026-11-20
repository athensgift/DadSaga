import Application
import Foundation

/// Keeps the dad's answers to the film offers in the app's own defaults (ADR-0037 §5). Each answered occasion has a key
/// of its own, so two answers saved at the same moment can't overwrite each other.
public struct UserDefaultsSagaOfferRepository: SagaOfferRepository, @unchecked Sendable {
    // UserDefaults is thread-safe; it is just not marked Sendable.
    private let defaults: UserDefaults
    private let keyPrefix: String

    public init(defaults: UserDefaults = .standard, keyPrefix: String = "sagaOffer.answered.") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    public func answeredOccasionIDs() async -> Set<String> {
        Set(answeredKeys.map { String($0.dropFirst(keyPrefix.count)) })
    }

    public func markAnswered(_ occasionID: String) async {
        defaults.set(true, forKey: keyPrefix + occasionID)
    }

    public func deleteAll() async {
        for key in answeredKeys {
            defaults.removeObject(forKey: key)
        }
    }

    private var answeredKeys: [String] {
        defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(keyPrefix) && defaults.bool(forKey: $0) }
    }
}
