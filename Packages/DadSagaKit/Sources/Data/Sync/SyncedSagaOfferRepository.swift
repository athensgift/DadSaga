import Application
import Foundation

/// The film offers answered follow the parent (ADR-0065 §1): kept on the iPhone as before (ADR-0037 §5), and with
/// iCloud on each answer also becomes a record in the parent's own zone, so a film is offered once on whichever of
/// their iPhones. An answer returns once the iPhone keeps it, and never waits for sync, which may be in the middle of
/// a fetch: its record follows, and one lost to a kill in between is found at the next launch, when the answers
/// are compared with the records (`SyncCoordinator.resume`).
public struct SyncedSagaOfferRepository: SagaOfferRepository {
    private let stored: any SagaOfferRepository
    private let sync: SyncCoordinator

    init(_ stored: any SagaOfferRepository, sync: SyncCoordinator) {
        self.stored = stored
        self.sync = sync
    }

    public func answeredOccasionIDs() async -> Set<String> {
        await stored.answeredOccasionIDs()
    }

    public func markAnswered(_ occasionID: String) async {
        await stored.markAnswered(occasionID)
        Task { await sync.offersChanged() }
    }

    public func forget(childID: UUID) async {
        await stored.forget(childID: childID)
    }

    public func deleteAll() async {
        await stored.deleteAll()
    }
}
