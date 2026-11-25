import Application
import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// A build with no iCloud trims the saga store's history at launch (ADR-0081, ADR-0065 §2). On a store on disk.
@Suite("Sync with no iCloud", .serialized)
struct NoCloudFamilySyncTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-no-cloud-" + UUID().uuidString)
    var storeURL: URL { directory.appending(path: "DadSaga.store") }
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)

    @Test("Given a saga whose history holds an entry's deletion, when resuming, then the history is empty and every row stays")
    func resumeTrimsTheHistory() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalStore.live(in: directory)
        try await store.profiles.create(PlayerProfile(
            children: [lena, nikos], heroClassID: "h-cool",
            dadAppearance: DadAppearance(hair: .curly, hairColor: .black, beard: .none, glasses: .none)
        ))
        let kept = ProgressEvent(kind: .quest(id: "q1"), childID: lena.id, date: .now, note: "πρώτο")
        let deleted = ProgressEvent(kind: .quest(id: "q2"), childID: nikos.id, date: .now, note: nil)
        try await store.progress.add(kept)
        try await store.progress.add(deleted)
        try await store.progress.delete(id: deleted.id)
        #expect(try storeHistory(at: storeURL).contains { $0.contains(.delete(ProgressEventRecord.self)) })
        let sync = NoCloudFamilySync(store: store)

        await sync.resume()

        #expect(try storeHistory(at: storeURL).isEmpty)
        #expect(try storedRowCount(ProfileRecord.self, at: storeURL) == 1)
        #expect(try storedRowCount(ChildRecord.self, at: storeURL) == 2)
        #expect(try storedRowCount(ProgressEventRecord.self, at: storeURL) == 1)
        // The store opens again with the saga whole, and goes on keeping a history.
        let reopened = LocalStore.live(in: directory)
        #expect(try await reopened.profiles.fetchProfile()?.children.map(\.id) == [lena.id, nikos.id])
        #expect(try await reopened.progress.fetchEvents().map(\.id) == [kept.id])
        try await store.profiles.save(HeroEdit(beard: .full))
        #expect(try storeHistory(at: storeURL).count == 1)
        // Nothing of sync was made beside it (ADR-0067 §3).
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).allSatisfy { $0.hasPrefix("DadSaga.store") })
        #expect(await sync.status() == ShareStatus(sharing: .off))
    }

    @Test("Given a store file that can't be opened, when resuming, then it returns and the file is as it was")
    func resumeLeavesAStoreItCannotOpen() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let junk = Data(repeating: 0x42, count: 4096)
        try junk.write(to: storeURL)

        await NoCloudFamilySync(store: LocalStore.live(in: directory)).resume()

        #expect(try Data(contentsOf: storeURL) == junk)
    }
}
