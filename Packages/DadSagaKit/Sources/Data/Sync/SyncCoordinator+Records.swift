import Foundation

/// What a zone is built from (ADR-0065 §1, §4): every record this iPhone writes into one, and the children deleted
/// for good, whose markers go with them.
extension SyncCoordinator {
    /// The children deleted for good while the history wasn't read into `Sync.store` (iCloud off): their ids are kept
    /// before the history is trimmed, so a zone this iPhone builds later still carries their markers (ADR-0065 §4).
    func rememberGone(_ ledger: SyncLedger, _ feed: StoreChangeFeed) async throws {
        guard case .changes(let changes, _) = try await feed.read(after: nil) else { return }
        let gone = changes.compactMap { change in
            if case .gone(let childID) = change { childID } else { nil }
        }
        if !gone.isEmpty { try await ledger.addGone(gone) }
    }

    /// A confirmed replace wins (ADR-0065 §4): a child `Sync.store` knows as deleted for good who has a row was
    /// brought back by a copy the parent chose (an import, "which to keep"), since nothing else writes a row under
    /// that id again. `Sync.store` forgets them, so they are sent as a child, not as their marker, and their record
    /// is applied when it comes. Before a zone is built, and before the family's is fetched whole and filled. Only
    /// what this iPhone remembered is dropped: a marker the zone itself still holds deletes them here when it is
    /// fetched (ADR-0065 §2).
    func keepChildrenACopyBroughtBack(_ ledger: SyncLedger) async throws {
        let rows = try await saga.open().feed.everyRecordName().filter { $0.type == .child }.compactMap(\.uuid)
        let back = try await ledger.goneIDs().intersection(rows)
        if !back.isEmpty { try await ledger.forgetGone(back) }
    }

    /// Every record this iPhone writes into a zone of `scope` that holds nothing of its own (ADR-0065 §1, §4): the
    /// rows, and what isn't a row. The family's carries this parent's member only, and a marker for each child deleted
    /// for good.
    func everyRecord(in scope: SyncScope, _ ledger: SyncLedger) async throws -> [RecordName] {
        let feed = try await saga.open().feed
        let rows = try await feed.everyRecordName()
        switch scope {
        case .personal:
            return rows.filter { $0.type.scope == .personal } + (await offerRecords()) + [.saga]
        case .family:
            let members = rows.filter { $0.type == .hero }.compactMap(\.uuid).map(RecordName.member)
            let gone = try await ledger.goneIDs().map(RecordName.child)
            return members + rows.filter { $0.type.scope == .family } + gone + (try await photoRecords(feed))
        }
    }

    /// The record of each offer answered.
    func offerRecords() async -> [RecordName] {
        await offers.answeredOccasionIDs().sorted().map(RecordName.offer(occasionID:))
    }

    /// The record of each photo an entry lists.
    func photoRecords(_ feed: StoreChangeFeed) async throws -> [RecordName] {
        try await feed.entryPhotos().values.flatMap(\.self).sorted().map(RecordName.photo)
    }
}
