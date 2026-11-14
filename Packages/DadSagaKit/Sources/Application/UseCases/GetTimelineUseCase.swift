import Domain

/// Everything the family has done, newest first.
public protocol GetTimelineUseCase: Sendable {
    func execute() async throws -> [TimelineEntry]
}

public struct DefaultGetTimelineUseCase: GetTimelineUseCase {
    private let contentRepository: any ContentRepository
    private let progressRepository: any ProgressRepository

    public init(contentRepository: any ContentRepository, progressRepository: any ProgressRepository) {
        self.contentRepository = contentRepository
        self.progressRepository = progressRepository
    }

    public func execute() async throws -> [TimelineEntry] {
        let catalog = try await contentRepository.fetchCatalog()
        return Timeline.entries(from: try await progressRepository.fetchEvents(), catalog: catalog)
    }
}
