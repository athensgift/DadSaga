import Foundation
import SwiftData

/// One change the dad made to the saga store, as the record change sync sends for it (ADR-0065 §2).
enum LocalChange: Hashable, Sendable {
    /// `fields` nil: every field (the row was inserted).
    case save(RecordName, fields: Set<String>?)
    case delete(RecordName)
    /// A child deleted for good: the only way a child row goes by the dad's own edit (ADR-0065 §4). Sent as the marker.
    case gone(childID: UUID)
    /// The entry's photo ids now, to compare with the photos `Sync.store` knows for it; nil: the entry went.
    case entryPhotos(entryID: UUID, photoIDs: [String]?)
}

/// What the history holds after a token.
enum FeedRead: Hashable, Sendable {
    /// The changes in order, and the token of the last transaction read: the one given when there was none.
    case changes([LocalChange], through: DefaultHistoryToken?)
    /// History up to the token is gone, or the token is another store's: what changed since can't be told
    /// (ADR-0065 §2, "History's two edges").
    case tokenExpired
}

/// Reads the saga store's history after a token into the record changes sync sends (ADR-0065 §2), so a write and its
/// sync can't come apart and a write path added later syncs without anyone remembering to. An actor on the store's one
/// queue (ADR-0068): it reads each row as last saved.
///
/// Transactions saved under the `sync` author are skipped: sync's own writes, and the rows a restore or start over
/// replaced.
actor StoreChangeFeed: SagaStoreActor {
    nonisolated let modelExecutor: any ModelExecutor
    nonisolated let modelContainer: ModelContainer

    init(queue: DefaultSerialModelExecutor, container: ModelContainer) {
        modelExecutor = queue
        modelContainer = container
    }

    /// The dad's changes after `token`; every one the history holds when it is nil.
    func read(after token: DefaultHistoryToken?) throws -> FeedRead {
        var descriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        if let token {
            guard try isThisStores(token) else { return .tokenExpired }
            descriptor.predicate = #Predicate { $0.token > token }
        }
        let transactions: [DefaultHistoryTransaction]
        do {
            transactions = try modelContext.fetchHistory(descriptor).sorted { $0.token < $1.token }
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

    /// Deletes the history before `token`, once `Sync.store` holds what was read through it (ADR-0065 §2). The token's
    /// own transaction stays: SwiftData reads "after a token" only while that transaction is still in the history, and
    /// calls the token expired once it is gone.
    func deleteHistory(before token: DefaultHistoryToken) throws {
        try modelContext.deleteHistory(HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.token < token }))
    }

    /// While iCloud is off, at launch beside the orphan sweep: every transaction, so the history never grows
    /// (ADR-0065 §2). Any token taken before it is expired afterwards.
    func trim() throws {
        try modelContext.deleteHistory(HistoryDescriptor<DefaultHistoryTransaction>())
    }

    /// The last transaction's token, to start reading from when iCloud is turned on; nil while the history is empty,
    /// which reads from its start.
    func latestToken() throws -> DefaultHistoryToken? {
        try latestTransaction()?.token
    }

    /// The rows' values now, for a batch: a pending change holds field names, never values, so a later edit rides
    /// along. A row gone since has no record here. A child in `gone` is the marker, whatever was asked. Only records
    /// that mirror a saga row: the others are `Sync.store`'s and the defaults'.
    func records(_ wanted: [(name: RecordName, fields: Set<String>?)], zones: SyncZones, gone: Set<UUID>) throws -> [SyncRecord] {
        try wanted.compactMap { name, fields in
            switch name.type {
            case .hero:
                guard let id = name.uuid else { return nil }
                return try row(ProfileRecord.self, #Predicate { $0.profileID == id })?.syncRecord(fields: fields, zones: zones)
            case .wardrobe:
                let skill = name.id
                return try row(OutfitRecord.self, #Predicate { $0.skill == skill })?.syncRecord(fields: fields, zones: zones)
            case .child:
                guard let id = name.uuid else { return nil }
                if gone.contains(id) { return ChildRecord.goneRecord(childID: id, zones: zones) }
                return try row(ChildRecord.self, #Predicate { $0.childID == id })?.syncRecord(fields: fields, zones: zones)
            case .entry:
                guard let id = name.uuid else { return nil }
                return try row(ProgressEventRecord.self, #Predicate { $0.eventID == id })?
                    .syncRecord(fields: fields, zones: zones)
            case .member, .photo, .offer, .saga:
                return nil
            }
        }
    }

    /// Every row's record name, for turning iCloud on and for a full send.
    func everyRecordName() throws -> [RecordName] {
        try modelContext.fetch(FetchDescriptor<ProfileRecord>()).map(\.recordName)
            + modelContext.fetch(FetchDescriptor<OutfitRecord>()).map(\.recordName)
            + modelContext.fetch(FetchDescriptor<ChildRecord>()).map(\.recordName)
            + modelContext.fetch(FetchDescriptor<ProgressEventRecord>()).map(\.recordName)
    }

    /// Each entry's photo ids, for the comparison at launch with the photos `Sync.store` knows.
    func entryPhotos() throws -> [UUID: [String]] {
        let entries = try modelContext.fetch(FetchDescriptor<ProgressEventRecord>())
        return Dictionary(entries.map { ($0.eventID, $0.photoIDs) }, uniquingKeysWith: { first, _ in first })
    }

    /// One element after each save of the store's context, whoever wrote: the store wakes sync, not each call site.
    /// At most one waits unread.
    nonisolated func saves() -> AsyncStream<Void> {
        let context = modelExecutor.modelContext
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let observer = SaveObserver(NotificationCenter.default.addObserver(
                forName: ModelContext.didSave, object: context, queue: nil
            ) { _ in continuation.yield() })
            continuation.onTermination = { _ in NotificationCenter.default.removeObserver(observer.token) }
        }
    }

    // MARK: - Reading

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

    private func row<Row: PersistentModel>(_: Row.Type, _ predicate: Predicate<Row>) throws -> Row? {
        var descriptor = FetchDescriptor<Row>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func latestTransaction() throws -> DefaultHistoryTransaction? {
        var descriptor = HistoryDescriptor<DefaultHistoryTransaction>(sortBy: [SortDescriptor(\.token, order: .reverse)])
        descriptor.fetchLimit = 1
        return try modelContext.fetchHistory(descriptor).first
    }

    /// A token names its store. One from another store file reads as "nothing after it" instead of throwing, which
    /// would lose every change for good, so it is checked against a transaction of this store. With no transaction
    /// there is nothing to read either way.
    private func isThisStores(_ token: DefaultHistoryToken) throws -> Bool {
        guard let latest = try latestTransaction() else { return true }
        return token.tokenValue?[latest.storeIdentifier] != nil
    }
}

/// `NotificationCenter`'s observer token is not `Sendable`; it is only ever handed back to remove the observer.
private struct SaveObserver: @unchecked Sendable {
    let token: any NSObjectProtocol

    init(_ token: any NSObjectProtocol) {
        self.token = token
    }
}
