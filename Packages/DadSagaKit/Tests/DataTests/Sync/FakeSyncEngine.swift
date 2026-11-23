import Foundation
import Synchronization
import Testing
@testable import Data

/// One iPhone's view of the fake iCloud (ADR-0065 §8): the account signed in on it, and the engines made for it. Two
/// of these on one `FakeCloud` are two iPhones.
final class FakeSyncCloud: SyncCloud {
    private struct State {
        var account: String?
        var engines: [FakeSyncEngine] = []
    }

    let cloud: FakeCloud
    private let state: Mutex<State>

    init(cloud: FakeCloud, account: String?) {
        self.cloud = cloud
        state = Mutex(State(account: account))
    }

    var account: String? { state.withLock { $0.account } }
    var engines: [FakeSyncEngine] { state.withLock { $0.engines } }

    /// The engine the coordinator last made for a database.
    func engine(_ database: SyncDatabase = .private) -> FakeSyncEngine? {
        engines.first { $0.database == database }
    }

    func currentUser() async throws -> String? { account }

    func sagaRecord() async throws -> SyncRecord? {
        guard let account else { return nil }
        return await cloud.record(.saga, in: .personal, of: account)
    }

    /// An engine that is replaced is not told: it goes on reporting to its delegate if something still calls it.
    func makeEngine(_ id: SyncEngineID, state: Data?, delegate: any SyncEngineDelegate) -> any SyncEngine {
        let engine = FakeSyncEngine(cloud: cloud, device: self, id: id, state: state, delegate: delegate)
        self.state.withLock { $0.engines = $0.engines.filter { $0.database != id.database } + [engine] }
        return engine
    }

    /// The app is launched again: the engines of the last run are gone with it.
    func forgetEngines() {
        state.withLock { $0.engines = [] }
    }

    // MARK: - The account

    func signOut() async {
        guard let previous = account else { return }
        await change(to: nil, .signOut(previous: previous))
    }

    func signIn(_ account: String) async {
        await change(to: account, .signIn(current: account))
    }

    func switchAccount(to account: String) async {
        guard let previous = self.account else { return await signIn(account) }
        await change(to: account, .switchAccounts(previous: previous, current: account))
    }

    private func change(to account: String?, _ change: AccountChange) async {
        state.withLock { $0.account = account }
        for engine in engines { await engine.accountChanged(change) }
    }
}

