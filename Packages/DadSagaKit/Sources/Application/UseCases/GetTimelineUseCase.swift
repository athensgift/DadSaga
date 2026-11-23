import Domain
import Foundation

/// Everything the family has done, newest first.
public protocol GetTimelineUseCase: Sendable {
    func execute() async throws -> [TimelineEntry]
}

/// Only the family's entries: a child removed from the family (ADR-0065 §4), or with no row, leaves the timeline with
/// their entries, which still count for their author. No saga, no entries.
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
        let family = Set(saga.profile.children.map(\.id))
        return Timeline.entries(from: saga.events, catalog: catalog).filter { family.contains($0.childID) }
    }
}
