import Foundation

/// What the engines report, one event at a time (ADR-0065 §2, §4).
extension SyncCoordinator {
    func handle(_ event: SyncEvent, from database: SyncDatabase) async {
        await quietly("an event") { try await self.handleOnChain(event, from: database) }
    }

    private func handleOnChain(_ event: SyncEvent, from database: SyncDatabase) async throws {
        // An engine this iPhone has let go of (sync turned off) has nothing more to say.
        guard engines[database] != nil, let ledger = try await ledgerWhileOn() else { return }
        switch event {
        case .stateUpdate(let state): try await keep(state, of: database, ledger)
        case .accountChange(let change): try await accountChanged(change, ledger)
        case .fetchedZones(_, let deleted): try await zonesWent(deleted, from: database, ledger)
        case .fetchedRecords(let modified, let deleted): try await fetched(modified, deleted, from: database, ledger)
        case .sentZones(let sent): try await zonesSent(sent, from: database, ledger)
        case .sentRecords(let sent): try await self.sent(sent, from: database, ledger)
        case .didFetchChanges: try await fetchEnded(from: database, ledger)
        }
    }

    /// An engine's state is kept as it reports it, until a fetched batch can't be applied: the engine is past that
    /// batch, so from then on this run keeps none, and the next launch starts before the batch and fetches it again.
    private func keep(_ state: Data, of database: SyncDatabase, _ ledger: SyncLedger) async throws {
        if !unapplied.contains(database) { try await ledger.store(engineState: state, for: database) }
    }

    /// A zone that couldn't be saved for lack of room: its records wait for room with it.
    private func zonesSent(_ sent: SentZones, from database: SyncDatabase, _ ledger: SyncLedger) async throws {
        if sent.failed.contains(where: { $0.error == .quotaExceeded }) {
            try await ledger.pause(.iCloudFull, full: database)
        }
    }

    // MARK: - Fetched

    /// Only records of the zones this saga syncs with, each kind in its own zone: anything else in the database is
    /// left alone.
    private func fetched(
        _ modified: [SyncRecord], _ deleted: [SyncChange], from database: SyncDatabase, _ ledger: SyncLedger
    ) async throws {
        let settings = try await ledger.settings()
        guard let zones = settings.zones else { return }
        func isOurs(_ name: RecordName, _ zone: SyncZone) -> Bool {
            zones.zone(for: name.type) == zone && settings.database(for: name.type.scope) == database
        }
        do {
            try await apply(
                fetched: modified.filter { isOurs($0.name, $0.zone) },
                deleted: deleted.filter { isOurs($0.name, $0.zone) }.map(\.name), ledger
            )
        } catch {
            unapplied.insert(database)
            throw error
        }
    }

    /// What came, into the store and `Sync.store`: a fetched batch, and the server's record of a save that met a
    /// newer one. A photo is placed under its id before the entry that lists it is applied, so the timeline finds it;
    /// an offer answered on another iPhone is answered here; the rows go through the applier, which leaves every
    /// field whose local change waits. Then `Sync.store` keeps the system fields of what came and forgets what went,
    /// and the files of deleted entries go.
    func apply(fetched records: [SyncRecord], deleted: [RecordName], _ ledger: SyncLedger) async throws {
        // First what the dad changed: it waits, and an expired token is dealt with before the applier meets it.
        try await drain(ledger)
        for record in records where record.name.type == .photo { await place(record) }
        for occasionID in records.compactMap(\.name.occasionID) { await offers.markAnswered(occasionID) }
        // A child leaves only by its marker (ADR-0065 §4): a deletion of its record changes nothing here.
        let deletions = try await ledger.deletionsToApply(deleted.filter { $0.type != .child })
        let rows = records.filter { $0.name.type.mirrorsARow }.map(\.clearingAbsentFields)
        var applied = Applied()
        if !rows.isEmpty || deletions.contains(where: { $0.type.mirrorsARow }) {
            let context = ApplyContext(
                waiting: try await ledger.waitingFields(for: Set(rows.map(\.name) + deletions)),
                historyToken: try await ledger.settings().historyToken, gone: try await ledger.goneIDs(),
                catalog: try await content.fetchCatalog()
            )
            applied = try await saga.open().applier.apply(FetchedBatch(records: rows, deletions: deletions), context)
        }
        try await ledger.fetched(FetchOutcome(
            records: records, deleted: deletions, gone: applied.goneLearned, resend: applied.resend,
            deleteFromZone: applied.deleteFromZone
        ))
        for photoID in applied.photosToDelete { await photos.delete(id: photoID) }
        // The title kept before this parent's entries went is the dad's own change: it is sent.
        try await drain(ledger)
    }

    /// A fetched photo under its own id, byte for byte (ADR-0065 §1). One this iPhone already has is left as it is.
    /// A file that can't be placed leaves the entry without its picture, as before it came.
    private func place(_ record: SyncRecord) async {
        do {
            guard let asset = record.asset, try await photos.fileURL(id: record.name.id) == nil else { return }
            try await photos.place(fileAt: asset, id: record.name.id)
        } catch {
            Self.logger.error("Sync, a photo: \(String(describing: error), privacy: .public)")
        }
    }

    /// A fetch ended. What was held behind it goes now: the fetch reported no deletion for it, so it is sent as a new
    /// record, with its zone saved again in case the zone was what the save didn't find (ADR-0065 §4). And after an
    /// expired history token, every row the zone lacks is sent, while one it has keeps the server's values.
    private func fetchEnded(from database: SyncDatabase, _ ledger: SyncLedger) async throws {
        let settings = try await ledger.settings()
        let scopes = SyncScope.allCases.filter { settings.database(for: $0) == database }
        if settings.resendAfterFetch {
            var names: [RecordName] = []
            for scope in scopes { names += try await everyRecord(in: scope, ledger) }
            fetchedSinceExpiry.insert(database)
            try await ledger.send(neverSent: names, endingResend: fetchedSinceExpiry.isSuperset(of: settings.databases))
        }
        let released = try await ledger.releaseAfterFetch(scopes)
        // Only where this parent makes zones: one in the partner's iCloud is theirs to make.
        if database == .private, let zones = settings.zones {
            await engines[database]?.add(Set(released.map { zones.zone(for: $0.type) }).map(ZoneChange.save))
        }
        try await give(ledger)
    }

    // MARK: - The account

    /// A sign-out keeps everything, and what waits is given again when the same account returns. Another account:
    /// sync is off for this saga, nothing goes into that iCloud by itself, and nothing is deleted (ADR-0065 §4).
    private func accountChanged(_ change: AccountChange, _ ledger: SyncLedger) async throws {
        switch change {
        case .signOut:
            try await ledger.pause(.signedOut)
        case .signIn(let current):
            guard current == (try await ledger.settings().account) else { return try await turnOff(ledger, .otherAccount) }
            try await ledger.pause(nil)
            try await give(ledger)
        case .switchAccounts:
            try await turnOff(ledger, .otherAccount)
        }
    }
}
