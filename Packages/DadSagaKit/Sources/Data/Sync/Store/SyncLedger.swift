import Foundation
import os
import SwiftData

/// What `Sync.store` keeps of the change feed's reading.
struct SyncSettings: Hashable, Sendable {
    /// The saga store's history was read through this token; nil: from its start.
    var historyToken: DefaultHistoryToken?
    var resendAfterFetch: Bool
}

/// One record's change waiting to be sent.
struct PendingChange: Hashable, Sendable {
    let name: RecordName
    let isDeletion: Bool
    /// The fields to set, read from the row when the batch is built; nil: every field. Empty for a deletion.
    let fields: Set<String>?
    /// What a batch remembers, to tell `sent` which state of the change it carried.
    let revision: Int
    /// Not given to an engine until the next fetch ends.
    let behindFetch: Bool
}

/// `Sync.store`'s one writer (ADR-0065 §5): what waits to be sent, each record's system fields, the history token and
/// the children deleted for good. Its own container, so the macro's own context is the right one. Every method is one
/// turn and one save, and hands back `Sendable` copies.
@ModelActor
actor SyncLedger {
    private static let logger = Logger(subsystem: "DadSaga", category: "sync")

    func settings() throws -> SyncSettings {
        guard let row = try settingsRow() else { return SyncSettings(historyToken: nil, resendAfterFetch: false) }
        return SyncSettings(historyToken: Self.token(from: row.historyToken), resendAfterFetch: row.resendAfterFetch)
    }

    /// The change feed's read, merged into what waits, and the token it read through, in one save (ADR-0065 §2): a
    /// write and its sync can't come apart, and reading the same changes again after a kill leaves the same rows.
    ///
    /// A save after a save adds its fields (every field stays every field); a deletion replaces a save; a save after a
    /// deletion is a save of every field; a save and then a deletion of a record never sent leave nothing; a child
    /// deleted for good is a save of every field of their record, which goes as the marker, and their id is kept.
    func record(_ changes: [LocalChange], through token: DefaultHistoryToken?) throws {
        try modelContext.saveAllOrNothing {
            var turn = Turn(nextSequence: try nextSequence())
            for change in changes {
                switch change {
                case .save(let name, let fields): try merge(save: name, fields: fields, &turn)
                case .delete(let name): try merge(deletion: name, &turn)
                case .gone(let childID):
                    try merge(save: .child(childID), fields: nil, &turn)
                    try insertGone(childID)
                case .entryPhotos:
                    // The photos to save or delete come from comparing these with the photos known for the entry
                    // (ADR-0065 §2); the ledger keeps those once the coordinator sends photos.
                    break
                }
            }
            let stored = try token.map { try JSONEncoder().encode($0) }
            if let row = try settingsRow() {
                row.update(\.historyToken, to: stored)
            } else {
                modelContext.insert(SyncSettingsRecord(historyToken: stored, resendAfterFetch: false))
            }
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
    /// the waiting ones, or every field of the record when it goes whole or its deletion waits.
    func waitingFields(for names: Set<RecordName>) throws -> [RecordName: Set<String>] {
        var waiting: [RecordName: Set<String>] = [:]
        for name in names {
            guard let row = try pendingRow(name) else { continue }
            waiting[name] = row.allFields || row.isDeletion ? SyncField.all(of: name.type) : Set(row.fields)
        }
        return waiting
    }

    /// What an engine reports sent. A saved record's system fields are kept, and its change leaves only at the
    /// revision the batch was built from (`revisions`): one merged in while the batch was out is sent again. A deleted
    /// record's system fields go, and its change with them, unless it was saved again meanwhile: that save then goes
    /// as a new record.
    func sent(saved: [SyncRecord], revisions: [RecordName: Int], deleted: [RecordName]) throws {
        try modelContext.saveAllOrNothing {
            for record in saved {
                try keepSystemFields(of: record)
                if let row = try pendingRow(record.name), !row.isDeletion, row.revision == revisions[record.name] {
                    modelContext.delete(row)
                }
            }
            for name in deleted {
                if let fields = try systemFieldsRow(name) { modelContext.delete(fields) }
                if let row = try pendingRow(name), row.isDeletion { modelContext.delete(row) }
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
    private struct Turn {
        var rows: [RecordName: PendingChangeRecord?] = [:]
        var nextSequence: Int
    }

    private func row(_ name: RecordName, _ turn: inout Turn) throws -> PendingChangeRecord? {
        if let known = turn.rows[name] { return known }
        let row = try pendingRow(name)
        turn.rows[name] = .some(row)
        return row
    }

    private func merge(save name: RecordName, fields: Set<String>?, _ turn: inout Turn) throws {
        guard let row = try row(name, &turn) else {
            return insert(name, isDeletion: false, fields: fields, &turn)
        }
        if row.isDeletion || fields == nil {
            row.update(\.isDeletion, to: false)
            row.update(\.allFields, to: true)
            row.update(\.fields, to: [])
        } else if !row.allFields, let fields {
            row.update(\.fields, to: Set(row.fields).union(fields).sorted())
        }
        row.revision += 1
    }

    private func merge(deletion name: RecordName, _ turn: inout Turn) throws {
        guard let row = try row(name, &turn) else {
            return insert(name, isDeletion: true, fields: [], &turn)
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
        row.revision += 1
    }

    private func insert(_ name: RecordName, isDeletion: Bool, fields: Set<String>?, _ turn: inout Turn) {
        let row = PendingChangeRecord(
            scope: name.type.scope.rawValue, recordName: name.string, isDeletion: isDeletion,
            fields: (fields ?? []).sorted(), allFields: fields == nil, sequence: turn.nextSequence
        )
        modelContext.insert(row)
        turn.rows[name] = .some(row)
        turn.nextSequence += 1
    }

    // MARK: - Rows

    private func settingsRow() throws -> SyncSettingsRecord? {
        try modelContext.fetch(FetchDescriptor<SyncSettingsRecord>()).first
    }

    private func pendingRow(_ name: RecordName) throws -> PendingChangeRecord? {
        let (scope, recordName) = (name.type.scope.rawValue, name.string)
        var descriptor = FetchDescriptor<PendingChangeRecord>(
            predicate: #Predicate { $0.scope == scope && $0.recordName == recordName }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func systemFieldsRow(_ name: RecordName) throws -> SystemFieldsRecord? {
        let (scope, recordName) = (name.type.scope.rawValue, name.string)
        var descriptor = FetchDescriptor<SystemFieldsRecord>(
            predicate: #Predicate { $0.scope == scope && $0.recordName == recordName }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func keepSystemFields(of record: SyncRecord) throws {
        guard let data = record.systemFields else { return }
        if let row = try systemFieldsRow(record.name) {
            row.update(\.data, to: data)
        } else {
            modelContext.insert(SystemFieldsRecord(
                scope: record.name.type.scope.rawValue, recordName: record.name.string, data: data
            ))
        }
    }

    private func insertGone(_ childID: UUID) throws {
        let stored = try modelContext.fetch(FetchDescriptor<GoneChildRecord>(predicate: #Predicate { $0.childID == childID }))
        if stored.isEmpty { modelContext.insert(GoneChildRecord(childID: childID)) }
    }

    private func nextSequence() throws -> Int {
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
