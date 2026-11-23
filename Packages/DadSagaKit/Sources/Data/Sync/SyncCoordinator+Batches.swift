import Foundation

/// What goes out: the batches an engine asks for, and what it reports of them (ADR-0065 §1, §4).
extension SyncCoordinator {
    func nextBatch(for pending: [SyncChange], from database: SyncDatabase) async -> SyncBatch? {
        do {
            return try await onChain { try await self.batch(for: pending, from: database) }
        } catch {
            Self.logger.error("Sync, a batch: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// The engine's list is only names: what is sent is what `Sync.store` holds for each now, with the row's values
    /// of this moment, so a later edit rides along. A change the ledger no longer holds, or holds for another zone or
    /// as the other kind, leaves the engine's list.
    private func batch(for given: [SyncChange], from database: SyncDatabase) async throws -> SyncBatch? {
        guard let ledger = try await ledgerWhileOn() else { return nil }
        let settings = try await ledger.settings()
        guard settings.pause != .signedOut, !settings.isFull(database) else { return nil }
        let waiting = try await ledger.pending().filter { !$0.behindFetch }
        let current = Set(changes(for: waiting, in: database, settings))
        let wanted = Set(given.filter(current.contains).map(\.name))
        // Members, children, entries, then photos; within a type, in the order the changes were made.
        var rest = waiting.enumerated().filter { wanted.contains($0.element.name) }
            .sorted { ($0.element.name.type.batchRank, $0.offset) < ($1.element.name.type.batchRank, $1.offset) }
            .map(\.element)[...]
        var batch = SyncBatch()
        var missing: [RecordName] = []
        while batch.saves.count + batch.deletions.count < Self.batchLimit, !rest.isEmpty {
            let chunk = Array(rest.prefix(Self.batchLimit - batch.saves.count - batch.deletions.count))
            rest = rest.dropFirst(chunk.count)
            let saves = try await records(for: chunk.filter { !$0.isDeletion }, ledger, settings)
            batch.saves += saves
            batch.deletions += changes(for: chunk.filter(\.isDeletion), in: database, settings)
            missing += Set(chunk.filter { !$0.isDeletion }.map(\.name)).subtracting(saves.map(\.name))
        }
        // A row gone since, a photo with no file or no entry: nothing to send any more.
        if !missing.isEmpty { try await ledger.drop(missing) }
        let gone = given.filter { !current.contains($0) || missing.contains($0.name) }
        if !gone.isEmpty { await engines[database]?.remove(gone) }
        return batch.saves.isEmpty && batch.deletions.isEmpty ? nil : batch
    }

    /// The records of `saves` as they are now, each set on the system fields kept for it: the rows from the store,
    /// the others from `Sync.store`, the defaults and the photo files.
    private func records(
        for saves: [PendingChange], _ ledger: SyncLedger, _ settings: SyncSettings
    ) async throws -> [SyncRecord] {
        guard !saves.isEmpty, let zones = settings.zones else { return [] }
        let feed = try await saga.open().feed
        var records = try await feed.records(
            saves.filter { $0.name.type.mirrorsARow }.map { ($0.name, $0.fields) }, zones: zones,
            gone: try await ledger.goneIDs()
        )
        let entries = saves.contains { $0.name.type == .photo } ? try await photoEntries(feed) : [:]
        for name in saves.map(\.name) where !name.type.mirrorsARow {
            var record = SyncRecord(name: name, zone: zones.zone(for: name.type))
            switch name.type {
            case .member:
                guard let account = settings.account else { continue }
                record.fields = [SyncField.Member.userRecordName: .string(account)]
            case .saga:
                guard let id = settings.familyZoneID, let owner = settings.familyOwner else { continue }
                record.fields = [SyncField.Saga.familyZone: .string(id.uuidString), SyncField.Saga.familyOwner: .string(owner)]
            case .photo:
                guard let entryID = entries[name.id], let file = try await photos.fileURL(id: name.id) else { continue }
                record.fields = [SyncField.Photo.entryID: .string(entryID.uuidString)]
                record.asset = file
            default:
                break
            }
            records.append(record)
        }
        let systemFields = try await ledger.systemFields(of: records.map(\.name))
        let built = Dictionary(records.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        // In the order asked: the batch's order is the order the zone fills in.
        return saves.compactMap { save in
            guard var record = built[save.name] else { return nil }
            record.systemFields = systemFields[save.name]
            outgoing[save.name] = Outgoing(revision: save.revision, entryID: entries[save.name.id])
            return record
        }
    }

    /// The entry that lists each photo.
    private func photoEntries(_ feed: StoreChangeFeed) async throws -> [String: UUID] {
        var entries: [String: UUID] = [:]
        for (entryID, photoIDs) in try await feed.entryPhotos() {
            for photoID in photoIDs { entries[photoID] = entryID }
        }
        return entries
    }

    // MARK: - Sent

    /// What an engine reports of a batch (ADR-0065 §4). A record saved or deleted leaves `Sync.store`, unless it
    /// changed while the batch was out. A save that met a newer record is merged and goes again; one whose record or
    /// zone is not there waits for the next fetch to say why; one for which iCloud has no room waits for room. Any
    /// other failure waits in `Sync.store` for the next launch.
    func sent(_ sent: SentRecords, from database: SyncDatabase, _ ledger: SyncLedger) async throws {
        // A record already gone is deleted.
        let deleted = sent.deleted.map(\.name) + sent.failedDeletions.filter { $0.error == .unknownItem }.map(\.change.name)
        try await ledger.sent(
            saved: sent.saved, revisions: outgoing.mapValues(\.revision),
            photoEntries: Dictionary(
                outgoing.compactMap { name, sent in sent.entryID.map { (name.id, $0) } }, uniquingKeysWith: { first, _ in first }
            ),
            deleted: deleted
        )
        let again = Set(sent.saved.map(\.name) + deleted)
        var asNew: [RecordName] = []
        var held = sent.failedDeletions.filter { $0.error == .zoneNotFound }.map(\.change.name)
        var isFull = sent.failedDeletions.contains { $0.error == .quotaExceeded }
        for failure in sent.failed {
            switch failure.error {
            case .serverRecordChanged(let server): try await resolve(server, ledger)
            case .unknownItem: asNew.append(failure.record.name)
            case .zoneNotFound: held.append(failure.record.name)
            case .quotaExceeded: isFull = true
            case .other: break
            }
        }
        try await ledger.hold(asNew, asNew: true)
        try await ledger.hold(held, asNew: false)
        if isFull { try await ledger.pause(.iCloudFull, full: database) }
        for name in sent.saved.map(\.name) + sent.failed.map(\.record.name) + deleted { outgoing[name] = nil }
        // The engine has let go of everything it sent: a record that changed while its batch was out goes again now.
        let settings = try await ledger.settings()
        guard settings.pause == nil else { return }
        let waiting = try await ledger.pending().filter { !$0.behindFetch && again.contains($0.name) }
        await engines[database]?.add(changes(for: waiting, in: database, settings))
    }

    /// A save met a record newer than the one it was set on. The server's record is applied like a fetched one, the
    /// waiting fields left alone, and its system fields kept; the change still waits, so it is given again and goes
    /// set on that record: one merge path, not two (ADR-0065 §4). A save onto a child deleted for good is forgotten
    /// instead, and the marker deletes the child here. A photo or an offer the zone already holds needs nothing more:
    /// neither ever changes.
    private func resolve(_ server: SyncRecord, _ ledger: SyncLedger) async throws {
        if [.photo, .offer].contains(server.name.type) || FieldMerge.resolve(server: server) == .drop {
            try await ledger.drop([server.name])
        }
        try await apply(fetched: [server], deleted: [], ledger)
    }
}
