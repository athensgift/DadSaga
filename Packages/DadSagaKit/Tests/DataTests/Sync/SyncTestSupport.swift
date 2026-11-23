import Application
import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// A saga store on disk with its change feed, and `Sync.store` beside it (ADR-0065 §2, §5).
struct FeedBench {
    let directory: URL
    let store: LocalStore
    let feed: StoreChangeFeed
    let applier: SwiftDataSyncApplier
    let ledger: SyncLedger
    /// The zones a test's records are in: Personal, and one family zone.
    let zones = SyncZones(family: .family(UUID(), owner: "_owner"))

    var storeURL: URL { directory.appending(path: "DadSaga.store") }
    var syncStoreURL: URL { directory.appending(path: SyncStoreConnection.fileName) }

    init(in directory: URL) async throws {
        self.directory = directory
        store = LocalStore.live(in: directory)
        let opened = try await store.connection.open()
        feed = opened.feed
        applier = opened.applier
        ledger = try #require(try await SyncStoreConnection(directory: { directory }).open(creating: true))
    }

    /// One drain, as sync does it (ADR-0065 §2): the history after the ledger's token, recorded with the new token in
    /// one save, then the history before that token deleted. Returns what was read.
    @discardableResult
    func drain() async throws -> [LocalChange] {
        let read = try await feed.read(after: try await ledger.settings().historyToken)
        guard case .changes(let changes, let token) = read else {
            Issue.record("The history token expired")
            return []
        }
        try await ledger.record(changes, through: token)
        if let token { try await feed.deleteHistory(before: token) }
        return changes
    }

    /// Everything that waits, reported sent, as an engine does once the zone holds it: nothing waits afterwards.
    func markEverythingSent() async throws {
        let pending = try await ledger.pending()
        try await ledger.sent(
            saved: pending.filter { !$0.isDeletion }.map {
                SyncRecord(name: $0.name, zone: zones.zone(for: $0.name.type), systemFields: Data([1]))
            },
            revisions: Dictionary(pending.map { ($0.name, $0.revision) }, uniquingKeysWith: { first, _ in first }),
            deleted: pending.filter(\.isDeletion).map(\.name)
        )
    }

    /// Applies what a fetch brought, as sync does (ADR-0065 §2): told what waits in the ledger for those records, the
    /// token the history was last read through, and the children the ledger knows as gone.
    @discardableResult
    func apply(
        _ records: [SyncRecord] = [], deleting deletions: [RecordName] = [], catalog: ContentCatalog = .threeTitles
    ) async throws -> Applied {
        let context = ApplyContext(
            waiting: try await ledger.waitingFields(for: Set(records.map(\.name) + deletions)),
            historyToken: try await ledger.settings().historyToken,
            gone: try await ledger.goneIDs(),
            catalog: catalog
        )
        return try await applier.apply(FetchedBatch(records: records, deletions: deletions), context)
    }

    /// A record as another iPhone sends it: `fields` of `name`, in its zone.
    func record(_ name: RecordName, _ fields: [String: SyncValue]) -> SyncRecord {
        SyncRecord(name: name, zone: zones.zone(for: name.type), fields: fields)
    }

    /// A child's whole record.
    func record(of child: Child, order: Int, isRemoved: Bool = false) -> SyncRecord {
        ChildRecord(child: child, order: order, isRemoved: isRemoved).syncRecord(fields: nil, zones: zones)
    }

    /// An entry's whole record.
    func record(of event: ProgressEvent) -> SyncRecord {
        ProgressEventRecord(event: event).syncRecord(fields: nil, zones: zones)
    }

    /// The rows' records now, whole.
    func stored(_ names: RecordName...) async throws -> [SyncRecord] {
        try await feed.records(names.map { ($0, nil) }, zones: zones, gone: [])
    }

    /// `Sync.store` opened again so that it can't be written: every save of this ledger throws.
    func unwritableLedger() throws -> SyncLedger {
        SyncLedger(modelContainer: try ModelContainer(
            for: SyncStoreConnection.schema,
            configurations: ModelConfiguration(
                schema: SyncStoreConnection.schema, url: syncStoreURL, allowsSave: false, cloudKitDatabase: .none
            )
        ))
    }
}

/// A suite on a `FeedBench`: a family of two and their entries.
protocol FeedSuite {
    var directory: URL { get }
    var lena: Child { get }
    var nikos: Child { get }
}

extension FeedSuite {
    /// The dad, Λένα and Νίκος, with onboarding's own changes already drained.
    func onboarded() async throws -> FeedBench {
        let bench = try await FeedBench(in: directory)
        try await bench.store.profiles.create(PlayerProfile(
            children: [lena, nikos], heroClassID: "h-cool",
            dadAppearance: DadAppearance(hair: .curly, hairColor: .black, beard: .none, glasses: .none)
        ))
        try await bench.drain()
        return bench
    }

    /// `onboarded`, with the zone already holding all of it: nothing waits to be sent.
    func synced() async throws -> FeedBench {
        let bench = try await onboarded()
        try await bench.markEverythingSent()
        return bench
    }

    func entry(with child: Child, photoIDs: [String] = []) -> ProgressEvent {
        ProgressEvent(kind: .quest(id: "q1"), childID: child.id, date: .now, note: "πρώτο", photoIDs: photoIDs)
    }

    /// The other parent's entry: the family's, never the test dad's.
    func partnersEntry(with child: Child, photoIDs: [String] = []) -> ProgressEvent {
        ProgressEvent(
            id: UUID(), authorID: .partner, kind: .quest(id: "q1"), childID: child.id, date: .now, note: nil,
            photoIDs: photoIDs
        )
    }
}

extension ContentCatalog {
    /// `threeTitles`, and the quest `q1` worth 20 XP: one entry of it reaches `t1`, two reach `t2`.
    static let titlesAndAQuest = ContentCatalog(
        worlds: [],
        quests: [Quest(
            id: "q1", worldID: "w1", title: LocalizedText(el: "x", en: "x"), description: LocalizedText(el: "x", en: "x"),
            skill: .care, xp: 20, minAgeMonths: 0
        )],
        bosses: [], firsts: [], titles: ContentCatalog.threeTitles.titles
    )
}

/// Content that is one catalog, for use cases a test runs on a small one.
struct FixedContent: ContentRepository {
    let catalog: ContentCatalog

    func fetchCatalog() async throws -> ContentCatalog { catalog }
}

/// Whether `stream` gives an element within `seconds`. The stream ends with the wait.
func yields(_ stream: AsyncStream<Void>, within seconds: Double) async -> Bool {
    await withTaskGroup(of: Bool.self) { group in
        group.addTask {
            var iterator = stream.makeAsyncIterator()
            return await iterator.next() != nil
        }
        group.addTask {
            try? await Task.sleep(for: .seconds(seconds))
            return false
        }
        let first = await group.next() ?? false
        group.cancelAll()
        return first
    }
}
