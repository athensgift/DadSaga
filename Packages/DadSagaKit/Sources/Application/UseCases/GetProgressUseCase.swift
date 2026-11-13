import Domain

/// The dad's current XP, level and history, derived from the stored events.
public protocol GetProgressUseCase: Sendable {
    func execute() async throws -> DadProgress
}

public struct DefaultGetProgressUseCase: GetProgressUseCase {
    private let contentRepository: any ContentRepository
    private let progressRepository: any ProgressRepository

    public init(contentRepository: any ContentRepository, progressRepository: any ProgressRepository) {
        self.contentRepository = contentRepository
        self.progressRepository = progressRepository
    }

    public func execute() async throws -> DadProgress {
        let catalog = try await contentRepository.fetchCatalog()
        return DadProgress(events: try await progressRepository.fetchEvents(), catalog: catalog)
    }
}