/// What the sync core uses of `CKSyncEngine`, over a `FakeCloud` (ADR-0065 §8). Nothing syncs by itself: a test calls
/// `fetchChanges` and `sendChanges`, and "offline" is not calling them. Its state travels as JSON in `stateUpdate`
/// after each fetch and send, and is read back when the next engine is made with it: a relaunch.
actor FakeSyncEngine: SyncEngine {
    private struct State: Codable {
        var pending: [Change] = []
        var zones: [ZoneSave] = []
        var databaseToken: Int?
        var zoneTokens: [String: FakeCloud.ZoneToken] = [:]
    }

    private struct Change: Codable, Hashable {
        var name: String
        var zone: Zone
        var isDeletion: Bool

        init(_ change: SyncChange) {
            name = change.name.string
            zone = Zone(change.zone)
            isDeletion = change.isDeletion
        }

        var change: SyncChange? {
            RecordName(name).map { isDeletion ? .delete($0, zone.zone) : .save($0, zone.zone) }
        }
    }

    private struct ZoneSave: Codable, Hashable {
        var zone: Zone
        var isDeletion: Bool
    }

    private struct Zone: Codable, Hashable {
        var family: UUID?
        var owner: String?

        init(_ zone: SyncZone) {
            guard case .family(let id, let owner) = zone else { return }
            family = id
            self.owner = owner
        }

        var zone: SyncZone {
            if let family, let owner { .family(family, owner: owner) } else { .personal }
        }

        var key: String { family.map { "family-\($0)-\(owner ?? "")" } ?? "personal" }
    }

    /// Records come in batches of this many, as a long fetch does.
    static let fetchBatch = 100

    nonisolated let id: SyncEngineID
    nonisolated var database: SyncDatabase { id.database }
    private let cloud: FakeCloud
    private let device: FakeSyncCloud
    private weak var delegate: (any SyncEngineDelegate)?
    private var state: State
    /// How many records and zones this engine has tried to send and has fetched: a round that moves nothing has
    /// settled.
    private(set) var moved = 0
    /// How many records each request carried.
    private(set) var batchSizes: [Int] = []

    init(cloud: FakeCloud, device: FakeSyncCloud, id: SyncEngineID, state: Data?, delegate: any SyncEngineDelegate) {
        self.cloud = cloud
        self.device = device
        self.id = id
        self.delegate = delegate
        self.state = state.flatMap { try? JSONDecoder().decode(State.self, from: $0) } ?? State()
    }

    var pending: [SyncChange] { state.pending.compactMap(\.change) }

    func add(_ changes: [SyncChange]) {
        for change in changes.map(Change.init) {
            if let index = state.pending.firstIndex(where: { $0.name == change.name && $0.zone == change.zone }) {
                state.pending[index] = change
            } else {
                state.pending.append(change)
            }
        }
    }

    func remove(_ changes: [SyncChange]) {
        let gone = Set(changes.map(Change.init))
        state.pending.removeAll(where: gone.contains)
    }

    func add(_ zones: [ZoneChange]) {
        for change in zones {
            let save = switch change {
            case .save(let zone): ZoneSave(zone: Zone(zone), isDeletion: false)
            case .delete(let zone): ZoneSave(zone: Zone(zone), isDeletion: true)
            }
            state.zones.removeAll { $0.zone == save.zone }
            state.zones.append(save)
        }
    }

    func fetchChanges(in zones: [SyncZone]? = nil) async throws {
        let account = try #require(device.account, "No account is signed in")
        let changes = await cloud.zoneChanges(for: account, in: database, since: state.databaseToken)
        state.databaseToken = changes.token
        for deletion in changes.deleted { state.zoneTokens[Zone(deletion.zone).key] = nil }
        if !changes.appeared.isEmpty || !changes.deleted.isEmpty {
            moved += changes.appeared.count + changes.deleted.count
            await delegate?.handle(.fetchedZones(modified: changes.appeared, deleted: changes.deleted), from: id)
        }
        for zone in await cloud.zones(of: account, in: database) where zones?.contains(zone) ?? true {
            let key = Zone(zone).key
            guard let records = await cloud.recordChanges(in: zone, for: account, database, since: state.zoneTokens[key])
            else { continue }
            state.zoneTokens[key] = records.token
            moved += records.modified.count + records.deleted.count
            var modified = records.modified[...]
            var deleted = records.deleted.map { SyncChange.delete($0, zone) }
            while !modified.isEmpty || !deleted.isEmpty {
                await delegate?.handle(
                    .fetchedRecords(modified: Array(modified.prefix(Self.fetchBatch)), deleted: deleted), from: id
                )
                (modified, deleted) = (modified.dropFirst(Self.fetchBatch), [])
            }
        }
        await delegate?.handle(.didFetchChanges, from: id)
        await reportState()
    }

    /// Zones first, then batches for as long as the delegate has one. A save or a deletion that failed leaves the
    /// list, as with `CKSyncEngine`: the delegate adds it again once it has dealt with the failure.
    func sendChanges() async throws {
        let account = try #require(device.account, "No account is signed in")
        if !state.zones.isEmpty {
            var sent = SentZones()
            for change in state.zones {
                if change.isDeletion {
                    await cloud.deleteZone(change.zone.zone, by: account)
                    sent.deleted.append(change.zone.zone)
                } else {
                    await cloud.saveZone(change.zone.zone, as: account)
                    sent.saved.append(change.zone.zone)
                }
            }
            moved += state.zones.count
            state.zones = []
            await delegate?.handle(.sentZones(sent), from: id)
        }
        for round in 0... {
            guard !state.pending.isEmpty, let batch = await delegate?.nextBatch(for: pending, from: id) else { break }
            try #require(round < 100, "The same changes are sent over and over")
            batchSizes.append(batch.saves.count + batch.deletions.count)
            let sent = await cloud.modify(batch, as: account, in: database)
            let names = Set(batch.saves.map(\.name.string) + batch.deletions.map(\.name.string))
            state.pending.removeAll { names.contains($0.name) }
            moved += batch.saves.count + batch.deletions.count
            await delegate?.handle(.sentRecords(sent), from: id)
        }
        await reportState()
    }

    /// The account changed under the engine: it starts again from nothing, unsent changes included, and says so.
    func accountChanged(_ change: AccountChange) async {
        state = State()
        await delegate?.handle(.accountChange(change), from: id)
        await reportState()
    }

    private func reportState() async {
        guard let data = try? JSONEncoder().encode(state) else { return }
        await delegate?.handle(.stateUpdate(data), from: id)
    }
}
