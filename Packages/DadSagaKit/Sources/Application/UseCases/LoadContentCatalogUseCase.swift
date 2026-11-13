import Domain

/// Loads all game content (worlds, quests, bosses, firsts).
public protocol LoadContentCatalogUseCase: Sendable {
    func execute() async throws -> ContentCatalog
}

public struct DefaultLoadContentCatalogUseCase: LoadContentCatalogUseCase {
    private let repository: any ContentRepository

    public init(repository: any ContentRepository) {
        self.repository = repository
    }

    public func execute() async throws -> ContentCatalog {
        try await repository.fetchCatalog()
    }
}
