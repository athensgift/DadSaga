import Application
import Foundation
import os
import SwiftData

/// What turning iCloud on came to.
enum TurnOnResult: Hashable, Sendable {
    case turnedOn
    /// No Apple Account is signed in.
    case noAccount
    /// There is no saga on this iPhone to sync.
    case noSaga
    /// iCloud holds a saga `Sync.store` doesn't name: nothing was written or sent, and the parent is asked which to
    /// keep (ADR-0065 §2).
    case iCloudHoldsAnotherSaga
}

/// Moves the saga between its store and iCloud (ADR-0065 §2, §4): the dad's changes from the store's history into
/// `Sync.store` and on to the engines, and what the engines fetch into the store through the applier. One delegate
/// for both engines.
///
/// `Sync.store` is the record of what waits; an engine's own list is given again from it at every launch. Every
/// operation runs to its end before the next starts (`onChain`), since an actor lets other calls in at every `await`.
/// Nothing on the chain waits for a fetch or a send: the engine calls back into the chain while one runs.
actor SyncCoordinator: FamilySync, SyncEngineDelegate {
    /// What a batch remembers of a record it carried, for when the engine reports it sent.
    struct Outgoing: Sendable {
        /// The state of the change the batch was built from: one merged in since is sent again.
        let revision: Int
        /// A photo's entry.
        var entryID: UUID?
    }

    static let logger = Logger(subsystem: "DadSaga", category: "sync")
    /// The server's limit for one request, saves and deletions together (ADR-0065 §1).
    static let batchLimit = 250

    let saga: StoreConnection
    let syncStore: SyncStoreConnection
    let photos: FilePhotoStore
    /// The answers as the iPhone keeps them: writing one here never comes back as a record to send. Always the
    /// repository that only stores, never `SyncedSagaOfferRepository`: this one is written to from inside a turn on
    /// the chain (`apply`, `renameOffers`), and the synced one tells sync of every answer, which is a turn on the
    /// chain too. Awaited from inside one, the chain would wait for itself.
    let offers: any SagaOfferRepository
    let content: any ContentRepository
    let cloud: any SyncCloud

    var engines: [SyncDatabase: any SyncEngine] = [:]
    /// The engine of each database that is listened to: one replaced since may still report, and is not.
    var engineIDs: [SyncDatabase: SyncEngineID] = [:]
    private var lastGeneration = 0
    var outgoing: [RecordName: Outgoing] = [:]
    /// Databases whose engine state is no longer kept this run: a fetched batch couldn't be applied, so the next
    /// launch starts from the state kept before it and fetches that batch again.
    var unapplied: Set<SyncDatabase> = []
    /// The databases whose fetch has ended since the history token expired.
    var fetchedSinceExpiry: Set<SyncDatabase> = []
    /// A save found no family zone in the partner's iCloud: the fetch that follows says whether sharing ended.
    var familyZoneNotFound = false
    /// The fetch under way listed the family's zone among those of the partner's iCloud: it is there.
    var familyZoneListed = false
    private var chain = SerialTaskQueue()
    private var listening: Task<Void, Never>?

    init(
        saga: StoreConnection, syncStore: SyncStoreConnection, photos: FilePhotoStore,
        offers: any SagaOfferRepository, content: any ContentRepository, cloud: any SyncCloud
    ) {
        self.saga = saga
        self.syncStore = syncStore
        self.photos = photos
        self.offers = offers
        self.content = content
        self.cloud = cloud
    }

    deinit {
        listening?.cancel()
    }

    // MARK: - One operation at a time

    /// Runs `operation` once every operation given before it has ended.
    func onChain<Success: Sendable>(_ operation: @escaping @Sendable () async throws -> Success) async throws -> Success {
        let task = chain.add { () async -> Result<Success, any Error> in
            do {
                return .success(try await operation())
            } catch {
                return .failure(error)
            }
        }
        return try await task.value.get()
    }

    /// As `onChain`, for what has no one to throw to: a failure is logged, and what waited still waits in
    /// `Sync.store`. Never anything from a record (ADR-0065 §7): see `syncLogLabel`.
    func quietly(_ what: StaticString, _ operation: @escaping @Sendable () async throws -> Void) async {
        do {
            try await onChain(operation)
        } catch {
            Self.logger.error("Sync, \(what, privacy: .public): \(error.syncLogLabel, privacy: .public)")
        }
    }

    /// The ledger while iCloud is on; nil while it is off or was never on.
    func ledgerWhileOn() async throws -> SyncLedger? {
        guard let ledger = try await syncStore.open(creating: false), try await ledger.settings().isOn else { return nil }
        return ledger
    }

    // MARK: - FamilySync

    func status() async -> ShareStatus {
        do {
            guard let ledger = try await ledgerWhileOn() else { return ShareStatus(sharing: .off) }
            let settings = try await ledger.settings()
            var status = ShareStatus(sharing: .alone)
            if settings.database(for: .family) == .shared {
                status.sharing = .partner
            } else if try await ledger.members().values.contains(where: { $0 != settings.account }) {
                status.sharing = .owner
            }
            if settings.pause == .signedOut {
                status.waiting = .signedOut
            } else if settings.follow != nil {
                status.waiting = .followFamily
            } else if settings.pause == .iCloudFull {
                status.waiting = .iCloudFull(isPartners: settings.fullDatabase == .shared)
            }
            return status
        } catch {
            Self.logger.error("Sync, status: \(error.syncLogLabel, privacy: .public)")
            return ShareStatus(sharing: .off)
        }
    }

    func resume() async {
        await quietly("resume") { try await self.resumeOnChain() }
    }

    private func resumeOnChain() async throws {
        let feed = try await saga.open().feed
        guard let ledger = try await syncStore.open(creating: false) else { return try await feed.trim() }
        guard try await ledger.settings().isOn else {
            try await rememberGone(ledger, feed)
            return try await feed.trim()
        }
        try await checkAccount(ledger)
        let settings = try await ledger.settings()
        guard settings.isOn else { return }
        try await makeEngines(ledger, settings)
        try await drain(ledger)
        // A kill between an answer and its record, or an entry changed while the history couldn't be read.
        try await ledger.send(neverSent: try await offerRecords() + photoRecords(feed))
        if settings.pause == .iCloudFull { try await ledger.pause(nil) }
        try await give(ledger)
        try await endMove(ledger)
        listen(to: feed)
    }

    /// A sign-out whose account is back goes on; with another account sync is off for this saga (ADR-0065 §4).
    private func checkAccount(_ ledger: SyncLedger) async throws {
        let user: String?
        do {
            user = try await cloud.currentUser()
        } catch {
            // Not known right now: sync stays as it was.
            Self.logger.error("Sync, the account: \(error.syncLogLabel, privacy: .public)")
            return
        }
        let settings = try await ledger.settings()
        if user == nil {
            if settings.pause != .signedOut { try await ledger.pause(.signedOut) }
        } else if user != settings.account {
            try await turnOff(ledger, .otherAccount)
        } else if settings.pause == .signedOut {
            try await ledger.accountReturned()
        }
    }

    // MARK: - Turning on

    /// Turns iCloud on for the account signed in (ADR-0065 §2). Every row is enqueued once, and the change feed reads
    /// on from the token taken then. When iCloud already holds the family `Sync.store` names (it is turned on again),
    /// nothing is sent until the zone has been fetched: a row it has merges as usual, and one it lacks is sent.
    func turnOn() async throws -> TurnOnResult {
        try await onChain { try await self.turnOnOnChain() }
    }

    private func turnOnOnChain() async throws -> TurnOnResult {
        if try await ledgerWhileOn() != nil { return .turnedOn }
        guard let user = try await cloud.currentUser() else { return .noAccount }
        let feed = try await saga.open().feed
        // The token first: a write that lands after it is read by the next drain, and at worst sent twice.
        let token = try await feed.latestToken()
        guard try await feed.everyRecordName().contains(where: { $0.type == .hero }) else { return .noSaga }
        let before = try await syncStore.open(creating: false)
        let named = try await before?.settings().familyZone
        let held = try await cloud.sagaRecord()
        if let held, held.sagaFamilyZone == nil || held.sagaFamilyZone != named { return .iCloudHoldsAnotherSaga }
        let ledger = try await syncStore.make()
        if before != nil { try await rememberGone(ledger, feed) }
        try await keepChildrenACopyBroughtBack(ledger)
        try await start(ledger, for: user, named: named, readingFrom: token, again: held != nil)
        listen(to: feed)
        return .turnedOn
    }

    /// `again`: iCloud holds the family `named` already, so nothing is sent before its zones have been fetched.
    /// Otherwise the zones are made and every record goes whole, into the family zone `Sync.store` named when it is
    /// this parent's, or a new one.
    private func start(
        _ ledger: SyncLedger, for user: String, named: SyncZone?, readingFrom token: DefaultHistoryToken?, again: Bool
    ) async throws {
        var family = (id: UUID(), owner: user)
        if case .family(let id, let owner)? = named, again || owner == user { family = (id, owner) }
        var names: [RecordName] = []
        if !again {
            for scope in SyncScope.allCases { names += try await everyRecord(in: scope, ledger) }
        }
        forgetEngines()
        try await ledger.turnOn(account: user, family: family, token: token, sending: names, afterFetch: again)
        let settings = try await ledger.settings()
        try await makeEngines(ledger, settings)
        if !again, let zone = settings.familyZone { await engines[.private]?.add([.save(.personal), .save(zone)]) }
        try await give(ledger)
    }

    // MARK: - Engines, and the store's own changes

    func makeEngines(_ ledger: SyncLedger, _ settings: SyncSettings) async throws {
        for database in settings.databases where engines[database] == nil {
            lastGeneration += 1
            let id = SyncEngineID(database: database, generation: lastGeneration)
            engineIDs[database] = id
            engines[database] = cloud.makeEngine(id, state: try await ledger.engineState(database), delegate: self)
        }
    }

    /// What the dad changed since the store was last read, into `Sync.store` and on to the engines. The store asks
    /// for this by itself after every save; a caller that can't wait for that asks here.
    func drain() async {
        await quietly("drain") {
            guard let ledger = try await self.ledgerWhileOn() else { return }
            try await self.drain(ledger)
        }
    }

    /// The history after the ledger's token, recorded with the new token in one save, then deleted before it
    /// (ADR-0065 §2): a kill in between reads the same changes again, which merge to the same rows. When the token has
    /// expired, reading starts again from the latest one and every row the zone lacks goes after the next fetch.
    func drain(_ ledger: SyncLedger) async throws {
        let feed = try await saga.open().feed
        let settings = try await ledger.settings()
        switch try await feed.read(after: settings.historyToken) {
        case .changes(let changes, let token):
            if !changes.isEmpty || token != settings.historyToken {
                try await ledger.record(changes, through: token)
                if let token { try await feed.deleteHistory(before: token) }
            }
        case .tokenExpired:
            fetchedSinceExpiry = []
            try await ledger.historyExpired(readingFrom: try await feed.latestToken())
        }
        try await give(ledger)
    }

    /// Everything that waits and isn't held behind a fetch, to its engine. Not while signed out, and not into an
    /// iCloud that is full: those wait in `Sync.store` (ADR-0065 §4).
    func give(_ ledger: SyncLedger) async throws {
        let settings = try await ledger.settings()
        guard settings.isOn, settings.pause != .signedOut else { return }
        let waiting = try await ledger.pending().filter { !$0.behindFetch }
        for database in settings.databases where !settings.isFull(database) {
            await engines[database]?.add(changes(for: waiting, in: database, settings))
        }
    }

    /// Each of `pending` that goes to `database`, as the engine holds it. None of the family's while they wait for
    /// the parent to follow another family, or for the family's zone to be fetched whole (ADR-0065 §2, §4). And no
    /// `saga` that still waited when a join or a rebuild began, until the family's zone holds everything: it would
    /// name that family already.
    func changes(for pending: [PendingChange], in database: SyncDatabase, _ settings: SyncSettings) -> [SyncChange] {
        guard let zones = settings.zones else { return [] }
        return pending.filter { change in
            let scope = change.name.type.scope
            return settings.database(for: scope) == database && !(scope == .family && settings.familyWaits)
                && !(change.name == .saga && settings.sagaWaitsForFamily)
        }.map { change in
            let zone = zones.zone(for: change.name.type)
            return change.isDeletion ? .delete(change.name, zone) : .save(change.name, zone)
        }
    }

    /// The store wakes sync, not each call site (ADR-0065 §2): one drain after each save, and at most one more waiting
    /// while it runs.
    private func listen(to feed: StoreChangeFeed) {
        guard listening == nil else { return }
        let saves = feed.saves()
        listening = Task { [weak self] in
            for await _ in saves { await self?.drain() }
        }
    }

    func stopListening() {
        listening?.cancel()
        listening = nil
    }

    /// The engines, and what was remembered of their batches and fetches, go: the next ones start from what
    /// `Sync.store` holds.
    func forgetEngines() {
        engines = [:]
        engineIDs = [:]
        outgoing = [:]
        unapplied = []
        fetchedSinceExpiry = []
        (familyZoneNotFound, familyZoneListed) = (false, false)
    }

    /// One database's engine goes, and what was remembered of the family's batches: its zone is another now.
    func forgetEngine(_ database: SyncDatabase) {
        engines[database] = nil
        engineIDs[database] = nil
        unapplied.remove(database)
        fetchedSinceExpiry.remove(database)
        outgoing = outgoing.filter { $0.key.type.scope == .personal && database != .private }
        if database == .shared { (familyZoneNotFound, familyZoneListed) = (false, false) }
    }
}

extension Error {
    /// All a log says of an error met in sync (ADR-0065 §7): its domain, which for a Swift error is its type, and its
    /// code. Never its description, which for CloudKit's and SwiftData's errors can carry a record's name (an id),
    /// a zone's (an account) or a value.
    var syncLogLabel: String {
        let error = self as NSError
        return "\(error.domain) \(error.code)"
    }
}
