import Foundation
import SwiftData

/// The saga store's history as the dad's changes (ADR-0065 §2), read on the store's one context (ADR-0068). The change
/// feed reads it to send them; the applier reads it in its own turn, so a write not yet read still waits when a record
/// arrives.
extension ModelContext {
    /// The dad's changes after `token`; every one the history holds when it is nil. Transactions saved under the
    /// `sync` author are skipped.
    func localChanges(after token: DefaultHistoryToken?) throws -> FeedRead {
        var descriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        if let token {
            guard try isThisStores(token) else { return .tokenExpired }
            descriptor.predicate = #Predicate { $0.token > token }
        }
        let transactions: [DefaultHistoryTransaction]
        do {
            transactions = try fetchHistory(descriptor).sorted { $0.token < $1.token }
        } catch SwiftDataError.historyTokenExpired {
            return .tokenExpired
        }
        let own = transactions.filter { $0.author != StoreAuthor.sync.rawValue }
        // First, so an insert or update of a row deleted later in the same read still names it.
        var deleted: [PersistentIdentifier: RecordName] = [:]
        for change in own.flatMap(\.changes) {
            if let name = Self.deletedRecordName(change) { deleted[change.changedPersistentIdentifier] = name }
        }
        let changes = try own.flatMap(\.changes).flatMap { change in
            try localChanges(for: change, ProfileRecord.self, deleted)
                ?? localChanges(for: change, ChildRecord.self, deleted)
                ?? localChanges(for: change, ProgressEventRecord.self, deleted)
                ?? localChanges(for: change, OutfitRecord.self, deleted)
                ?? []
        }
        return .changes(changes, through: transactions.last?.token ?? token)
    }

    func latestTransaction() throws -> DefaultHistoryTransaction? {
        var descriptor = HistoryDescriptor<DefaultHistoryTransaction>(sortBy: [SortDescriptor(\.token, order: .reverse)])
        descriptor.fetchLimit = 1
        return try fetchHistory(descriptor).first
    }

    /// The one row the predicate names, fetched: `model(for:)` hands back a fault for a row that is gone.
    func row<Row: PersistentModel>(_: Row.Type, _ predicate: Predicate<Row>) throws -> Row? {
        var descriptor = FetchDescriptor<Row>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try fetch(descriptor).first
    }

    /// What `change` sends when it is a change of a `Row`; nil when it is another model's.
    private func localChanges<Row: SyncedRow>(
        for change: HistoryChange, _: Row.Type, _ deleted: [PersistentIdentifier: RecordName]
    ) throws -> [LocalChange]? {
        switch change {
        case .insert(let insert as DefaultHistoryInsert<Row>):
            return try saved(Row.self, insert.changedPersistentIdentifier, fields: nil, deleted)
        case .update(let update as DefaultHistoryUpdate<Row>):
            let fields = Set(update.updatedAttributes.compactMap { Row.syncField(for: $0) })
            // An update of only the columns that name the row sends nothing.
            guard !fields.isEmpty else { return [] }
            return try saved(Row.self, update.changedPersistentIdentifier, fields: fields, deleted)
        case .delete(let delete as DefaultHistoryDelete<Row>):
            return deleted[delete.changedPersistentIdentifier].map(Self.whenDeleted) ?? []
        default:
            return nil
        }
    }

    /// A save of the row's record, named by the row or, when it was deleted later in this read, by its tombstone. A
    /// row that went under the `sync` author (a restore, a fetched deletion) names nothing and sends nothing.
    private func saved<Row: SyncedRow>(
        _: Row.Type, _ id: PersistentIdentifier, fields: Set<String>?, _ deleted: [PersistentIdentifier: RecordName]
    ) throws -> [LocalChange] {
        let stored = try row(Row.self, #Predicate { $0.persistentModelID == id })
        guard let name = stored?.recordName ?? deleted[id] else { return [] }
        var changes = [LocalChange.save(name, fields: fields)]
        if let entry = stored as? ProgressEventRecord, fields?.contains(SyncField.Entry.photoIDs) ?? true {
            changes.append(.entryPhotos(entryID: entry.eventID, photoIDs: entry.photoIDs))
        }
        return changes
    }

    /// A deleted row's record, from the id its tombstone kept.
    private static func deletedRecordName(_ change: HistoryChange) -> RecordName? {
        guard case .delete(let delete) = change else { return nil }
        return switch delete {
        case let delete as DefaultHistoryDelete<ProfileRecord>: ProfileRecord.recordName(from: delete.tombstone)
        case let delete as DefaultHistoryDelete<ChildRecord>: ChildRecord.recordName(from: delete.tombstone)
        case let delete as DefaultHistoryDelete<ProgressEventRecord>: ProgressEventRecord.recordName(from: delete.tombstone)
        case let delete as DefaultHistoryDelete<OutfitRecord>: OutfitRecord.recordName(from: delete.tombstone)
        default: nil
        }
    }

    /// A child's row goes by the dad's edit only when deleted for good, sent as the marker; an entry takes its photos;
    /// a hero is never deleted by sync (only start over deletes the profile, under `sync`).
    private static func whenDeleted(_ name: RecordName) -> [LocalChange] {
        switch name.type {
        case .child: name.uuid.map { [.gone(childID: $0)] } ?? []
        case .entry: [.delete(name)] + (name.uuid.map { [.entryPhotos(entryID: $0, photoIDs: nil)] } ?? [])
        case .wardrobe: [.delete(name)]
        case .hero, .member, .photo, .offer, .saga: []
        }
    }

    /// A token names its store. One from another store file reads as "nothing after it" instead of throwing, which
    /// would lose every change for good, so it is checked against a transaction of this store. With no transaction
    /// there is nothing to read either way.
    private func isThisStores(_ token: DefaultHistoryToken) throws -> Bool {
        guard let latest = try latestTransaction() else { return true }
        return token.tokenValue?[latest.storeIdentifier] != nil
    }
}
