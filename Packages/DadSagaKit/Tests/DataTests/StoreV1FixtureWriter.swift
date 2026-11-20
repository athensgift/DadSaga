import Foundation
import Testing
@testable import Data

/// Writes `Fixtures/StoreV1` with the version 1 build, once. Run with `DADSAGA_WRITE_STORE_V1=1`.
@Suite("Store V1 fixture writer")
struct StoreV1FixtureWriter {
    @Test("Writes the version 1 fixture", .enabled(if: ProcessInfo.processInfo.environment["DADSAGA_WRITE_STORE_V1"] == "1"))
    func write() async throws {
        let scratch = FileManager.default.temporaryDirectory.appending(path: "dadsaga-store-v1-" + UUID().uuidString)
        let store = LocalStore.live(in: scratch)
        try await store.profiles.save(StoreV1Fixture.profile)
        for event in StoreV1Fixture.events { try await store.progress.add(event) }
        #expect(try await store.progress.fetchEvents() == StoreV1Fixture.events)
        let target = StoreV1Fixture.directory
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        for name in ["DadSaga.store", "DadSaga.store-shm", "DadSaga.store-wal"] {
            let destination = target.appending(path: name)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: scratch.appending(path: name), to: destination)
        }
        withExtendedLifetime(store) {}
    }
}
