import Foundation

/// One record's change an engine holds to send. It names the record; the delegate builds what is sent when asked.
public enum SyncChange: Hashable, Sendable {
    case save(RecordName, SyncZone)
    case delete(RecordName, SyncZone)

    public var name: RecordName {
        switch self {
        case .save(let name, _), .delete(let name, _): name
        }
    }

    public var zone: SyncZone {
        switch self {
        case .save(_, let zone), .delete(_, let zone): zone
        }
    }

    public var isDeletion: Bool {
        if case .delete = self { true } else { false }
    }
}

public enum ZoneChange: Hashable, Sendable {
    case save(SyncZone)
    case delete(SyncZone)
}

/// Why a zone went (ADR-0065 §4): another iPhone deleted it, the parent deleted the app's data in iCloud's settings,
/// or the account's encrypted data was reset.
public enum ZoneDeletionReason: Hashable, Sendable {
    case deleted, purged, encryptedDataReset
}

public struct ZoneDeletion: Hashable, Sendable {
    public let zone: SyncZone
    public let reason: ZoneDeletionReason

    public init(zone: SyncZone, reason: ZoneDeletionReason) {
        self.zone = zone
        self.reason = reason
    }
}

/// The Apple Account changed under the engine. Each name is a real user record name.
public enum AccountChange: Hashable, Sendable {
    case signIn(current: String)
    case signOut(previous: String)
    case switchAccounts(previous: String, current: String)
}

/// Why a save or a deletion didn't happen, of the errors an engine doesn't retry by itself.
public enum SyncSaveError: Error, Hashable, Sendable {
    /// The zone holds a newer record than the one the save was set on, or one where a new record was sent: the
    /// server's record, whole.
    case serverRecordChanged(SyncRecord)
    /// No record for the system fields the save carried: it was deleted, or its zone was made again.
    case unknownItem
    case zoneNotFound
    case quotaExceeded
    case other
}

public struct FailedSave: Hashable, Sendable {
    public let record: SyncRecord
    public let error: SyncSaveError

    public init(record: SyncRecord, error: SyncSaveError) {
        self.record = record
        self.error = error
    }
}

public struct FailedDeletion: Hashable, Sendable {
    public let change: SyncChange
    public let error: SyncSaveError

    public init(change: SyncChange, error: SyncSaveError) {
        self.change = change
        self.error = error
    }
}

public struct FailedZoneSave: Hashable, Sendable {
    public let zone: SyncZone
    public let error: SyncSaveError

    public init(zone: SyncZone, error: SyncSaveError) {
        self.zone = zone
        self.error = error
    }
}

/// What became of one batch of records.
public struct SentRecords: Hashable, Sendable {
    /// Each saved record with the system fields the server gave it.
    public var saved: [SyncRecord]
    public var failed: [FailedSave]
    public var deleted: [SyncChange]
    public var failedDeletions: [FailedDeletion]

    public init(
        saved: [SyncRecord] = [], failed: [FailedSave] = [], deleted: [SyncChange] = [],
        failedDeletions: [FailedDeletion] = []
    ) {
        self.saved = saved
        self.failed = failed
        self.deleted = deleted
        self.failedDeletions = failedDeletions
    }
}

public struct SentZones: Hashable, Sendable {
    public var saved: [SyncZone]
    public var failed: [FailedZoneSave]
    public var deleted: [SyncZone]

    public init(saved: [SyncZone] = [], failed: [FailedZoneSave] = [], deleted: [SyncZone] = []) {
        self.saved = saved
        self.failed = failed
        self.deleted = deleted
    }
}

/// What an engine tells its delegate, one event at a time.
public enum SyncEvent: Sendable {
    /// The engine's own state, to keep and hand back when the engine is next made.
    case stateUpdate(Data)
    case accountChange(AccountChange)
    case fetchedZones(modified: [SyncZone], deleted: [ZoneDeletion])
    /// Records as the zone holds them now, whole, and the records deleted in it (`.delete` changes).
    case fetchedRecords(modified: [SyncRecord], deleted: [SyncChange])
    case sentZones(SentZones)
    case sentRecords(SentRecords)
    /// A fetch ended: every change up to it has been handed over.
    case didFetchChanges
}

/// What the sync core uses of one `CKSyncEngine`, which serves one database (ADR-0065 §2, §8). The app's engine wraps
/// CloudKit's; the tests' keeps zones in memory.
///
/// An engine keeps at most one change waiting per record: one added replaces the one it held. A save or a deletion it
/// reports failed has left its list. It never calls its delegate from inside `add` or `remove`.
public protocol SyncEngine: Sendable {
    var database: SyncDatabase { get }
    func add(_ changes: [SyncChange]) async
    func remove(_ changes: [SyncChange]) async
    func add(_ zones: [ZoneChange]) async
    /// `zones` nil: every zone of the database. Never called while the delegate handles an event.
    func fetchChanges(in zones: [SyncZone]?) async throws
    /// Never called while the delegate handles an event.
    func sendChanges() async throws
}

/// One batch to send.
public struct SyncBatch: Hashable, Sendable {
    public var saves: [SyncRecord]
    public var deletions: [SyncChange]

    public init(saves: [SyncRecord] = [], deletions: [SyncChange] = []) {
        self.saves = saves
        self.deletions = deletions
    }
}

public protocol SyncEngineDelegate: AnyObject, Sendable {
    func handle(_ event: SyncEvent, from database: SyncDatabase) async
    /// The next records to send of those the engine holds: 250 at most, members, children, entries, then photos
    /// (ADR-0065 §1). Nil when nothing of them is left to send.
    func nextBatch(for pending: [SyncChange], from database: SyncDatabase) async -> SyncBatch?
}

/// The iCloud container: the account, one record read by itself, and the engines.
public protocol SyncCloud: Sendable {
    /// The real user record name of the Apple Account; nil: none is signed in.
    func currentUser() async throws -> String?
    /// The `saga` record of the parent's own zone, read outside any engine, so nothing is fetched or applied before
    /// the parent is asked which saga to keep (ADR-0065 §2). Nil: iCloud holds none.
    func sagaRecord() async throws -> SyncRecord?
    /// `state`: what the last engine for this database reported in `stateUpdate`; nil starts from nothing, and its
    /// first fetch brings every zone whole. An engine made earlier for the same database reports nothing from then
    /// on: what the delegate does when a fetch ends counts on that fetch being the new engine's.
    func makeEngine(_ database: SyncDatabase, state: Data?, delegate: any SyncEngineDelegate) -> any SyncEngine
}
