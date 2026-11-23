import Domain
import Foundation

/// Everything the family has done, newest first.
public protocol GetTimelineUseCase: Sendable {
    func execute() async throws -> [TimelineEntry]
}

/// Leaves out the entries of a child removed from the family (ADR-0065 §5): only a copy from the co-op version can
/// bring one until then. Their entries still count for their author. No saga, no entries.
public struct DefaultGetTimelineUseCase: GetTimelineUseCase {
    private let contentRepository: any ContentRepository
    private let wholeSaga: any WholeSagaRepository

    public init(contentRepository: any ContentRepository, wholeSaga: any WholeSagaRepository) {
        self.contentRepository = contentRepository
        self.wholeSaga = wholeSaga
    }

    public func execute() async throws -> [TimelineEntry] {
        async let saga = wholeSaga.readAll()
        let catalog = try await contentRepository.fetchCatalog()
        guard let saga = try await saga else { return [] }
        let removed = Set(saga.removedChildren.map(\.id))
        return Timeline.entries(from: saga.events, catalog: catalog).filter { !removed.contains($0.childID) }
    }
}
