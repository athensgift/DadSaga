import Domain
import Foundation

/// Takes back what the dad just recorded, as if he never had: the entry with its photos, and what the store kept for
/// his title and gear goes back to how it was just before (ADR-0055 §3). So a quest that brought a title takes the
/// title, its level and its gear with it. A closed title card goes back only as far as the title he still holds.
/// Deleting an entry later, from the timeline, keeps the title instead (`DeleteEventUseCase`).
public protocol UndoRecordUseCase: Sendable {
    /// - Parameters:
    ///   - eventID: the entry just recorded (`ProgressChange.eventID`).
    ///   - kept: what the store kept before it (`ProgressChange.keptBefore`).
    func execute(eventID: UUID, restoring kept: KeptStanding) async throws
}

public struct DefaultUndoRecordUseCase: UndoRecordUseCase {
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

    /// The kept record goes back first. If deleting the entry then fails, it is put back as it was, so nothing has
    /// changed and the Undo can be tried again.
    public func execute(eventID: UUID, restoring kept: KeptStanding) async throws {
        let remover = EntryRemover(progressRepository: progressRepository, photoStore: photoStore)
        let (event, events) = try await remover.find(eventID)
        let catalog = try await contentRepository.fetchCatalog()
        let now = try await standingRepository.fetchKept()
        let after = DadProgress(events: events.filter { $0.id != eventID }, catalog: catalog)
        try await standingRepository.restore(now.undone(to: kept, after: after, catalog: catalog))
        do {
            try await remover.remove(event)
        } catch {
            try? await standingRepository.restore(now)
            throw error
        }
    }
}
