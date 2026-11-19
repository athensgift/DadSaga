import Domain

/// Port for the dad's preferences. They belong to the phone, not to the saga, so starting over keeps them.
public protocol PreferencesRepository: Sendable {
    /// `.default` for anything never saved.
    func fetch() async -> Preferences
    func save(_ preferences: Preferences) async
}
