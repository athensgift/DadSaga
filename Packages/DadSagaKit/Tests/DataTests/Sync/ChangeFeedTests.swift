import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// The saga store's history, read as the record changes sync sends (ADR-0065 §2, §8): each change with only the fields
/// it changed, a deleted row named by the id its tombstone kept, and nothing for a write saved under `sync`. On a store
/// on disk, through the real repositories.
@Suite("The store's history as the changes sync sends", .serialized)
struct ChangeFeedTests: FeedSuite {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-feed-" + UUID().uuidString)
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)

    @Test("Given a new saga, when onboarding saves, then the hero and each child go whole")
    func onboardingSendsEveryRowWhole() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await FeedBench(in: directory)
        try await bench.store.profiles.create(PlayerProfile(children: [lena, nikos], heroClassID: "h-cool"))

        let changes = try await bench.drain()

        #expect(Set(changes) == [
            .save(.hero(.testDad), fields: nil), .save(.child(lena.id), fields: nil), .save(.child(nikos.id), fields: nil)
        ])
    }

    @Test("Given two children, when one is renamed, then that child's record with only its name")
    func aRenameSendsOnlyTheName() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()
        var renamed = lena
        renamed.name = "Ελένη"

        try await bench.store.profiles.save(FamilyEdit(changed: [ChildEdit(child: renamed, fields: [.name])]))

        #expect(try await bench.drain() == [.save(.child(lena.id), fields: ["name"])])
    }

    @Test("Given a child not born, when a birth day is set, and when it moves in the month, then the one field birthDay")
    func aBirthDayIsOneField() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()
        var born = nikos
        born.birthDay = .day(2026, 11, 1)
        var moved = born
        moved.birthDay = .day(2026, 11, 3)

        try await bench.store.profiles.save(FamilyEdit(changed: [ChildEdit(child: born, fields: [.birthDay])]))
        let set = try await bench.drain()
        try await bench.store.profiles.save(FamilyEdit(changed: [ChildEdit(child: moved, fields: [.birthDay])]))
        let move = try await bench.drain()

        #expect(set == [.save(.child(nikos.id), fields: ["birthDay"])])
        #expect(move == [.save(.child(nikos.id), fields: ["birthDay"])])
    }

    @Test("Given a family, when a child is added and an entry recorded, then both go whole, the entry with its photos")
    func insertsSendEveryFieldAndThePhotos() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()
        let iris = Child(name: "Ίρις", birthDay: nil)
        let recorded = entry(with: lena, photoIDs: ["a", "b"])

        try await bench.store.profiles.save(FamilyEdit(added: [iris]))
        try await bench.store.progress.add(recorded)

        #expect(try await bench.drain() == [
            .save(.child(iris.id), fields: nil),
            .save(.entry(recorded.id), fields: nil),
            .entryPhotos(entryID: recorded.id, photoIDs: ["a", "b"])
        ])
    }

    @Test("Given an entry, when its note changes, then only the note; when its photos change, then photoIDs and the photos now")
    func anEntryEditSendsWhatChanged() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()
        let recorded = entry(with: lena, photoIDs: ["a"])
        try await bench.store.progress.add(recorded)
        try await bench.drain()
        func edited(note: String?, photoIDs: [String]) -> ProgressEvent {
            ProgressEvent(
                id: recorded.id, kind: recorded.kind, childID: lena.id, date: recorded.date, note: note, photoIDs: photoIDs
            )
        }

        try await bench.store.progress.update(edited(note: "άλλο", photoIDs: ["a"]))
        let note = try await bench.drain()
        try await bench.store.progress.update(edited(note: "άλλο", photoIDs: ["b", "a"]))
        let photos = try await bench.drain()

        #expect(note == [.save(.entry(recorded.id), fields: ["note"])])
        #expect(photos == [
            .save(.entry(recorded.id), fields: ["photoIDs"]), .entryPhotos(entryID: recorded.id, photoIDs: ["b", "a"])
        ])
    }

    @Test("Given the dad's look, when only the beard changes, then his hero's record with only the beard")
    func theBeardSendsOnlyTheBeard() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()

        try await bench.store.profiles.save(HeroEdit(beard: .full))

        #expect(try await bench.drain() == [.save(.hero(.testDad), fields: ["beard"])])
    }

    @Test("Given a title kept before a deletion, and a card closed, then heldTitleID and seenTitleID, each alone")
    func aKeptTitleSendsHeldTitleID() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()

        try await bench.store.standing.keep(titleID: "t1", catalog: .threeTitles)
        try await bench.store.standing.markSeen(titleID: "t1")

        #expect(try await bench.drain() == [
            .save(.hero(.testDad), fields: ["heldTitleID"]), .save(.hero(.testDad), fields: ["seenTitleID"])
        ])
    }

    @Test("Given a wardrobe slot, when it is hidden, changed and set back to automatic, then a save, its choice, a deletion")
    func aWardrobeChoiceIsSavedThenDeleted() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()

        _ = try await bench.store.outfit.setChoice(.hidden, for: .care)
        let hidden = try await bench.drain()
        _ = try await bench.store.outfit.setChoice(.item("g-mug"), for: .care)
        let changed = try await bench.drain()
        _ = try await bench.store.outfit.setChoice(.automatic, for: .care)
        let cleared = try await bench.drain()

        #expect(hidden == [.save(.wardrobe(skill: "care"), fields: nil)])
        #expect(changed == [.save(.wardrobe(skill: "care"), fields: ["choice"])])
        // Named by the skill its tombstone kept.
        #expect(cleared == [.delete(.wardrobe(skill: "care"))])
    }

    @Test("Given a sent entry with photos, when it is deleted, then a deletion named by its id, and its photos go")
    func aDeletedEntryIsNamedByItsTombstone() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()
        let recorded = entry(with: lena, photoIDs: ["a"])
        try await bench.store.progress.add(recorded)
        try await bench.drain()

        try await bench.store.progress.delete(id: recorded.id)

        #expect(try await bench.drain() == [
            .delete(.entry(recorded.id)), .entryPhotos(entryID: recorded.id, photoIDs: nil)
        ])
    }

    @Test("Given an entry added and deleted before a drain, when drained, then nothing waits for it")
    func addedAndDeletedSendsNothing() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()
        let waitingBefore = try await bench.ledger.pending()
        let recorded = entry(with: lena, photoIDs: ["a"])

        try await bench.store.progress.add(recorded)
        try await bench.store.progress.delete(id: recorded.id)
        let changes = try await bench.drain()

        // The insert still names the entry, by the id its later deletion kept.
        #expect(changes == [
            .save(.entry(recorded.id), fields: nil),
            .delete(.entry(recorded.id)), .entryPhotos(entryID: recorded.id, photoIDs: nil)
        ])
        #expect(try await bench.ledger.pending() == waitingBefore)
    }

    @Test("Given a child removed and brought back, then each is only isRemoved")
    func removingAndBringingBackSendOnlyTheMark() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()

        try await bench.store.profiles.save(FamilyEdit(removedIDs: [lena.id]))
        let removed = try await bench.drain()
        try await bench.store.profiles.bringBack(childID: lena.id)
        let back = try await bench.drain()

        #expect(removed == [.save(.child(lena.id), fields: ["isRemoved"])])
        #expect(back == [.save(.child(lena.id), fields: ["isRemoved"])])
    }

    @Test("Given a removed child with entries, when deleted for good, then gone, each entry's deletion, and the id kept")
    func deletingForGoodSendsGone() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()
        let (first, second) = (entry(with: lena, photoIDs: ["a"]), entry(with: lena))
        let others = entry(with: nikos)
        for entry in [first, second, others] { try await bench.store.progress.add(entry) }
        try await bench.store.profiles.save(FamilyEdit(removedIDs: [lena.id]))
        try await bench.drain()
        let zones = SyncZones(family: .family(UUID(), owner: "_owner"))

        _ = try await bench.store.profiles.deleteForGood(childID: lena.id)
        let changes = try await bench.drain()

        #expect(changes.count == 5)
        #expect(Set(changes) == [
            .gone(childID: lena.id),
            .delete(.entry(first.id)), .entryPhotos(entryID: first.id, photoIDs: nil),
            .delete(.entry(second.id)), .entryPhotos(entryID: second.id, photoIDs: nil)
        ])
        // The marker waits as the child's whole record, and the id stays for every zone this iPhone builds.
        let gone = try await bench.ledger.goneIDs()
        #expect(gone == [lena.id])
        let waiting = try await bench.ledger.pending().first { $0.name == .child(lena.id) }
        #expect(waiting?.isDeletion == false)
        #expect(waiting?.fields == nil)
        let marker = try await bench.feed.records([(.child(lena.id), nil)], zones: zones, gone: gone)
        #expect(marker == [ChildRecord.goneRecord(childID: lena.id, zones: zones)])
    }

    @Test("Given a restore and a start over, saved under sync, when drained, then nothing; an edit after them is read")
    func writesUnderSyncAreSkipped() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()
        try await bench.store.progress.add(entry(with: lena))
        try await bench.drain()
        var saga = try #require(try await bench.store.wholeSaga.readAll())
        saga.profile.children.removeLast()
        saga.events = []

        try await bench.store.wholeSaga.replaceAll(with: saga)
        let restored = try await bench.drain()
        try await bench.store.profiles.save(HeroEdit(beard: .full))
        let edited = try await bench.drain()
        try await bench.store.wholeSaga.eraseAll()
        let erased = try await bench.drain()

        #expect(restored.isEmpty)
        #expect(edited == [.save(.hero(.testDad), fields: ["beard"])])
        #expect(erased.isEmpty)
    }

    @Test("Given an entry recorded and not yet drained, when a restore replaces every row, then the entry sends nothing")
    func aRowReplacedUnderSyncSendsNothing() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()
        let saga = try #require(try await bench.store.wholeSaga.readAll())

        try await bench.store.progress.add(entry(with: lena, photoIDs: ["a"]))
        try await bench.store.profiles.save(HeroEdit(beard: .full))
        try await bench.store.wholeSaga.replaceAll(with: saga)

        #expect(try await bench.drain().isEmpty)
    }
}
