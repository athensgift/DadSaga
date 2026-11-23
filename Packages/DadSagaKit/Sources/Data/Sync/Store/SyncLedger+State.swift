import Foundation
import SwiftData

/// What a fetch, or the server's record of a save that met a newer one, leaves in `Sync.store`.
struct FetchOutcome: Sendable {
    /// The records that came: their system fields are kept, and a photo's record is known for its entry.
    var records: [SyncRecord] = []
    /// Records the zone no longer holds: nothing is kept or waits for them any more (a deletion wins, ADR-0065 §4).
    var deleted: [RecordName] = []
    /// Children whose `gone` marker came.
    var gone: [UUID] = []
    /// Changes that came and were not applied, to send again.
    var resend: [LocalChange] = []
    /// Records to delete from the zone.
    var deleteFromZone: [RecordName] = []
}

/// Where sync stands, what its engines last said, and what a fetch leaves (ADR-0065 §2, §4). As in the rest of the
/// ledger, every method is one turn and one save.
extension SyncLedger {
    // MARK: On, off, waiting

    /// iCloud is turned on for `account` (ADR-0065 §2): every record of `names` goes whole, as to zones that hold
    /// nothing of this iPhone's, and the store's history is read from `token` on. Nothing kept from an earlier time
    /// meets the zones: system fields, the engines' states and what waited all go. `afterFetch`: iCloud holds this
    /// family already, so nothing is sent until the first fetch has brought it (`send(neverSent:)`).
    func turnOn(
        account: String, family: (id: UUID, owner: String), token: DefaultHistoryToken?, sending names: [RecordName],
        afterFetch: Bool
    ) throws {
        try modelContext.saveAllOrNothing {
            let row = try settingsRowMakingOne()
            row.update(\.isOn, to: true)
            row.update(\.offReason, to: nil)
            row.update(\.accountName, to: account)
            row.update(\.pause, to: nil)
            row.update(\.fullDatabase, to: nil)
            row.update(\.familyZoneID, to: family.id)
            row.update(\.familyOwner, to: family.owner)
            row.update(\.historyToken, to: try token.map { try JSONEncoder().encode($0) })
            row.update(\.resendAfterFetch, to: afterFetch)
            try forgetEngines()
            try restart(SyncScope.allCases, sending: names)
        }
    }

    /// Sync turns itself off (ADR-0065 §4). The saga is untouched; the children deleted for good, the account and the
    /// family's zone are kept for when the parent turns iCloud on again.
    func turnOff(_ reason: SyncOffReason) throws {
        try modelContext.saveAllOrNothing {
            let row = try settingsRowMakingOne()
            row.update(\.isOn, to: false)
            row.update(\.offReason, to: reason.rawValue)
            row.update(\.pause, to: nil)
            row.update(\.fullDatabase, to: nil)
            row.update(\.resendAfterFetch, to: false)
            try forgetEngines()
            try restart(SyncScope.allCases, sending: [])
        }
    }

    /// `pause` nil: nothing is waited for any more. `database`: whose iCloud is full.
    func pause(_ pause: SyncPause?, full database: SyncDatabase? = nil) throws {
        try modelContext.saveAllOrNothing {
            let row = try settingsRowMakingOne()
            row.update(\.pause, to: pause?.rawValue)
            row.update(\.fullDatabase, to: pause == .iCloudFull ? database?.rawValue : nil)
        }
    }

    /// The history after the token is gone (ADR-0065 §2, "History's two edges"): reading starts again from `token`, and
    /// once the next fetch ends every row the zone lacks is sent (`send(neverSent:)`).
    func historyExpired(readingFrom token: DefaultHistoryToken?) throws {
        try modelContext.saveAllOrNothing {
            let row = try settingsRowMakingOne()
            row.update(\.historyToken, to: try token.map { try JSONEncoder().encode($0) })
            row.update(\.resendAfterFetch, to: true)
        }
    }

    /// A zone was made again under its name (`encryptedDataReset`): every record of `names` goes whole, and nothing
    /// kept from the old zone meets the new one.
    func reset(_ scope: SyncScope, sending names: [RecordName]) throws {
        try modelContext.saveAllOrNothing { try restart([scope], sending: names) }
    }

