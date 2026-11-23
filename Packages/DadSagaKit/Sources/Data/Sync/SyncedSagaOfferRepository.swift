import Application

/// The film offers answered follow the parent (ADR-0065 §1): kept on the iPhone as before (ADR-0037 §5), and with
/// iCloud on each answer also becomes a record in the parent's own zone, so a film is offered once on whichever of
/// their iPhones. An answer returns once its record waits in `Sync.store`.
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
        await sync.offersChanged()
    }

    public func deleteAll() async {
        await stored.deleteAll()
    }
}
