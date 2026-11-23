import Foundation
import os
import SwiftData

/// `Sync.store`'s one writer (ADR-0065 §5): what waits to be sent, each record's system fields, the history token and
/// the children deleted for good. Its own container, so the macro's own context is the right one. Every method is one
/// turn and one save, and hands back `Sendable` copies.
@ModelActor
actor SyncLedger {
    private static let logger = Logger(subsystem: "DadSaga", category: "sync")

    func settings() throws -> SyncSettings {
        guard let row = try settingsRow() else { return SyncSettings(historyToken: nil, resendAfterFetch: false) }
        var follow: FamilyToFollow?
        if let zoneID = row.followZoneID, let owner = row.followOwner {
            follow = FamilyToFollow(zoneID: zoneID, owner: owner, childMap: row.followChildMap, how: row.followHow)
        }
        return SyncSettings(
            historyToken: Self.token(from: row.historyToken), resendAfterFetch: row.resendAfterFetch, isOn: row.isOn,
            offReason: row.offReason.flatMap(SyncOffReason.init), account: row.accountName,
            pause: row.pause.flatMap(SyncPause.init), fullDatabase: row.fullDatabase.flatMap(SyncDatabase.init),
            familyZoneID: row.familyZoneID, familyOwner: row.familyOwner, fullSendAfterFetch: row.fullSendAfterFetch,
            childMap: row.childMap.flatMap(ChildMap.init(json:)), childMapWaits: row.childMapWaits,
            sagaWaitsForFamily: row.sagaWaitsForFamily, oldFamilyZoneID: row.oldFamilyZoneID, follow: follow
        )
    }

    /// The change feed's read, merged into what waits, and the token it read through, in one save (ADR-0065 §2): a
    /// write and its sync can't come apart, and reading the same changes again after a kill leaves the same rows.
    ///
    /// A save after a save adds its fields (every field stays every field); a deletion replaces a save; a save after a
    /// deletion is a save of every field; a save and then a deletion of a record never sent leave nothing; a child
    /// deleted for good is a save of every field of their record, which goes as the marker, and their id is kept. An
    /// entry's photos are compared with the photos the zone is known to hold for it: a new one is a save of its record,
    /// one the entry no longer lists a deletion.
    func record(_ changes: [LocalChange], through token: DefaultHistoryToken?) throws {
        try modelContext.saveAllOrNothing {
            var turn = Turn(nextSequence: try nextSequence())
            try merge(changes, &turn)
            try settingsRowMakingOne().update(\.historyToken, to: try token.map { try JSONEncoder().encode($0) })
        }
    }

    /// Changes that don't come from the store's history (an offer's record to delete, a change to send again), merged
    /// into what waits like the feed's.
    func record(_ changes: [LocalChange]) throws {
        try modelContext.saveAllOrNothing {
            var turn = Turn(nextSequence: try nextSequence())
            try merge(changes, &turn)
        }
    }

    /// What waits, in the order it was first changed; `scope` nil: both zones'.
    func pending(_ scope: SyncScope? = nil) throws -> [PendingChange] {
        let rows = try modelContext.fetch(FetchDescriptor<PendingChangeRecord>(sortBy: [SortDescriptor(\.sequence)]))
        return rows.compactMap { row in
            guard scope == nil || row.scope == scope?.rawValue, let name = RecordName(row.recordName) else { return nil }
            return PendingChange(
                name: name, isDeletion: row.isDeletion, fields: row.allFields ? nil : Set(row.fields),
                revision: row.revision, behindFetch: row.behindFetch
            )
        }
    }

    /// For each of `names` with a change waiting, the fields a record that arrives must leave alone (ADR-0065 §4):
    /// the ones the dad changed, which is every field of a row he added, or of a record whose deletion waits. A
    /// record that goes whole only because the zone lacked it leaves alone just the fields he changed.
    func waitingFields(for names: Set<RecordName>) throws -> [RecordName: Set<String>] {
        var waiting: [RecordName: Set<String>] = [:]
        for name in names {
            guard let row = try pendingRow(name) else { continue }
            waiting[name] = row.isDeletion ? SyncField.all(of: name.type) : Set(row.fields)
        }
        return waiting
    }

    /// What an engine reports sent. A saved record's system fields are kept, and its change leaves only at the
    /// revision the batch was built from (`revisions`): one merged in while the batch was out is sent again. A deleted
    /// record's system fields go, and its change with them, unless it was saved again meanwhile: that save then goes
    /// as a new record, as does a record deleted to be written again (a member for its new creator). A photo saved
    /// is known for its entry (`photoEntries`, by photo id) from then on, and one deleted no longer.
    func sent(
        saved: [SyncRecord], revisions: [RecordName: Int], photoEntries: [String: UUID] = [:], deleted: [RecordName]
    ) throws {
        try modelContext.saveAllOrNothing {
            for record in saved {
                try keepSystemFields(of: record)
                if let row = try pendingRow(record.name), !row.isDeletion, row.revision == revisions[record.name] {
                    modelContext.delete(row)
                }
                if record.name.type == .photo, let entryID = photoEntries[record.name.id] {
                    try know(photo: record.name.id, of: entryID)
                }
                // The only member this iPhone writes is its own parent's.
                if record.name.type == .member, let profileID = record.name.uuid, let account = try settingsRow()?.accountName {
                    try know(member: profileID, of: account)
                }
            }
            for name in deleted {
                try forget(name)
                guard let row = try pendingRow(name), row.isDeletion else { continue }
                if row.thenSave {
                    // Deleted to be written again, by this parent now.
                    row.isDeletion = false
                    row.allFields = true
                    row.thenSave = false
                    row.revision += 1
                } else {
                    modelContext.delete(row)
                }
            }
        }
    }

    /// The system fields of records that came in a fetch or with a conflict.
    func store(systemFields records: [SyncRecord]) throws {
        try modelContext.saveAllOrNothing {
            for record in records { try keepSystemFields(of: record) }
        }
    }

    func systemFields(of name: RecordName) throws -> Data? {
        try systemFieldsRow(name)?.data
    }

    /// The system fields kept for each of `names`; a record never sent or fetched has none.
    func systemFields(of names: [RecordName]) throws -> [RecordName: Data] {
        var fields: [RecordName: Data] = [:]
        for name in names { fields[name] = try systemFieldsRow(name)?.data }
        return fields
    }

    /// The children deleted for good, here or on another iPhone (ADR-0065 §4).
    func goneIDs() throws -> Set<UUID> {
        Set(try modelContext.fetch(FetchDescriptor<GoneChildRecord>()).map(\.childID))
    }

    /// Markers learned from a fetch.
    func addGone(_ ids: [UUID]) throws {
        try modelContext.saveAllOrNothing {
            for id in Set(ids) { try insertGone(id) }
        }
    }

    // MARK: - One turn's merging

    /// The pending rows a turn has touched: a fetch isn't trusted to show a row inserted or deleted earlier in the same
    /// unsaved turn.
    struct Turn {
        var rows: [RecordName: PendingChangeRecord?] = [:]
        var nextSequence: Int
    }

    /// The feed's changes, and those of a fetch, into what waits.
    func merge(_ changes: [LocalChange], _ turn: inout Turn) throws {
        for change in changes {
            switch change {
            case .save(let name, let fields): try merge(save: name, fields: fields, &turn)
            case .delete(let name): try merge(deletion: name, &turn)
            case .gone(let childID):
                try merge(save: .child(childID), fields: nil, &turn)
                try insertGone(childID)
            case .entryPhotos(let entryID, let photoIDs): try merge(photos: photoIDs, of: entryID, &turn)
            }
        }
    }

    func row(_ name: RecordName, _ turn: inout Turn) throws -> PendingChangeRecord? {
        if let known = turn.rows[name] { return known }
        let row = try pendingRow(name)
        turn.rows[name] = .some(row)
        return row
    }

    /// A save the dad made: `fields` nil, the row was inserted and every field is his.
    func merge(save name: RecordName, fields: Set<String>?, _ turn: inout Turn) throws {
        guard let row = try row(name, &turn) else {
            insert(name, isDeletion: false, fields: fields ?? SyncField.all(of: name.type), whole: fields == nil, &turn)
            return
        }
        // A record that is deleted to be written again is saved whole once it is gone.
        if row.thenSave { return }
        if row.isDeletion || fields == nil {
            row.update(\.isDeletion, to: false)
            row.update(\.allFields, to: true)
            row.update(\.fields, to: SyncField.all(of: name.type).sorted())
        } else if let fields {
            row.update(\.fields, to: Set(row.fields).union(fields).sorted())
        }
        row.revision += 1
    }

    /// The zone isn't known to hold the record, so it goes whole. The fields the dad changed stay as they were: if the
    /// zone turns out to hold the record after all (another iPhone put it there), what comes sets every other field,
    /// and the two merge by field (ADR-0065 §4).
    func merge(whole name: RecordName, _ turn: inout Turn) throws {
        guard let row = try row(name, &turn) else {
            insert(name, isDeletion: false, fields: [], whole: true, &turn)
            return
        }
        if row.thenSave { return }
        if row.isDeletion {
            row.update(\.isDeletion, to: false)
            row.update(\.fields, to: SyncField.all(of: name.type).sorted())
        }
        row.update(\.allFields, to: true)
        row.revision += 1
    }

    func merge(deletion name: RecordName, _ turn: inout Turn) throws {
        guard let row = try row(name, &turn) else {
            insert(name, isDeletion: true, fields: [], whole: false, &turn)
            return
        }
        if !row.isDeletion, try systemFieldsRow(name) == nil {
            // Never sent: the server has nothing to delete.
            modelContext.delete(row)
            turn.rows[name] = .some(nil)
            return
        }
        row.update(\.isDeletion, to: true)
        row.update(\.allFields, to: false)
        row.update(\.fields, to: [])
        row.update(\.thenSave, to: false)
        row.revision += 1
    }

    @discardableResult
    func insert(
        _ name: RecordName, isDeletion: Bool, fields: Set<String>, whole: Bool, _ turn: inout Turn
    ) -> PendingChangeRecord {
        let row = PendingChangeRecord(
            scope: name.type.scope.rawValue, recordName: name.string, isDeletion: isDeletion,
            fields: fields.sorted(), allFields: whole, sequence: turn.nextSequence
        )
        modelContext.insert(row)
        turn.rows[name] = .some(row)
        turn.nextSequence += 1
        return row
    }

    // MARK: - Rows

    func settingsRow() throws -> SyncSettingsRecord? {
        try modelContext.fetch(FetchDescriptor<SyncSettingsRecord>()).first
    }

    /// The settings row, inserted when the store has none yet. Inside a save.
    func settingsRowMakingOne() throws -> SyncSettingsRecord {
        if let row = try settingsRow() { return row }
        let row = SyncSettingsRecord(historyToken: nil, resendAfterFetch: false)
        modelContext.insert(row)
        return row
    }

    func pendingRow(_ name: RecordName) throws -> PendingChangeRecord? {
        let (scope, recordName) = (name.type.scope.rawValue, name.string)
        var descriptor = FetchDescriptor<PendingChangeRecord>(
            predicate: #Predicate { $0.scope == scope && $0.recordName == recordName }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func systemFieldsRow(_ name: RecordName) throws -> SystemFieldsRecord? {
        let (scope, recordName) = (name.type.scope.rawValue, name.string)
        var descriptor = FetchDescriptor<SystemFieldsRecord>(
            predicate: #Predicate { $0.scope == scope && $0.recordName == recordName }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func keepSystemFields(of record: SyncRecord) throws {
        guard let data = record.systemFields else { return }
        if let row = try systemFieldsRow(record.name) {
            row.update(\.data, to: data)
        } else {
            modelContext.insert(SystemFieldsRecord(
                scope: record.name.type.scope.rawValue, recordName: record.name.string, data: data
            ))
        }
    }

    func insertGone(_ childID: UUID) throws {
        let stored = try modelContext.fetch(FetchDescriptor<GoneChildRecord>(predicate: #Predicate { $0.childID == childID }))
        if stored.isEmpty { modelContext.insert(GoneChildRecord(childID: childID)) }
    }

    func nextSequence() throws -> Int {
        var descriptor = FetchDescriptor<PendingChangeRecord>(sortBy: [SortDescriptor(\.sequence, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try modelContext.fetch(descriptor).first?.sequence ?? -1) + 1
    }

    /// A token that no longer decodes reads as none: the history is then read from its start, which sends again at
    /// worst what the last transaction read already sent, and loses nothing.
    private static func token(from data: Data?) -> DefaultHistoryToken? {
        guard let data else { return nil }
        do {
            return try JSONDecoder().decode(DefaultHistoryToken.self, from: data)
        } catch {
            logger.error("The history token could not be read: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
