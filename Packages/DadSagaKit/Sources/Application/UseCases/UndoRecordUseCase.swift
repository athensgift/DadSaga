import Domain
import Foundation

/// Takes back what the dad just recorded, as if he never had (ADR-0055 §3): the entry goes with its photos, and
/// nothing is kept for it. The store keeps a title only before a deletion (`DeleteEventUseCase`), so a title this
/// entry brought goes with it, and its level and gear too. A title card he closed goes back only as far as the title
/// he still holds.
public protocol UndoRecordUseCase: Sendable {
    /// - Parameter eventID: the entry just recorded (`ProgressChange.eventID`). Throws `ProgressError.unknownEvent`
    ///   when it is no longer there.
    /// - Returns: the title he holds once the entry is gone, so the screen knows which title cards may come again.
    func execute(undoing eventID: UUID) async throws -> DadTitle?
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

    /// The closed card goes back first, when it is above the title he will hold. If deleting the entry then fails, it
    /// is put back as it was, so nothing has changed and the Undo can be tried again.
    public func execute(undoing eventID: UUID) async throws -> DadTitle? {
        let remover = EntryRemover(progressRepository: progressRepository, photoStore: photoStore)
        let (event, events) = try await remover.find(eventID)
        let catalog = try await contentRepository.fetchCatalog()
        let kept = try await standingRepository.fetchKept()
        let after = DadProgress(events: events.filter { $0.id != eventID }, catalog: catalog)
        let left = DadStanding(progress: after, catalog: catalog, kept: kept)
        let seen = left.seenAfterUndo
        if let seen { try await standingRepository.markSeen(titleID: seen.id) }
        do {
            try await remover.remove(event)
            return left.title
        } catch {
            if seen != nil, let closed = kept.seenTitleID { try? await standingRepository.markSeen(titleID: closed) }
            throw error
        }
    }
}
