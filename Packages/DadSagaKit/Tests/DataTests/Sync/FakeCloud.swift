import Foundation
@testable import Data

/// The iCloud of several Apple Accounts, in memory (ADR-0065 §8): each account's private database with its zones, the
/// zones shared with it, change tags, creators, quotas and the three ways a zone goes. It answers as CloudKit does
/// where the sync core depends on the answer; `FakeCloudTests` pin those answers.
actor FakeCloud {
    /// A zone as the server names it: the account whose database holds it, and the zone as that account's own
    /// engines see it.
    struct ZoneID: Hashable {
        let owner: String
        let zone: SyncZone

        init(_ zone: SyncZone, for account: String) {
            self.zone = zone
            if case .family(_, let owner) = zone { self.owner = owner } else { owner = account }
        }
    }

    struct StoredRecord {
        var fields: [String: SyncValue] = [:]
        var asset: Data?
        /// Grows with every save: a save set on an older one meets `serverRecordChanged`.
        var tag = 0
        let creator: String

        var bytes: Int {
            fields.reduce(asset?.count ?? 0) { $0 + $1.key.utf8.count + $1.value.bytes }
        }
    }

    struct ZoneState {
        /// A zone made again under its name is another incarnation: system fields from the old one name nothing.
        let incarnation: Int
        var records: [RecordName: StoredRecord] = [:]
        /// The zone's change log: where each record last changed, or was deleted.
        var changed: [RecordName: Int] = [:]
        var deleted: [RecordName: Int] = [:]
        var sequence = 0
        var participants: Set<String> = []
    }

    /// How far a device has read a zone.
    struct ZoneToken: Codable, Hashable {
        var incarnation: Int
        var sequence: Int
    }

    struct DatabaseKey: Hashable {
        let account: String
        let database: SyncDatabase
    }

    struct DatabaseChange {
        let sequence: Int
        let zone: SyncZone
        /// Nil: the zone appeared.
        let deletion: ZoneDeletionReason?
    }

    /// What a database fetch reports of its zones.
    struct ZoneChanges {
        var appeared: [SyncZone]
        var deleted: [ZoneDeletion]
        var token: Int
    }

    /// What a zone fetch reports of its records.
    struct RecordChanges {
        var modified: [SyncRecord]
        var deleted: [RecordName]
        var token: ZoneToken
    }

    /// What a record's system fields are here: enough to tell a stale save.
    struct SystemFields: Codable {
        var incarnation: Int
        var name: String
        var tag: Int
    }

    var zones: [ZoneID: ZoneState] = [:]
    var databaseLogs: [DatabaseKey: [DatabaseChange]] = [:]
    var quotas: [String: Int] = [:]
    var incarnations = 0
    var databaseSequence = 0
    /// Fetched records come newest first: CloudKit promises no order.
    var deliversInReverse = false
    /// The names each request saved and deleted, in the order they were sent.
    var requests: [[RecordName]] = []
    /// Runs once, when the next request has arrived and before it is answered: what happens while a batch is out.
    var whileNextRequestIsOut: (@Sendable () async -> Void)?
    /// Where a fetched photo's file is put.
    let downloads: URL

    init(downloads: URL) {
        self.downloads = downloads
    }

    func whileNextRequestIsOut(_ happens: @escaping @Sendable () async -> Void) {
        whileNextRequestIsOut = happens
    }

    func setDeliversInReverse(_ reversed: Bool) {
        deliversInReverse = reversed
    }

    /// How many bytes of records and photos the account's iCloud holds at most. A partner's saves count here too.
    func setQuota(_ account: String, bytes: Int?) {
        quotas[account] = bytes
    }

    func usage(of account: String) -> Int {
        zones.filter { $0.key.owner == account }.values.flatMap(\.records.values).reduce(0) { $0 + $1.bytes }
    }

    // MARK: - Zones

    /// Makes the zone in the account's private database; one that is there stays as it is.
    func saveZone(_ zone: SyncZone, as account: String) {
        let id = ZoneID(zone, for: account)
        guard id.owner == account, zones[id] == nil else { return }
        incarnations += 1
        zones[id] = ZoneState(incarnation: incarnations)
        log(zone, nil, for: account, .private)
    }

    /// Another of the account's iPhones deletes the zone, or the zone goes for `reason`. It vanishes for the people it
    /// was shared with too.
    func deleteZone(_ zone: SyncZone, by account: String, reason: ZoneDeletionReason = .deleted) {
        let id = ZoneID(zone, for: account)
        guard id.owner == account, let state = zones.removeValue(forKey: id) else { return }
        log(zone, reason, for: account, .private)
        for participant in state.participants { log(zone, reason, for: participant, .shared) }
    }

    /// The person deletes DadSaga's data in iCloud's settings: every zone of their private database, `purged`.
    func purge(_ account: String) {
        for id in zones.keys where id.owner == account { deleteZone(id.zone, by: account, reason: .purged) }
    }

    /// The account's encrypted data is reset: every zone of its private database, Personal too.
    func resetEncryptedData(_ account: String) {
        for id in zones.keys where id.owner == account { deleteZone(id.zone, by: account, reason: .encryptedDataReset) }
    }

    /// The owner shares the whole zone with `account`: it appears in that account's shared database.
    func share(_ zone: SyncZone, with account: String) {
        let id = ZoneID(zone, for: account)
        guard zones[id]?.participants.insert(account).inserted == true else { return }
        log(zone, nil, for: account, .shared)
    }

    /// The owner stops sharing: the zone stays theirs and vanishes for everyone else, reported `deleted`.
    func stopSharing(_ zone: SyncZone) {
        guard case .family(_, let owner) = zone, let state = zones[ZoneID(zone, for: owner)] else { return }
        zones[ZoneID(zone, for: owner)]?.participants = []
        for participant in state.participants { log(zone, .deleted, for: participant, .shared) }
    }

    /// The zones an account's database shows: its own in the private one, those shared with it in the shared one.
    func zones(of account: String, in database: SyncDatabase = .private) -> [SyncZone] {
        zones.filter { isVisible($0.key, $0.value, to: account, in: database) }.map(\.key.zone)
            .sorted { String(describing: $0) < String(describing: $1) }
    }

    /// The zones that appeared and went in a database since `token`; with none, every zone there is and no deletion.
    func zoneChanges(
        for account: String, in database: SyncDatabase, since token: Int?
    ) -> ZoneChanges {
        guard let token else {
            return ZoneChanges(appeared: zones(of: account, in: database), deleted: [], token: databaseSequence)
        }
        let changes = (databaseLogs[DatabaseKey(account: account, database: database)] ?? []).filter { $0.sequence > token }
        var deleted: [SyncZone: ZoneDeletionReason] = [:]
        for change in changes { deleted[change.zone] = change.deletion ?? deleted[change.zone] }
        let here = Set(zones(of: account, in: database))
        return ZoneChanges(
            appeared: Set(changes.filter { $0.deletion == nil }.map(\.zone)).intersection(here).sorted { "\($0)" < "\($1)" },
            deleted: deleted.map { ZoneDeletion(zone: $0.key, reason: $0.value) }.sorted { "\($0.zone)" < "\($1.zone)" },
            token: databaseSequence
        )
    }

    func isVisible(_ id: ZoneID, _ state: ZoneState, to account: String, in database: SyncDatabase) -> Bool {
        database == .private ? id.owner == account : state.participants.contains(account)
    }

    private func log(_ zone: SyncZone, _ deletion: ZoneDeletionReason?, for account: String, _ database: SyncDatabase) {
        databaseSequence += 1
        databaseLogs[DatabaseKey(account: account, database: database), default: []]
            .append(DatabaseChange(sequence: databaseSequence, zone: zone, deletion: deletion))
    }
}

extension SyncValue {
    /// Roughly what the value takes of a quota.
    var bytes: Int {
        switch self {
        case .string(let string): string.utf8.count
        case .strings(let strings): strings.reduce(0) { $0 + $1.utf8.count }
        case .int, .date: 8
        case .bool: 1
        case .cleared: 0
        }
    }
}
