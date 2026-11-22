import Domain
import Foundation

/// Removes something the dad recorded (a quest, a boss or a moment), with its photos and the XP it gave: deleting an
/// entry from the timeline, or a moment he opened to edit. This is the dad correcting his own log, not the game taking
/// something away (ADR-0006, ADR-0021): badges and moments follow from the events, so they go back to what they would
/// be without this one. His title and gear never do: they are kept first (ADR-0055 §3). An Undo right after
/// recording is `UndoRecordUseCase`, which keeps nothing.
public protocol DeleteEventUseCase: Sendable {
    func execute(eventID: UUID) async throws
}

public struct DefaultDeleteEventUseCase: DeleteEventUseCase {
    private let contentRepository: any ContentRepository
    private let progressRepository: any ProgressRepository
    private let standingRepository: any StandingRepository
    private let photoStore: any PhotoStore

    public init(
        contentRepository: any ContentRepository,
        progressRepository: any ProgressRepository,
        standingRepository: any StandingRepository,
        photoStore: any PhotoStore
    ) {
        self.contentRepository = contentRepository
        self.progressRepository = progressRepository
        self.standingRepository = standingRepository
        self.photoStore = photoStore
    }

    public func execute(eventID: UUID) async throws {
        let remover = EntryRemover(progressRepository: progressRepository, photoStore: photoStore)
        let (event, events) = try await remover.find(eventID)
        let catalog = try await contentRepository.fetchCatalog()
        try await StandingKeeper(standingRepository: standingRepository)
            .keepBeforeDeleting(DadProgress(events: events, catalog: catalog), catalog: catalog)
        try await remover.remove(event)
    }
}
