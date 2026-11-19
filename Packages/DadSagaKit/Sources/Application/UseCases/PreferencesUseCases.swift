import Domain

/// The dad's light/dark choice and haptics (ADR-0030).
public protocol GetPreferencesUseCase: Sendable {
    func execute() async -> Preferences
}

public protocol SavePreferencesUseCase: Sendable {
    func execute(_ preferences: Preferences) async
}

public struct DefaultGetPreferencesUseCase: GetPreferencesUseCase {
    private let repository: any PreferencesRepository

    public init(repository: any PreferencesRepository) {
        self.repository = repository
    }

    public func execute() async -> Preferences {
        await repository.fetch()
    }
}

public struct DefaultSavePreferencesUseCase: SavePreferencesUseCase {
    private let repository: any PreferencesRepository

    public init(repository: any PreferencesRepository) {
        self.repository = repository
    }

    public func execute(_ preferences: Preferences) async {
        await repository.save(preferences)
    }
}
