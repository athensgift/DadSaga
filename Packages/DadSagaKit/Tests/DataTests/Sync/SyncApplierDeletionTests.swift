import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// Rows that go because sync fetched it (ADR-0065 §4): an entry's deletion, a child's `gone` marker. Before this
/// parent's own entries go, their title is kept, so it never goes down (ADR-0055 §3, ADR-0006); the family is never
/// left without a child; and a child leaves only by the marker. On a store on disk.
@Suite("Deletions that came, into the saga store", .serialized)
struct SyncApplierDeletionTests: FeedSuite {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-applier-" + UUID().uuidString)
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)
    let catalog = ContentCatalog.titlesAndAQuest

    /// The title the dad holds now, as home works it out: the higher of what his entries reach and what is kept.
    func heldTitle(on bench: FeedBench) async throws -> String? {
        let profile = try #require(try await bench.store.profiles.fetchProfile())
        return DadStanding(
            progress: DadProgress(of: profile, events: try await bench.store.progress.fetchEvents(), catalog: catalog),
            catalog: catalog, kept: try await bench.store.standing.fetchKept()
        ).title?.id
    }

    @Test("Given the partner's entries, when one's deletion comes, then it goes with the photos no other entry lists")
    func aPartnersEntryGoesWithItsPhotos() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let first = partnersEntry(with: lena, photoIDs: ["a", "shared"])
        let second = partnersEntry(with: lena, photoIDs: ["shared"])
        try await bench.apply([bench.record(of: first), bench.record(of: second)])
        let before = try storeHistory(at: bench.storeURL).count

        let applied = try await bench.apply(deleting: [.entry(first.id), .entry(UUID())], catalog: catalog)

        #expect(applied == Applied(photosToDelete: ["a"], changedSomething: true))
        #expect(try await bench.store.progress.fetchEvents() == [second])
        // Not this parent's entry: nothing is kept for it, and the one save is sync's.
        #expect(try await bench.store.standing.fetchKept() == KeptStanding())
        #expect(Array(try storeHistory(at: bench.storeURL).dropFirst(before)) == [[.delete(ProgressEventRecord.self)]])
        #expect(try storeAuthors(at: bench.storeURL).last == "sync")
        #expect(try await bench.drain().isEmpty)
    }

    @Test("Given two entries of the dad's, when one's deletion comes, then his title is kept first, in a save the feed sends")
    func anOwnEntryDeletedKeepsTheTitleFirst() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let (first, second) = (entry(with: lena), entry(with: nikos))
        try await bench.store.progress.add(first)
        try await bench.store.progress.add(second)
        try await bench.drain()
        try await bench.markEverythingSent()
        let before = try storeHistory(at: bench.storeURL).count
        #expect(try await heldTitle(on: bench) == "t2")

        let applied = try await bench.apply(deleting: [.entry(second.id)], catalog: catalog)

        #expect(applied.changedSomething)
        #expect(try await bench.store.progress.fetchEvents() == [first])
        #expect(try await bench.store.standing.fetchKept().titleID == "t2")
        #expect(try await heldTitle(on: bench) == "t2")
        // The title in a save of the dad's own, then the deletion under sync.
        #expect(Array(try storeHistory(at: bench.storeURL).dropFirst(before)) == [
            [.update(ProfileRecord.self, [\ProfileRecord.heldTitleID])], [.delete(ProgressEventRecord.self)]
        ])
        #expect(try storeAuthors(at: bench.storeURL).suffix(2) == [nil, "sync"])
        #expect(try await bench.drain() == [.save(.hero(.testDad), fields: ["heldTitleID"])])
    }

    @Test("Given a higher title already kept, when an own entry's deletion comes, then nothing more is kept")
    func aTitleAlreadyKeptIsNotWrittenAgain() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let recorded = entry(with: lena)
        try await bench.store.progress.add(recorded)
        try await bench.store.standing.keep(titleID: "t2", catalog: catalog)
        try await bench.drain()
        let before = try storeHistory(at: bench.storeURL).count

        try await bench.apply(deleting: [.entry(recorded.id)], catalog: catalog)

        #expect(try await heldTitle(on: bench) == "t2")
        #expect(Array(try storeHistory(at: bench.storeURL).dropFirst(before)) == [[.delete(ProgressEventRecord.self)]])
    }

    @Test("Given a child whose marker comes, then the child, every entry with them and their photos go, the dad's title kept")
    func aGoneChildTakesEveryEntry() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let (own, others) = (entry(with: lena, photoIDs: ["a"]), entry(with: nikos, photoIDs: ["c"]))
        let partners = partnersEntry(with: lena, photoIDs: ["b"])
        try await bench.store.progress.add(own)
        try await bench.store.progress.add(others)
        try await bench.drain()
        try await bench.markEverythingSent()
        try await bench.apply([bench.record(of: partners)])
        #expect(try await heldTitle(on: bench) == "t2")

        let applied = try await bench.apply([ChildRecord.goneRecord(childID: lena.id, zones: bench.zones)], catalog: catalog)

        #expect(applied.goneLearned == [lena.id])
        #expect(Set(applied.photosToDelete) == ["a", "b"])
        #expect(applied.resend.isEmpty)
        #expect(applied.changedSomething)
        let saga = try #require(try await bench.store.wholeSaga.readAll())
        #expect(saga.profile.children == [nikos])
        #expect(saga.profile.removedChildren.isEmpty)
        #expect(saga.events == [others])
        #expect(try await heldTitle(on: bench) == "t2")
        // Only the kept title is the dad's change: no row that went is read as his deletion.
        #expect(try await bench.drain() == [.save(.hero(.testDad), fields: ["heldTitleID"])])
    }

    @Test("Given a child known as gone, when a save of them or an entry with them comes, then neither is stored")
    func nothingBringsAGoneChildBack() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let learned = try await bench.apply([ChildRecord.goneRecord(childID: lena.id, zones: bench.zones)]).goneLearned
        try await bench.ledger.addGone(learned)
        let late = partnersEntry(with: lena, photoIDs: ["a", "b"])
        let before = try await bench.store.wholeSaga.readAll()

        // A bring-back that raced the delete for good, and a stale iPhone's late upload.
        let applied = try await bench.apply([bench.record(of: lena, order: 0), bench.record(of: late)])

        // The zone holds their record without the marker: it goes again, with the entry and its photos deleted there.
        #expect(applied == Applied(
            resend: [.gone(childID: lena.id)], deleteFromZone: [.entry(late.id), .photo("a"), .photo("b")]
        ))
        #expect(try await bench.store.wholeSaga.readAll() == before)
        #expect(try await bench.store.profiles.fetchProfile()?.children == [nikos])
    }

    @Test("Given the dad deleted a child for good and the feed hasn't read it, when their record comes, then no row")
    func aChildTheDadJustDeletedStaysGone() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let recorded = entry(with: lena)
        try await bench.store.progress.add(recorded)
        try await bench.drain()
        try await bench.markEverythingSent()
        try await bench.store.profiles.save(FamilyEdit(removedIDs: [lena.id]))
        _ = try await bench.store.profiles.deleteForGood(childID: lena.id)

        let applied = try await bench.apply([bench.record(of: lena, order: 0), bench.record(of: recorded)])

        #expect(applied == Applied(resend: [.gone(childID: lena.id)], deleteFromZone: [.entry(recorded.id)]))
        #expect(try await bench.store.wholeSaga.readAll()?.profile.removedChildren.isEmpty == true)
        #expect(try await bench.store.progress.fetchEvents().isEmpty)
        #expect(try await bench.drain().contains(.gone(childID: lena.id)))
    }

    @Test("Given an entry the dad deleted, its deletion waiting or not yet read, when its record comes, then no row")
    func anEntryWhoseDeletionWaitsIsNotStoredAgain() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let (first, second) = (entry(with: lena), entry(with: nikos))
        try await bench.store.progress.add(first)
        try await bench.store.progress.add(second)
        try await bench.drain()
        try await bench.markEverythingSent()
        try await bench.store.progress.delete(id: first.id)
        try await bench.drain()
        try await bench.store.progress.delete(id: second.id)

        // Another of his iPhones edited both meanwhile.
        let applied = try await bench.apply([bench.record(of: first), bench.record(of: second)])

        #expect(applied == Applied())
        #expect(try await bench.store.progress.fetchEvents().isEmpty)
    }

    @Test("Given a child's or a hero's deletion, when it comes, then nothing goes: a child leaves only by the marker")
    func aChildsDeletionIsIgnored() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        try await bench.store.progress.add(entry(with: lena))
        let before = try await bench.store.wholeSaga.readAll()
        let history = try storeHistory(at: bench.storeURL).count

        let applied = try await bench.apply(
            deleting: [.child(lena.id), .hero(.testDad), .member(.partner), .photo("a"), .saga], catalog: catalog
        )

        #expect(applied == Applied())
        #expect(try await bench.store.wholeSaga.readAll() == before)
        #expect(try storeHistory(at: bench.storeURL).count == history)
    }

    @Test("Given removals that would leave no child, when they come, then the last one is not applied, and is sent again")
    func theLastChildStays() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()

        let both = try await bench.apply([
            bench.record(.child(lena.id), ["isRemoved": .bool(true)]), bench.record(.child(nikos.id), ["isRemoved": .bool(true)])
        ])

        #expect(both.resend == [.save(.child(nikos.id), fields: ["isRemoved"])])
        #expect(try await bench.store.profiles.fetchProfile()?.children == [nikos])
        #expect(try await bench.store.profiles.fetchProfile()?.removedChildren == [lena])

        // The same on another day: the dad's own removal is in the zone, and the partner removed the other child.
        let again = try await bench.apply([
            bench.record(.child(nikos.id), ["isRemoved": .bool(true), "name": .string("Νικόλας")])
        ])

        #expect(again.resend == [.save(.child(nikos.id), fields: ["isRemoved"])])
        #expect(try await bench.store.profiles.fetchProfile()?.children.map(\.name) == ["Νικόλας"])
        #expect(try await bench.drain().isEmpty)
    }

    @Test("Given a marker that takes the family's last child, then the first removed child comes back, and is sent")
    func aMarkerNeverEmptiesTheFamily() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        try await bench.store.profiles.save(FamilyEdit(removedIDs: [lena.id]))
        try await bench.drain()
        try await bench.markEverythingSent()

        let applied = try await bench.apply([ChildRecord.goneRecord(childID: nikos.id, zones: bench.zones)])

        #expect(applied.goneLearned == [nikos.id])
        #expect(applied.resend == [.save(.child(lena.id), fields: ["isRemoved"])])
        #expect(try await bench.store.profiles.fetchProfile()?.children == [lena])
        #expect(try await bench.store.profiles.fetchProfile()?.removedChildren.isEmpty == true)
    }

    @Test("Given a history token that expired, when a batch comes, then nothing is applied and the applier says so")
    func anExpiredTokenAppliesNothing() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let stale = try #require(try await bench.ledger.settings().historyToken)
        try await bench.store.profiles.save(HeroEdit(beard: .full))
        try await bench.drain()
        try await bench.store.profiles.save(HeroEdit(beard: .short))
        let before = try await bench.store.wholeSaga.readAll()
        let context = ApplyContext(waiting: [:], historyToken: stale, gone: [], catalog: catalog)
        let batch = FetchedBatch(records: [bench.record(.child(lena.id), ["name": .string("Ελένη")])])

        await #expect(throws: SyncApplyError.historyTokenExpired) { try await bench.applier.apply(batch, context) }

        #expect(try await bench.store.wholeSaga.readAll() == before)
    }
}
