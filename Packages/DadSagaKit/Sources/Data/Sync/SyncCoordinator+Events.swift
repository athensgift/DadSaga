import Foundation

/// What the engines report, one event at a time (ADR-0065 §2, §4).
extension SyncCoordinator {
    func handle(_ event: SyncEvent, from engine: SyncEngineID) async {
        await quietly("an event") { try await self.handleOnChain(event, from: engine) }
    }

    private func handleOnChain(_ event: SyncEvent, from engine: SyncEngineID) async throws {
        // An engine this iPhone has let go of (sync turned off, or another took its place) has nothing more to say,
        // whatever it reported before this turn on the chain came.
        let database = engine.database
        guard engineIDs[database] == engine, let ledger = try await ledgerWhileOn() else { return }
        switch event {
        case .stateUpdate(let state): try await keep(state, of: database, ledger)
        case .accountChange(let change): try await accountChanged(change, ledger)
        case .fetchedZones(let modified, let deleted):
            try await applying(from: database) { try await self.zonesWent(deleted, from: database, ledger) }
            if database == .shared, let family = try await ledger.settings().familyZone, modified.contains(family) {
                familyZoneListed = true
            }
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

    /// What a fetch brought is applied, or the engine's state is no longer kept this run: the next launch fetches it
    /// again.
    private func applying(from database: SyncDatabase, _ apply: () async throws -> Void) async throws {
        do {
            try await apply()
        } catch {
            unapplied.insert(database)
            throw error
        }
    }

    /// A zone that couldn't be saved for lack of room: its records wait for room with it. And the parent's own zone
    /// that a join left is gone.
    private func zonesSent(_ sent: SentZones, from database: SyncDatabase, _ ledger: SyncLedger) async throws {
        if sent.failed.contains(where: { $0.error == .quotaExceeded }) {
            try await ledger.pause(.iCloudFull, full: database)
        }
        for case .family(let id, _) in sent.deleted { try await ledger.oldZoneDeleted(id) }
    }

    // MARK: - Fetched

    /// Only records of the zones this saga syncs with, each kind in its own zone: anything else in the database is
    /// left alone. So is the family's zone while `saga` names another to follow: only the family's sync is off then,
    /// and the parent's own zone goes on, or this iPhone would never see `saga` change (ADR-0065 §4).
    private func fetched(
        _ modified: [SyncRecord], _ deleted: [SyncChange], from database: SyncDatabase, _ ledger: SyncLedger
    ) async throws {
        let settings = try await ledger.settings()
        guard let zones = settings.zones else { return }
        func isOurs(_ name: RecordName, _ zone: SyncZone) -> Bool {
            let scope = name.type.scope
            return zones.zone(for: name.type) == zone && settings.database(for: scope) == database
                && (scope == .personal || settings.follow == nil)
        }
        try await applying(from: database) {
            try await self.apply(
                fetched: modified.filter { isOurs($0.name, $0.zone) },
                deleted: deleted.filter { isOurs($0.name, $0.zone) }.map(\.name), ledger
            )
        }
    }

    /// What came, into the store and `Sync.store`: a fetched batch, and the server's record of a save that met a
    /// newer one. A photo is placed under its id before the entry that lists it is applied, so the timeline finds it;
    /// an offer answered on another iPhone is answered here; the rows go through the applier, which leaves every
    /// field whose local change waits, and applies a join's child map with the batch that brings the last of the
    /// family's children it names. Then `Sync.store` keeps the system fields of what came, the members and the family
    /// `saga` names, and forgets what went; and the files of deleted entries go.
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
            let settings = try await ledger.settings()
            let context = ApplyContext(
                waiting: try await ledger.waitingFields(for: Set(rows.map(\.name) + deletions)),
                historyToken: settings.historyToken, gone: try await ledger.goneIDs(),
                catalog: try await content.fetchCatalog(), map: settings.childMapWaits ? settings.childMap : nil
            )
            applied = try await saga.open().applier.apply(FetchedBatch(records: rows, deletions: deletions), context)
        }
        try await ledger.fetched(FetchOutcome(
            records: records, deleted: deletions, gone: applied.goneLearned, resend: applied.resend,
            deleteFromZone: applied.deleteFromZone, mapped: applied.mapped
        ))
        for photoID in applied.photosToDelete { await photos.delete(id: photoID) }
        if let mapped = applied.mapped { try await renameOffers(by: mapped, ledger) }
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
            Self.logger.error("Sync, a photo: \(error.syncLogLabel, privacy: .public)")
        }
    }

    /// A fetch ended. What was held behind it goes now: the fetch reported no deletion for it, so it is sent as a new
    /// record, with its zone saved again in case the zone was what the save didn't find (ADR-0065 §4). After an
    /// expired history token, every row the zone lacks is sent, while one it has keeps the server's values. And when
    /// it was the whole fetch of the family's zone, what the zone lacks is sent or deleted by the rejoin's rule: only
    /// when every batch of it was applied, since a record of a batch that wasn't reads as one the zone lacks, and
    /// another member's entry would go as their deletion. Until the next launch has fetched that batch again, the
    /// family's changes wait.
    private func fetchEnded(from database: SyncDatabase, _ ledger: SyncLedger) async throws {
        let settings = try await ledger.settings()
        let scopes = SyncScope.allCases.filter { settings.database(for: $0) == database }
        if settings.resendAfterFetch {
            var names: [RecordName] = []
            for scope in scopes { names += try await everyRecord(in: scope, ledger) }
            fetchedSinceExpiry.insert(database)
            try await ledger.send(neverSent: names, endingResend: fetchedSinceExpiry.isSuperset(of: settings.databases))
        }
        if settings.fullSendAfterFetch, settings.follow == nil, scopes.contains(.family), !unapplied.contains(database) {
            try await fullSend(ledger)
        }
        if database == .shared {
            // A save found no zone, and this fetch listed none: the partner's sharing has ended. When it did list
            // the zone, the zone is there (it wasn't yet, for that save): what waited is sent again.
            let ended = familyZoneNotFound && !familyZoneListed
            (familyZoneNotFound, familyZoneListed) = (false, false)
            if ended { try await familyLeft(ledger) }
        }
        let released = try await ledger.releaseAfterFetch(scopes)
        // Only where this parent makes zones: one in the partner's iCloud is theirs to make.
        if database == .private, let zones = settings.zones {
            await engines[database]?.add(Set(released.map { zones.zone(for: $0.type) }).map(ZoneChange.save))
        }
        try await give(ledger)
        try await endMove(ledger)
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
            try await accountReturned(ledger)
            try await give(ledger)
        case .switchAccounts:
            try await turnOff(ledger, .otherAccount)
        }
    }

    /// The same account is back. The engine of the family's database is made again from nothing, whatever the one
    /// that reported the sign-in kept: the rejoin's rule that follows its first fetch counts on that fetch bringing
    /// the zone whole. Both engines report the sign-in; the second finds its engine replaced and is dropped.
    func accountReturned(_ ledger: SyncLedger) async throws {
        try await ledger.accountReturned()
        let settings = try await ledger.settings()
        forgetEngine(settings.database(for: .family))
        try await makeEngines(ledger, settings)
    }
}
