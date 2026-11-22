import Domain
import Foundation

/// Takes back what the dad just recorded, as if he never had: the entry with its photos, and what the store kept for
/// his title, gear and title card goes back to how it was just before (ADR-0055 §3). So a quest that brought a title
/// takes the title, its card and its gear with it. Deleting an entry later, from the timeline, keeps them instead
/// (`DeleteEventUseCase`).
public protocol UndoRecordUseCase: Sendable {
    /// - Parameters:
    ///   - eventID: the entry just recorded (`ProgressChange.eventID`).
    ///   - kept: what the store kept before it (`ProgressChange.keptBefore`).
    func execute(eventID: UUID, restoring kept: KeptStanding) async throws
}

public struct DefaultUndoRecordUseCase: UndoRecordUseCase {
    private let progressRepository: any ProgressRepository
    private let standingRepository: any StandingRepository
    private let photoStore: any PhotoStore

    public init(
        progressRepository: any ProgressRepository,
        standingRepository: any StandingRepository,
        photoStore: any PhotoStore
    ) {
        self.progressRepository = progressRepository
        self.standingRepository = standingRepository
        self.photoStore = photoStore
    }

    /// The kept record goes back first: if deleting the entry then fails, the entry still reaches what it reached, and
    /// the Undo can be tried again.
    public func execute(eventID: UUID, restoring kept: KeptStanding) async throws {
        let events = try await progressRepository.fetchEvents()
        guard let event = events.first(where: { $0.id == eventID }) else { throw ProgressError.unknownEvent }
        try await standingRepository.restore(kept)
        try await progressRepository.delete(id: eventID)
        for photoID in event.photoIDs {
            await photoStore.delete(id: photoID)
        }
    }
}
