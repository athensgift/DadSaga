import Application
import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// The applier on the saga store's one queue (ADR-0068): what it writes, every repository reads, and a rule a write
/// keeps holds though a fetch landed between a use case's read and that write: the family is never left without a
/// child, and a kept title never goes down (ADR-0006, ADR-0055 §3). On a store on disk.
@Suite("The applier on the saga store's one queue", .serialized)
struct SyncApplierQueueTests: FeedSuite {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-applier-" + UUID().uuidString)
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)

    @Test("Given every repository has read the saga, when a batch changes each row, then every repository reads the change")
    func everyRepositoryReadsWhatTheApplierWrote() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let recorded = entry(with: lena)
        try await bench.store.progress.add(recorded)
        _ = try await bench.store.outfit.setChoice(.hidden, for: .care)
        try await bench.drain()
        try await bench.markEverythingSent()
        // Every repository loads every row it reads.
        _ = try await bench.store.wholeSaga.readAll()
        _ = try await bench.store.profiles.fetchProfile()
        _ = try await bench.store.progress.fetchEvents()
        _ = try await bench.store.outfit.fetchOutfit()
        _ = try await bench.store.standing.fetchKept()
        let partners = partnersEntry(with: nikos, photoIDs: ["b"])

        try await bench.apply([
            bench.record(.child(lena.id), ["name": .string("Ελένη")]),
            bench.record(.hero(.testDad), ["beard": .string("full"), "heldTitleID": .string("t1"), "seenTitleID": .string("t1")]),
            bench.record(.entry(recorded.id), ["note": .string("άλλο"), "photoIDs": .strings(["a"])]),
            bench.record(.wardrobe(skill: "care"), ["choice": .string("item:g-mug")]),
            bench.record(of: partners)
        ])

        let profile = try #require(try await bench.store.profiles.fetchProfile())
        #expect(profile.children.map(\.name) == ["Ελένη", "Νίκος"])
        #expect(profile.dadAppearance.beard == .full)
        #expect(try await bench.store.progress.fetchEvents().map(\.note) == ["άλλο", nil])
        #expect(try await bench.store.progress.referencedPhotoIDs() == ["a", "b"])
        #expect(try await bench.store.outfit.fetchOutfit() == Outfit(choices: [.care: .item("g-mug")]))
        #expect(try await bench.store.standing.fetchKept() == KeptStanding(titleID: "t1", seenTitleID: "t1"))
        let saga = try #require(try await bench.store.wholeSaga.readAll())
        #expect(saga.profile == profile)
        #expect(saga.events.map(\.id) == [recorded.id, partners.id])
        #expect(saga.kept.titleID == "t1")
        // And what a repository writes next, the applier reads: the same record again changes nothing.
        try await bench.store.profiles.save(HeroEdit(beard: .short))
        try await bench.drain()
        try await bench.markEverythingSent()
        #expect(try await bench.apply([bench.record(.hero(.testDad), ["beard": .string("short")])]) == Applied())
    }

    @Test("Given the dad's edit read two children, when a removal lands before he removes the other, then he is refused")
    func aFetchBeforeARemovalNeverEmptiesTheFamily() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        // "My family" opens on both children.
        #expect(try await bench.store.profiles.fetchProfile()?.children.count == 2)

        try await bench.apply([bench.record(.child(lena.id), ["isRemoved": .bool(true)])])

        await #expect(throws: ProfileValidationError.noChildren) {
            try await bench.store.profiles.save(FamilyEdit(removedIDs: [nikos.id]))
        }
        #expect(try await bench.store.profiles.fetchProfile()?.children == [nikos])
    }

    @Test("Given a deletion read no kept title, when a higher one lands before it keeps a lower, then the higher stays")
    func aFetchBeforeAKeepNeverLowersTheTitle() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        // The deletion's use case reads what is kept, and works out `t1` from the entries.
        #expect(try await bench.store.standing.fetchKept().titleID == nil)

        try await bench.apply([bench.record(.hero(.testDad), ["heldTitleID": .string("t2")])])
        try await bench.store.standing.keep(titleID: "t1", catalog: .threeTitles)

        #expect(try await bench.store.standing.fetchKept().titleID == "t2")
    }

    @Test("Given a kept title, when a lower one comes it stays, when a higher one comes it is taken, whatever waits")
    func aKeptTitleOnlyGoesUp() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        try await bench.store.standing.keep(titleID: "t1", catalog: .threeTitles)
        try await bench.drain()

        // The dad's own keep still waits to be sent: it never holds a higher one back.
        let lower = try await bench.apply([bench.record(.hero(.testDad), ["heldTitleID": .string("t0")])])
        #expect(lower == Applied())
        #expect(try await bench.store.standing.fetchKept().titleID == "t1")

        try await bench.apply([bench.record(.hero(.testDad), ["heldTitleID": .cleared])])
        #expect(try await bench.store.standing.fetchKept().titleID == "t1")

        try await bench.apply([bench.record(.hero(.testDad), ["heldTitleID": .string("t2")])])
        #expect(try await bench.store.standing.fetchKept().titleID == "t2")

        try await bench.apply([bench.record(.hero(.testDad), ["heldTitleID": .string("t-from-a-newer-version")])])
        try await bench.apply([bench.record(.hero(.testDad), ["heldTitleID": .string("t2")])])
        #expect(try await bench.store.standing.fetchKept().titleID == "t-from-a-newer-version")
        // None of it is the dad's change.
        #expect(try await bench.drain().isEmpty)
    }

    @Test("Given a record that comes twice in one batch, then each field's later value is the one stored")
    func aRecordTwiceInABatch() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()

        try await bench.apply([
            bench.record(.child(lena.id), ["name": .string("Ελένη"), "isRemoved": .bool(true)]),
            bench.record(.child(lena.id), ["isRemoved": .bool(false), "gender": .string("boy")])
        ])

        let child = try #require(try await bench.store.profiles.fetchProfile()?.children.first)
        #expect(child.name == "Ελένη")
        #expect(child.gender == .boy)
    }

    @Test("Given a child map, when applied, then the mapped child's row goes, their entries move, and the feed reads nothing")
    func aChildMapMovesEntries() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let familys = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl)
        let (moved, stays) = (entry(with: lena, photoIDs: ["a"]), entry(with: nikos))
        try await bench.store.progress.add(moved)
        try await bench.store.progress.add(stays)
        try await bench.drain()
        try await bench.markEverythingSent()
        let map = ChildMap(familyIDs: [lena.id: familys.id, nikos.id: nikos.id, UUID(): UUID()])
        // The family's child is not here yet: nothing moves, so no child is hidden meanwhile.
        #expect(try await bench.applier.apply(map) == ChildMap())
        #expect(try await bench.store.profiles.fetchProfile()?.children == [lena, nikos])
        try await bench.apply([bench.record(of: familys, order: 0)])
        // An edit the feed hasn't read when the join lands.
        var renamed = lena
        renamed.name = "Ελένη"
        try await bench.store.profiles.save(FamilyEdit(changed: [ChildEdit(child: renamed, fields: [.name])]))
        let before = try storeHistory(at: bench.storeURL).count

        let applied = try await bench.applier.apply(map)

        #expect(applied == ChildMap(familyIDs: [lena.id: familys.id]))
        #expect(try await bench.store.profiles.fetchProfile()?.children == [familys, nikos])
        let events = try await bench.store.progress.fetchEvents()
        #expect(Set(events.map(\.id)) == [moved.id, stays.id])
        #expect(events.first { $0.id == moved.id }?.childID == familys.id)
        #expect(events.first { $0.id == moved.id }?.photoIDs == ["a"])
        #expect(events.first { $0.id == stays.id }?.childID == nikos.id)
        // One save under sync: the row is never read as deleted for good, nor the entry as edited.
        #expect(try storeHistory(at: bench.storeURL).count == before + 1)
        #expect(try storeAuthors(at: bench.storeURL).last == "sync")
        #expect(try await bench.drain().isEmpty)
        #expect(try await bench.ledger.goneIDs().isEmpty)
        // Applied again (a kill before `Sync.store` knew): the same answer, and nothing more moves.
        #expect(try await bench.applier.apply(map) == applied)
        #expect(try await bench.store.progress.fetchEvents().first { $0.id == stays.id }?.childID == nikos.id)
    }

    @Test("Given a child map waiting, when the batch that brings the family's child comes, then both are one save")
    func aWaitingChildMapIsAppliedWithItsBatch() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let familys = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl)
        let moved = entry(with: lena)
        try await bench.store.progress.add(moved)
        try await bench.drain()
        let map = ChildMap(familyIDs: [lena.id: familys.id])
        func apply(_ records: [SyncRecord]) async throws -> Applied {
            try await bench.applier.apply(FetchedBatch(records: records), ApplyContext(
                waiting: [:], historyToken: try await bench.ledger.settings().historyToken, gone: [], catalog: .threeTitles,
                map: map
            ))
        }

        // A batch without the family's child: the map still waits, and the family is as it was.
        #expect(try await apply([bench.record(.child(nikos.id), ["name": .string("Νικόλας")])]).mapped == nil)
        #expect(try await bench.store.profiles.fetchProfile()?.children.map(\.id) == [lena.id, nikos.id])
        let before = try storeHistory(at: bench.storeURL).count

        let applied = try await apply([bench.record(of: familys, order: 0)])

        // Never a save with the child twice, and never one with neither.
        #expect(applied.mapped == map)
        #expect(try storeHistory(at: bench.storeURL).count == before + 1)
        #expect(try await bench.store.profiles.fetchProfile()?.children.map(\.id) == [familys.id, nikos.id])
        #expect(try await bench.store.progress.fetchEvents().map(\.childID) == [familys.id])
        #expect(try await bench.drain().isEmpty)
    }
}
