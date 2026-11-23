import Foundation
import SwiftData
import Testing
@testable import Data

/// `Sync.store`'s ledger (ADR-0065 §2, §5): what waits to be sent, merged change by change, and when a sent change
/// leaves. On a store on disk.
@Suite("Sync.store's ledger", .serialized)
struct SyncLedgerTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-ledger-" + UUID().uuidString)
    let child = RecordName.child(UUID())
    let entry = RecordName.entry(UUID())
    let hero = RecordName.hero(UUID())

    func ledger() async throws -> SyncLedger {
        let directory = directory
        return try #require(try await SyncStoreConnection(directory: { directory }).open(creating: true))
    }

    /// `name` as an engine reports it saved, with system fields.
    func saved(_ name: RecordName, tag: UInt8 = 1) -> SyncRecord {
        SyncRecord(name: name, zone: .personal, systemFields: Data([tag]))
    }

    @Test("Given iCloud never turned on, when sync asks where it stands, then no file; turning on creates it by the saga's store")
    func noFileUntilCreated() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalStore.live(in: directory)
        _ = try await store.profiles.fetchProfile()
        let directory = directory
        let connection = SyncStoreConnection(directory: { directory })

        #expect(try await connection.open(creating: false) == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).allSatisfy { $0.hasPrefix("DadSaga.store") })

        #expect(try await connection.open(creating: true) != nil)
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "Sync.store").path))
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "DadSaga.store").path))
        // Open again, and after a relaunch: the same store, with no need to create.
        #expect(try await connection.open(creating: false) != nil)
        #expect(try await SyncStoreConnection(directory: { directory }).open(creating: false) != nil)
    }

    @Test("Given a new ledger, when read, then nothing waits, no token and no child gone")
    func aNewLedgerIsEmpty() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()

        #expect(try await ledger.settings() == SyncSettings(historyToken: nil, resendAfterFetch: false))
        #expect(try await ledger.pending().isEmpty)
        #expect(try await ledger.goneIDs().isEmpty)
    }

    @Test("Given a save waiting, when another save of the record comes, then its fields are added and the revision grows")
    func saveAfterSaveAddsFields() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()

        try await ledger.record([.save(child, fields: ["name"])], through: nil)
        try await ledger.record([.save(child, fields: ["skinTone", "name"]), .save(hero, fields: nil)], through: nil)
        try await ledger.record([.save(hero, fields: ["beard"])], through: nil)

        #expect(try await ledger.pending() == [
            PendingChange(name: child, isDeletion: false, fields: ["name", "skinTone"], revision: 2, behindFetch: false),
            // Every field stays every field.
            PendingChange(name: hero, isDeletion: false, fields: nil, revision: 2, behindFetch: false)
        ])
    }

    @Test("Given a sent record with a save waiting, when it is deleted, then the deletion replaces the save")
    func deletionReplacesASave() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()
        try await ledger.store(systemFields: [saved(entry)])

        try await ledger.record([.save(entry, fields: ["note"]), .delete(entry)], through: nil)

        #expect(try await ledger.pending() == [
            PendingChange(name: entry, isDeletion: true, fields: [], revision: 2, behindFetch: false)
        ])
    }

    @Test("Given a deletion waiting, when the record is saved again, then a save of every field")
    func saveAfterDeletionIsWhole() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()
        let wardrobe = RecordName.wardrobe(skill: "care")
        try await ledger.store(systemFields: [saved(wardrobe)])

        try await ledger.record([.delete(wardrobe)], through: nil)
        try await ledger.record([.save(wardrobe, fields: ["choice"])], through: nil)

        #expect(try await ledger.pending() == [
            PendingChange(name: wardrobe, isDeletion: false, fields: nil, revision: 2, behindFetch: false)
        ])
    }

    @Test("Given a record never sent, when it is saved and then deleted, then nothing waits; in one read or in two")
    func aNeverSentPairLeavesNothing() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()

        try await ledger.record([.save(entry, fields: nil), .save(entry, fields: ["note"]), .delete(entry)], through: nil)
        #expect(try await ledger.pending().isEmpty)

        try await ledger.record([.save(entry, fields: nil)], through: nil)
        try await ledger.record([.delete(entry)], through: nil)
        #expect(try await ledger.pending().isEmpty)

        // The same read again, as after a kill before the history was deleted: still nothing.
        try await ledger.record([.save(entry, fields: nil), .delete(entry)], through: nil)
        #expect(try await ledger.pending().isEmpty)
    }

    @Test("Given a slot never sent, when it is set, cleared and set again in one read, then one save of every field waits")
    func setClearedAndSetAgain() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()
        let wardrobe = RecordName.wardrobe(skill: "care")

        try await ledger.record(
            [.save(hero, fields: ["beard"]), .save(wardrobe, fields: nil), .delete(wardrobe), .save(wardrobe, fields: nil)],
            through: nil
        )

        #expect(try await ledger.pending() == [
            PendingChange(name: hero, isDeletion: false, fields: ["beard"], revision: 1, behindFetch: false),
            PendingChange(name: wardrobe, isDeletion: false, fields: nil, revision: 1, behindFetch: false)
        ])
    }

    @Test("Given a deletion of a record with nothing waiting, then it waits: the server may hold it")
    func aDeletionAloneWaits() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()

        try await ledger.record([.delete(entry)], through: nil)

        #expect(try await ledger.pending() == [
            PendingChange(name: entry, isDeletion: true, fields: [], revision: 1, behindFetch: false)
        ])
    }

    @Test("Given a batch out, when the record changes again before it is sent, then the change stays; at its revision, it goes")
    func aChangeMergedWhileABatchIsOutStays() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()
        try await ledger.record([.save(child, fields: ["name"]), .save(hero, fields: ["beard"])], through: nil)
        let batch = Dictionary(uniqueKeysWithValues: try await ledger.pending().map { ($0.name, $0.revision) })

        try await ledger.record([.save(child, fields: ["skinTone"])], through: nil)
        try await ledger.sent(saved: [saved(child), saved(hero)], revisions: batch, deleted: [])

        #expect(try await ledger.pending() == [
            PendingChange(name: child, isDeletion: false, fields: ["name", "skinTone"], revision: 2, behindFetch: false)
        ])
        // Both are on the server now.
        #expect(try await ledger.systemFields(of: child) == Data([1]))
        #expect(try await ledger.systemFields(of: hero) == Data([1]))

        try await ledger.sent(saved: [saved(child, tag: 2)], revisions: [child: 2], deleted: [])
        #expect(try await ledger.pending().isEmpty)
        #expect(try await ledger.systemFields(of: child) == Data([2]))
    }

    @Test("Given a batch out with a save, when the record is deleted meanwhile, then the deletion waits with the system fields")
    func aDeletionWhileItsSaveIsOutWaits() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()
        try await ledger.store(systemFields: [saved(entry)])
        try await ledger.record([.save(entry, fields: ["note"])], through: nil)

        try await ledger.record([.delete(entry)], through: nil)
        try await ledger.sent(saved: [saved(entry, tag: 2)], revisions: [entry: 1], deleted: [])

        #expect(try await ledger.pending().map(\.isDeletion) == [true])
        #expect(try await ledger.systemFields(of: entry) == Data([2]))
    }

    @Test("Given a deletion sent, then it and the system fields go; saved again meanwhile, the save stays, to go as new")
    func aSentDeletion() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()
        let wardrobe = RecordName.wardrobe(skill: "care")
        try await ledger.store(systemFields: [saved(entry), saved(wardrobe)])
        try await ledger.record([.delete(entry), .delete(wardrobe)], through: nil)

        try await ledger.record([.save(wardrobe, fields: nil)], through: nil)
        try await ledger.sent(saved: [], revisions: [:], deleted: [entry, wardrobe])

        #expect(try await ledger.pending() == [
            PendingChange(name: wardrobe, isDeletion: false, fields: nil, revision: 2, behindFetch: false)
        ])
        #expect(try await ledger.systemFields(of: entry) == nil)
        #expect(try await ledger.systemFields(of: wardrobe) == nil)
    }

    @Test("Given a child deleted for good, when recorded, then their whole record waits and their id is kept, once")
    func goneIsASaveOfEveryFieldAndTheIDKept() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()
        let id = try #require(child.uuid)
        let learned = UUID()

        try await ledger.record([.save(child, fields: ["isRemoved"]), .gone(childID: id)], through: nil)
        try await ledger.record([.gone(childID: id)], through: nil)
        try await ledger.addGone([learned, id, learned])

        #expect(try await ledger.pending() == [
            PendingChange(name: child, isDeletion: false, fields: nil, revision: 3, behindFetch: false)
        ])
        #expect(try await ledger.goneIDs() == [id, learned])
    }

    @Test("Given changes waiting in both zones, when read, then in the order first made, and by zone")
    func pendingInOrderAndByScope() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()

        try await ledger.record([.save(hero, fields: ["beard"]), .save(entry, fields: nil)], through: nil)
        try await ledger.record([.save(child, fields: ["name"]), .save(hero, fields: ["hair"])], through: nil)

        #expect(try await ledger.pending().map(\.name) == [hero, entry, child])
        #expect(try await ledger.pending(.personal).map(\.name) == [hero])
        #expect(try await ledger.pending(.family).map(\.name) == [entry, child])
    }

    @Test("Given changes waiting, when a record arrives, then its waiting fields: all of them for a whole save or a deletion")
    func waitingFields() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()
        let wardrobe = RecordName.wardrobe(skill: "care")
        let other = RecordName.child(UUID())
        try await ledger.record(
            [.save(child, fields: ["name", "order"]), .save(entry, fields: nil), .delete(wardrobe)], through: nil
        )

        let waiting = try await ledger.waitingFields(for: [child, entry, wardrobe, other])

        #expect(waiting == [child: ["name", "order"], entry: SyncField.Entry.all, wardrobe: ["choice"]])
    }

    @Test("Given changes recorded with a token, when the ledger is opened again, then the token and what waits are there")
    func theTokenIsKeptWithWhatWaits() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await FeedBench(in: directory)
        _ = try await bench.store.outfit.setChoice(.hidden, for: .care)
        let token = try #require(try await bench.feed.latestToken())

        try await bench.ledger.record([.save(hero, fields: ["beard"])], through: token)

        let directory = directory
        let reopened = try #require(try await SyncStoreConnection(directory: { directory }).open(creating: false))
        #expect(try await reopened.settings().historyToken == token)
        #expect(try await reopened.pending().map(\.name) == [hero])
    }

    @Test("Given a stored token that no longer reads, when the settings are read, then no token: read from the start")
    func anUnreadableTokenReadsAsNone() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()
        try await ledger.record([], through: nil)
        let container = try ModelContainer(
            for: SyncStoreConnection.schema,
            configurations: ModelConfiguration(
                schema: SyncStoreConnection.schema, url: directory.appending(path: "Sync.store"), cloudKitDatabase: .none
            )
        )
        let context = ModelContext(container)
        let row = try #require(try context.fetch(FetchDescriptor<SyncSettingsRecord>()).first)
        row.historyToken = Data("not a token".utf8)
        try context.save()

        let directory = directory
        let reopened = try #require(try await SyncStoreConnection(directory: { directory }).open(creating: false))
        #expect(try await reopened.settings().historyToken == nil)
    }
}