    // MARK: Engines

    func engineState(_ database: SyncDatabase) throws -> Data? {
        try engineRow(database)?.state
    }

    func store(engineState state: Data, for database: SyncDatabase) throws {
        try modelContext.saveAllOrNothing {
            if let row = try engineRow(database) {
                row.update(\.state, to: state)
            } else {
                modelContext.insert(EngineStateRecord(database: database.rawValue, state: state))
            }
        }
    }

    // MARK: What waits

    /// Holds the changes of `names` until the next fetch ends: it says whether the record or its zone went
    /// (ADR-0065 §4). `asNew`: the zone had no record for the system fields a save carried, so they are dropped and the
    /// save goes whole, as a new record, unless that fetch reports the deletion.
    func hold(_ names: [RecordName], asNew: Bool) throws {
        try modelContext.saveAllOrNothing {
            for name in names {
                if asNew, let fields = try systemFieldsRow(name) { modelContext.delete(fields) }
                guard let row = try pendingRow(name) else { continue }
                row.update(\.behindFetch, to: true)
                if asNew, !row.isDeletion {
                    row.update(\.allFields, to: true)
                    row.update(\.fields, to: [])
                }
            }
        }
    }

    /// A fetch of the zones of `scopes` ended: the changes held behind it are free to go. Returns them.
    func releaseAfterFetch(_ scopes: [SyncScope]) throws -> [RecordName] {
        try modelContext.saveAllOrNothing {
            let scopes = scopes.map(\.rawValue)
            let held = try modelContext.fetch(FetchDescriptor<PendingChangeRecord>(predicate: #Predicate { $0.behindFetch }))
                .filter { scopes.contains($0.scope) }
            for row in held { row.update(\.behindFetch, to: false) }
            return held.compactMap { RecordName($0.recordName) }
        }
    }

    /// Forgets what waits for `names`: the row is gone, or the server's record is final.
    func drop(_ names: [RecordName]) throws {
        try modelContext.saveAllOrNothing {
            for name in names {
                if let row = try pendingRow(name) { modelContext.delete(row) }
            }
        }
    }

    /// Each of `names` the zone isn't known to hold becomes a save of the whole record, unless one waits already: an
    /// offer answered with no record, a photo an entry lists (ADR-0065 §1), and, after the fetch that follows an
    /// expired history token, every row the zone lacks, while a row it has keeps the server's values (ADR-0065 §2).
    /// `endingResend`: that fetch has ended for every database.
    func send(neverSent names: [RecordName], endingResend: Bool = false) throws {
        try modelContext.saveAllOrNothing {
            var turn = Turn(nextSequence: try nextSequence())
            for name in names where try systemFieldsRow(name) == nil {
                if let row = try row(name, &turn), row.allFields, !row.isDeletion { continue }
                try merge(save: name, fields: nil, &turn)
            }
            if endingResend { try settingsRowMakingOne().update(\.resendAfterFetch, to: false) }
        }
    }

    // MARK: A fetch

    /// Of the records a fetch reports deleted, those the deletion is about: one whose system fields are kept, or whose
    /// save is held behind this fetch (ADR-0065 §4). A record with neither is not in the zone as far as this iPhone
    /// knows: the deletion is an earlier one coming back (this iPhone's own, of a slot since set again), and the row
    /// there is now stays, to be sent as a new record.
    func deletionsToApply(_ names: [RecordName]) throws -> [RecordName] {
        try names.filter { try systemFieldsRow($0) != nil || (try pendingRow($0)?.behindFetch ?? false) }
    }

    func fetched(_ outcome: FetchOutcome) throws {
        try modelContext.saveAllOrNothing {
            var turn = Turn(nextSequence: try nextSequence())
            for record in outcome.records {
                try keepSystemFields(of: record)
                if record.name.type == .photo, let entryID = record.photoEntryID {
                    try know(photo: record.name.id, of: entryID)
                }
            }
            for name in outcome.deleted {
                try forget(name)
                if let row = try row(name, &turn) {
                    modelContext.delete(row)
                    turn.rows[name] = .some(nil)
                }
            }
            for childID in Set(outcome.gone) { try insertGone(childID) }
            try merge(outcome.resend + outcome.deleteFromZone.map(LocalChange.delete), &turn)
        }
    }

    // MARK: Photos

    /// The photos the zone is known to hold, each with its entry.
    func knownPhotos() throws -> [String: UUID] {
        Dictionary(
            try modelContext.fetch(FetchDescriptor<KnownPhotoRecord>()).map { ($0.photoID, $0.entryID) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// An entry's photos now, against the photos the zone is known to hold for it (ADR-0065 §2): one it doesn't hold is
    /// a save, unless it waits already; one the entry no longer lists is a deletion. `photoIDs` nil: the entry went,
    /// and every photo known for it goes. A photo that only waited is found without an entry when its batch is built,
    /// and dropped there.
    func merge(photos photoIDs: [String]?, of entryID: UUID, _ turn: inout Turn) throws {
        let known = try modelContext.fetch(FetchDescriptor<KnownPhotoRecord>(predicate: #Predicate { $0.entryID == entryID }))
        let listed = Set(photoIDs ?? [])
        for photo in known where !listed.contains(photo.photoID) {
            try merge(deletion: .photo(photo.photoID), &turn)
        }
        for name in (photoIDs ?? []).map(RecordName.photo) where try systemFieldsRow(name) == nil {
            if try row(name, &turn) == nil { try merge(save: name, fields: nil, &turn) }
        }
    }

    func know(photo photoID: String, of entryID: UUID) throws {
        if let row = try knownPhotoRow(photoID) {
            row.update(\.entryID, to: entryID)
        } else {
            modelContext.insert(KnownPhotoRecord(photoID: photoID, entryID: entryID))
        }
    }

    /// The zone no longer holds `name`: its system fields go, and a photo is no longer known.
    func forget(_ name: RecordName) throws {
        if let fields = try systemFieldsRow(name) { modelContext.delete(fields) }
        if name.type == .photo, let photo = try knownPhotoRow(name.id) { modelContext.delete(photo) }
    }

    // MARK: Rows

    /// Every record of `names` goes whole into the zones of `scopes`, and nothing else waits for them: what waited was
    /// for zones that are gone. Their system fields go, and the photos known. A row that stays is changed in place,
    /// never deleted and inserted again under the same name in one save.
    private func restart(_ scopes: [SyncScope], sending names: [RecordName]) throws {
        let scopes = scopes.map(\.rawValue)
        let wanted = Set(names)
        var turn = Turn(nextSequence: try nextSequence())
        for row in try modelContext.fetch(FetchDescriptor<PendingChangeRecord>()) where scopes.contains(row.scope) {
            guard let name = RecordName(row.recordName), wanted.contains(name) else {
                modelContext.delete(row)
                continue
            }
            row.update(\.behindFetch, to: false)
            turn.rows[name] = .some(row)
        }
        for name in names where scopes.contains(name.type.scope.rawValue) {
            if turn.rows[name] == nil { turn.rows[name] = .some(nil) }
            try merge(save: name, fields: nil, &turn)
        }
        for row in try modelContext.fetch(FetchDescriptor<SystemFieldsRecord>()) where scopes.contains(row.scope) {
            modelContext.delete(row)
        }
        if scopes.contains(SyncScope.family.rawValue) {
            for row in try modelContext.fetch(FetchDescriptor<KnownPhotoRecord>()) { modelContext.delete(row) }
        }
    }

    private func forgetEngines() throws {
        for row in try modelContext.fetch(FetchDescriptor<EngineStateRecord>()) { modelContext.delete(row) }
    }

    private func engineRow(_ database: SyncDatabase) throws -> EngineStateRecord? {
        let database = database.rawValue
        return try modelContext.fetch(FetchDescriptor<EngineStateRecord>(predicate: #Predicate { $0.database == database })).first
    }

    private func knownPhotoRow(_ photoID: String) throws -> KnownPhotoRecord? {
        try modelContext.fetch(FetchDescriptor<KnownPhotoRecord>(predicate: #Predicate { $0.photoID == photoID })).first
    }
}
