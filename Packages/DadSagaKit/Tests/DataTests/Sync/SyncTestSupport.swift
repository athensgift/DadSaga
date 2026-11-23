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
    let ledger: SyncLedger

    var storeURL: URL { directory.appending(path: "DadSaga.store") }
    var syncStoreURL: URL { directory.appending(path: SyncStoreConnection.fileName) }

    init(in directory: URL) async throws {
        self.directory = directory
        store = LocalStore.live(in: directory)
        feed = try await store.connection.open().feed
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

    func entry(with child: Child, photoIDs: [String] = []) -> ProgressEvent {
        ProgressEvent(kind: .quest(id: "q1"), childID: child.id, date: .now, note: "πρώτο", photoIDs: photoIDs)
    }
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
