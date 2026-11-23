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
        try modelContext.localChanges(after: token)
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
        try modelContext.latestTransaction()?.token
    }

    /// The rows' values now, for a batch: a pending change holds field names, never values, so a later edit rides
    /// along. A row gone since has no record here. A child in `gone` is the marker, whatever was asked. Only records
    /// that mirror a saga row: the others are `Sync.store`'s and the defaults'.
    func records(_ wanted: [(name: RecordName, fields: Set<String>?)], zones: SyncZones, gone: Set<UUID>) throws -> [SyncRecord] {
        try wanted.compactMap { name, fields in
            switch name.type {
            case .hero:
                guard let id = name.uuid else { return nil }
                return try modelContext.row(ProfileRecord.self, #Predicate { $0.profileID == id })?
                    .syncRecord(fields: fields, zones: zones)
            case .wardrobe:
                let skill = name.id
                return try modelContext.row(OutfitRecord.self, #Predicate { $0.skill == skill })?
                    .syncRecord(fields: fields, zones: zones)
            case .child:
                guard let id = name.uuid else { return nil }
                if gone.contains(id) { return ChildRecord.goneRecord(childID: id, zones: zones) }
                return try modelContext.row(ChildRecord.self, #Predicate { $0.childID == id })?
                    .syncRecord(fields: fields, zones: zones)
            case .entry:
                guard let id = name.uuid else { return nil }
                return try modelContext.row(ProgressEventRecord.self, #Predicate { $0.eventID == id })?
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
}

/// `NotificationCenter`'s observer token is not `Sendable`; it is only ever handed back to remove the observer.
private struct SaveObserver: @unchecked Sendable {
    let token: any NSObjectProtocol

    init(_ token: any NSObjectProtocol) {
        self.token = token
    }
}
