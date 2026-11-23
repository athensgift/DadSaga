import Foundation

/// The film offers answered (ADR-0065 §1): the one change sync doesn't read from the store's history, since the
/// answers live in the defaults.
extension SyncCoordinator {
    /// An offer was answered: each answer with no record becomes one to send.
    func offersChanged() async {
        await quietly("an offer") {
            guard let ledger = try await self.ledgerWhileOn() else { return }
            try await ledger.send(neverSent: await self.offerRecords())
            try await self.give(ledger)
        }
    }

    /// A join or a follow made this iPhone's children the family's (ADR-0065 §1): an occasion's id begins with its
    /// child's, so the answers are renamed, in the defaults first; then the old records go and the family child's are
    /// written. A kill in between offers a film once more (ADR-0037 §5).
    func renameOffers(by map: ChildMap, _ ledger: SyncLedger) async throws {
        let answered = await offers.answeredOccasionIDs()
        let renamed = Set(answered.map(map.occasionID))
        let old = answered.subtracting(renamed)
        guard !old.isEmpty else { return }
        await offers.deleteAll()
        for occasionID in renamed { await offers.markAnswered(occasionID) }
        try await ledger.record(old.sorted().map { .delete(.offer(occasionID: $0)) })
        try await ledger.send(neverSent: await offerRecords())
        try await give(ledger)
    }
}
