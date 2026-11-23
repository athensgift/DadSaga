import Application
import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// Records that sync fetched, written into the saga store (ADR-0065 §2, §4): only the fields that came and differ,
/// none whose local change waits, in one save under `sync` that the change feed never reads back. On a store on disk,
/// read through the real repositories.
@Suite("Records that came, into the saga store", .serialized)
struct SyncApplierTests: FeedSuite {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-applier-" + UUID().uuidString)
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    /// A late id, so a child that comes at his order with an early one reads before him.
    let nikos = Child(
        id: UUID(uuid: (0xF0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 0x01)), name: "Νίκος", birthDay: nil
    )

    @Test("Given a tone change waiting, when a rename and a tone come, then both edits stand, in one save under sync")
    func aFetchedRenameKeepsAWaitingTone() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        var toned = lena
        toned.skinTone = .dark
        try await bench.store.profiles.save(FamilyEdit(changed: [ChildEdit(child: toned, fields: [.skinTone])]))
        try await bench.drain()
        let before = try storeHistory(at: bench.storeURL).count

        let applied = try await bench.apply([
            bench.record(.child(lena.id), ["name": .string("Ελένη"), "skinTone": .string("mediumDark")])
        ])

        let child = try #require(try await bench.store.profiles.fetchProfile()?.children.first)
        #expect(child.name == "Ελένη")
        #expect(child.skinTone == .dark)
        #expect(applied.changedSomething)
        #expect(Array(try storeHistory(at: bench.storeURL).dropFirst(before)) == [
            [.update(ChildRecord.self, [\ChildRecord.name])]
        ])
        #expect(try storeAuthors(at: bench.storeURL).last == "sync")
        // What came is never read back as the dad's change.
        #expect(try await bench.drain().isEmpty)
    }

    @Test("Given a rename the feed hasn't read yet, when another name comes, then the dad's stays and still goes out")
    func aWriteNotYetReadAlsoWaits() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        var renamed = lena
        renamed.name = "Ελένη"
        try await bench.store.profiles.save(FamilyEdit(changed: [ChildEdit(child: renamed, fields: [.name])]))

        try await bench.apply([bench.record(.child(lena.id), ["name": .string("Λενιώ"), "gender": .string("boy")])])

        let child = try #require(try await bench.store.profiles.fetchProfile()?.children.first)
        #expect(child.name == "Ελένη")
        #expect(child.gender == .boy)
        #expect(try await bench.drain() == [.save(.child(lena.id), fields: ["name"])])
    }

    @Test("Given a child at an order already used, when read, then by order and then by id, in the family and in a copy")
    func twoChildrenAtOneOrder() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let iris = Child(
            id: UUID(uuid: (0x01, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 0x01)), name: "Ίρις",
            birthDay: .day(2026, 1, 9), gender: .girl
        )
        let zoe = Child(id: UUID(uuid: (0xF1, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 0x01)), name: "Ζωή", birthDay: nil)

        // Both parents added a child offline, each after the last one they knew: Νίκος's order.
        try await bench.apply([bench.record(of: zoe, order: 1), bench.record(of: iris, order: 1)])

        #expect(try await bench.store.profiles.fetchProfile()?.children == [lena, iris, nikos, zoe])
        #expect(try await bench.store.wholeSaga.readAll()?.profile.children == [lena, iris, nikos, zoe])
        #expect(try storedChildOrders(at: bench.storeURL) == ["Λένα": 0, "Νίκος": 1, "Ίρις": 1, "Ζωή": 1])
    }

    @Test("Given a child's record without what a row needs, then no row; a removed child comes removed, and comes back")
    func childrenThatCome() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let iris = Child(name: "Ίρις", birthDay: nil)

        try await bench.apply([bench.record(.child(iris.id), ["name": .string("Ίρις"), "order": .int(2)])])
        #expect(try await bench.stored(.child(iris.id)).isEmpty)

        try await bench.apply([bench.record(of: iris, order: 2, isRemoved: true)])
        #expect(try await bench.store.profiles.fetchProfile()?.children == [lena, nikos])
        #expect(try await bench.store.profiles.fetchProfile()?.removedChildren == [iris])

        try await bench.apply([bench.record(.child(iris.id), ["isRemoved": .bool(false), "birthDay": .string("2026-01-09")])])
        var born = iris
        born.birthDay = .day(2026, 1, 9)
        #expect(try await bench.store.profiles.fetchProfile()?.children == [lena, nikos, born])
    }

    @Test("Given an entry that comes before its child, then it is stored, and joins the timeline when the child comes")
    func anEntryBeforeItsChild() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let iris = Child(name: "Ίρις", birthDay: nil)
        let recorded = partnersEntry(with: iris, photoIDs: ["a"])
        let timeline = DefaultGetTimelineUseCase(
            contentRepository: FixedContent(catalog: .titlesAndAQuest), wholeSaga: bench.store.wholeSaga
        )

        try await bench.apply([bench.record(of: recorded)])

        #expect(try await bench.store.progress.fetchEvents() == [recorded])
        #expect(try await timeline.execute().isEmpty)

        try await bench.apply([bench.record(of: iris, order: 2)])

        #expect(try await timeline.execute().map(\.id) == [recorded.id])
    }

    @Test("Given an entry, when its note and photos come changed, then only those; one without its date is no row")
    func entriesThatCome() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let recorded = partnersEntry(with: lena, photoIDs: ["a"])
        var incomplete = bench.record(of: partnersEntry(with: lena))
        incomplete.fields["date"] = nil
        try await bench.apply([bench.record(of: recorded), incomplete])
        let before = try storeHistory(at: bench.storeURL).count

        try await bench.apply([bench.record(
            .entry(recorded.id), ["note": .string("μαζί"), "photoIDs": .strings(["b", "a"]), "kind": .string("quest")]
        )])

        let edited = ProgressEvent(
            id: recorded.id, authorID: .partner, kind: recorded.kind, childID: lena.id, date: recorded.date, note: "μαζί",
            photoIDs: ["b", "a"]
        )
        #expect(try await bench.store.progress.fetchEvents() == [edited])
        #expect(Array(try storeHistory(at: bench.storeURL).dropFirst(before)) == [
            [.update(ProgressEventRecord.self, [\ProgressEventRecord.note, \ProgressEventRecord.photoIDs])]
        ])
    }

    @Test("Given values this version doesn't know, when they come, then each is stored as it came")
    func unknownValuesAreStoredAsTheyCame() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let ritual = bench.record(.entry(UUID()), [
            "author": .string(UUID.partner.uuidString), "childID": .string(lena.id.uuidString), "kind": .string("ritual"),
            "contentID": .string("r-bedtime"), "date": .date(Date(timeIntervalSinceReferenceDate: 800_000_000)),
            "photoIDs": .strings(["a"])
        ])
        let records = [
            bench.record(.child(lena.id), ["gender": .string("a-newer-gender"), "skinTone": .string("a-newer-tone")]),
            bench.record(.hero(.testDad), ["beard": .string("braided"), "classID": .string("h-newer")]),
            bench.record(.wardrobe(skill: "care"), ["choice": .string("aura:gold")]),
            bench.record(.wardrobe(skill: "a-newer-skill"), ["choice": .string("hidden")]),
            ritual
        ]

        try await bench.apply(records)

        let stored = try await bench.stored(
            .child(lena.id), .hero(.testDad), .wardrobe(skill: "care"), .wardrobe(skill: "a-newer-skill"), ritual.name
        )
        for (record, row) in zip(records, stored) {
            #expect(row.fields.filter { record.fields[$0.key] != nil } == record.fields)
        }
        #expect(stored.count == records.count)
        // What this version can't show, it still reads around: the family, the entries it knows, every photo named.
        #expect(try await bench.store.profiles.fetchProfile()?.children.map(\.name) == ["Λένα", "Νίκος"])
        #expect(try await bench.store.progress.fetchEvents().isEmpty)
        #expect(try await bench.store.progress.referencedPhotoIDs() == ["a"])
        #expect(try await bench.store.outfit.fetchOutfit() == Outfit())
    }

    @Test("Given rows as the zone holds them, when the same records come, then nothing is written")
    func equalValuesWriteNoTransaction() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let recorded = entry(with: lena, photoIDs: ["a"])
        try await bench.store.progress.add(recorded)
        _ = try await bench.store.outfit.setChoice(.hidden, for: .care)
        try await bench.store.standing.keep(titleID: "t1", catalog: .threeTitles)
        try await bench.drain()
        try await bench.markEverythingSent()
        let rows = try await bench.stored(
            .hero(.testDad), .child(lena.id), .child(nikos.id), .entry(recorded.id), .wardrobe(skill: "care")
        )
        let before = try storeHistory(at: bench.storeURL).count

        let applied = try await bench.apply(rows)

        #expect(rows.count == 5)
        #expect(applied == Applied())
        #expect(try storeHistory(at: bench.storeURL).count == before)
    }

    @Test("Given a wardrobe slot, when a choice comes it is set, another replaces it, and its deletion makes it automatic")
    func wardrobeSlotsThatCome() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let care = RecordName.wardrobe(skill: "care")

        try await bench.apply([bench.record(care, ["choice": .string("hidden")])])
        #expect(try await bench.store.outfit.fetchOutfit() == Outfit(choices: [.care: .hidden]))

        try await bench.apply([bench.record(care, ["choice": .string("item:g-mug")])])
        #expect(try await bench.store.outfit.fetchOutfit() == Outfit(choices: [.care: .item("g-mug")]))

        let applied = try await bench.apply(deleting: [care, .wardrobe(skill: "play")])
        #expect(try await bench.store.outfit.fetchOutfit() == Outfit())
        #expect(applied.changedSomething)
        #expect(try await bench.drain().isEmpty)
    }

    @Test("Given another parent's hero, or a hero's deletion, when it comes, then this iPhone's hero is as it was")
    func onlyThisParentsHero() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await synced()
        let before = try await bench.store.wholeSaga.readAll()

        let applied = try await bench.apply(
            [bench.record(.hero(.partner), ["beard": .string("full"), "heldTitleID": .string("t2")])],
            deleting: [.hero(.testDad)]
        )

        #expect(applied == Applied())
        #expect(try await bench.store.wholeSaga.readAll() == before)
        #expect(try await bench.stored(.hero(.partner)).isEmpty)

        try await bench.apply([bench.record(.hero(.testDad), ["beard": .string("full"), "hasPartner": .bool(false)])])
        let profile = try #require(try await bench.store.profiles.fetchProfile())
        #expect(profile.dadAppearance.beard == .full)
        #expect(!profile.hasPartner)
    }
}
