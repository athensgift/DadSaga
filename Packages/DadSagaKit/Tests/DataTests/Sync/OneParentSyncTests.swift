import Application
import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// One parent's saga and their own iCloud (ADR-0065 §2, §4): turning on, what the dad changes going out by itself,
/// and what another of his iPhones wrote coming in and merging by field. One iPhone on a `FakeCloud`; the dad's
/// other iPhone is records written straight into it.
@Suite("One parent's saga and iCloud", .serialized)
struct OneParentSyncTests: SyncBench {
    let root = FileManager.default.temporaryDirectory.appending(path: "dadsaga-sync-" + UUID().uuidString)
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)

    func child(_ child: Child, on phone: SyncPhone) async throws -> Child? {
        try await phone.store.profiles.fetchProfile()?.children.first { $0.id == child.id }
    }

    @Test("Given a saga, when iCloud is turned on, then all of it goes: `saga` first, photos last, 250 at most a time")
    func turningOnSendsEverything() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let phone = phone("iphone", account: "dad", on: cloud)
        let entry = try await onboard(phone)
        for minute in 0..<260 {
            try await phone.store.progress.add(ProgressEvent(
                kind: .quest(id: "q1"), childID: nikos.id, date: entry.date.addingTimeInterval(Double(minute) * 60)
            ))
        }

        #expect(try await phone.coordinator.turnOn() == .turnedOn)
        try await phone.send()

        let family = try await phone.family()
        guard case .family(let zoneID, "dad") = family else {
            Issue.record("The family's zone is not in the dad's own iCloud")
            return
        }
        let personal = await cloud.records(in: .personal, of: "dad")
        #expect(Set(personal.keys) == [
            .hero(.testDad), .wardrobe(skill: "care"), .offer(occasionID: "\(lena.id.uuidString)/birthday/1"), .saga
        ])
        #expect(personal[.saga] == ["familyZone": .string(zoneID.uuidString), "familyOwner": .string("dad")])
        #expect(personal[.hero(.testDad)]?["classID"] == .string("h-cool"))
        #expect(personal[.wardrobe(skill: "care")] == ["choice": .string("hidden")])
        let records = await cloud.records(in: family, of: "dad")
        // The dad's member, two children, 261 entries and a photo.
        #expect(records.count == 265)
        #expect(records[.member(.testDad)] == ["userRecordName": .string("dad")])
        #expect(records[.child(lena.id)]?["name"] == .string("Λένα"))
        #expect(records[.entry(entry.id)]?["photoIDs"] == .strings(entry.photoIDs))
        let photo = RecordName.photo(entry.photoIDs[0])
        #expect(records[photo] == ["entryID": .string(entry.id.uuidString)])
        #expect(await cloud.asset(of: photo, in: family, of: "dad") == (try await phone.photos.storedData(id: photo.id)))
        // `saga` first, so iCloud is seen to hold this saga from the first request on; the parent's own records
        // don't wait behind the photos; a partner's timeline fills before its pictures; and no request passes the
        // server's limit.
        let order: [RecordType] = [.saga, .hero, .wardrobe, .offer, .member, .child, .entry, .photo]
        let sent = await cloud.requests.flatMap(\.self).compactMap { order.firstIndex(of: $0.type) }
        #expect(sent == sent.sorted())
        let sizes = try #require(await phone.device.engine()?.batchSizes)
        #expect(sizes.count > 1 && sizes.allSatisfy { $0 <= 250 })
        #expect(try await phone.ledger().pending().isEmpty)
        #expect(await phone.coordinator.status() == ShareStatus(sharing: .alone))
    }

    @Test("Given an iCloud holding another saga, when iCloud is turned on, then nothing is written or sent")
    func iCloudHoldingAnotherSagaIsLeftAlone() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let other: [String: SyncValue] = ["familyZone": .string(UUID().uuidString), "familyOwner": .string("dad")]
        await cloud.write(SyncRecord(name: .saga, zone: .personal, fields: other), as: "dad")
        let phone = phone("iphone", account: "dad", on: cloud)
        let entry = try await onboard(phone)

        #expect(try await phone.coordinator.turnOn() == .iCloudHoldsAnotherSaga)

        #expect(!FileManager.default.fileExists(atPath: phone.syncStoreURL.path))
        #expect(phone.device.engines.isEmpty)
        #expect(await cloud.records(in: .personal, of: "dad") == [.saga: other])
        #expect(await cloud.zones(of: "dad") == [.personal])
        #expect(try await phone.store.progress.fetchEvents() == [entry])
        #expect(await phone.coordinator.status() == ShareStatus(sharing: .off))
    }

    @Test("Given no Apple Account, or no saga, when iCloud is turned on, then it says so and nothing is created")
    func nothingToTurnOn() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let signedOut = phone("signed-out", account: nil, on: cloud)
        try await onboard(signedOut)
        let empty = phone("empty", account: "dad", on: cloud)

        #expect(try await signedOut.coordinator.turnOn() == .noAccount)
        #expect(try await empty.coordinator.turnOn() == .noSaga)

        #expect(!FileManager.default.fileExists(atPath: signedOut.syncStoreURL.path))
        #expect(!FileManager.default.fileExists(atPath: empty.syncStoreURL.path))
        #expect(await cloud.zones(of: "dad").isEmpty)
    }

    @Test("Given iCloud on, when the dad records an entry, then the store's own save sends it: no one tells sync")
    func anEditReachesICloudByItself() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, _) = try await started(on: cloud)
        let later = ProgressEvent(kind: .quest(id: "q1"), childID: nikos.id, date: .now)
        let waiting = SyncChange.save(.entry(later.id), try await phone.family())

        try await phone.store.progress.add(later)

        #expect(await eventually { await phone.device.engine()?.pending.contains(waiting) ?? false })
        try await phone.send()
        #expect(try await phone.cloudRecord(.entry(later.id))?["childID"] == .string(nikos.id.uuidString))
    }

    @Test("Given a child edited on two iPhones, when they meet, then both fields stay, and one field is the later save's")
    func aChildEditedOnBothSidesMergesByField() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, _) = try await started(on: cloud)
        var edited = lena

        await cloud.write(try await record(.child(lena.id), ["name": .string("Ελένη")], for: phone), as: "dad")
        edited.skinTone = .dark
        try await phone.store.profiles.save(FamilyEdit(changed: [ChildEdit(child: edited, fields: [.skinTone])]))
        try await settle(phone)

        #expect(try await child(lena, on: phone)?.name == "Ελένη")
        #expect(try await child(lena, on: phone)?.skinTone == .dark)
        #expect(try await phone.cloudRecord(.child(lena.id))?["name"] == .string("Ελένη"))
        #expect(try await phone.cloudRecord(.child(lena.id))?["skinTone"] == .string("dark"))

        // The name on both sides: this iPhone saves after the other, so its name stands, here and there.
        await cloud.write(try await record(.child(lena.id), ["name": .string("Λ")], for: phone), as: "dad")
        edited.name = "Λενάκι"
        try await phone.store.profiles.save(FamilyEdit(changed: [ChildEdit(child: edited, fields: [.name])]))
        try await settle(phone)

        #expect(try await child(lena, on: phone)?.name == "Λενάκι")
        #expect(try await phone.cloudRecord(.child(lena.id))?["name"] == .string("Λενάκι"))
        #expect(try await phone.ledger().pending().isEmpty)
    }

    @Test("Given a kept title, when iCloud holds a higher one it is taken; a lower one there is replaced by this one")
    func theHigherTitleWinsBothWays() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, _) = try await started(on: cloud)
        let hero = RecordName.hero(.testDad)

        await cloud.write(try await record(hero, ["heldTitleID": .string("t1")], for: phone), as: "dad")
        try await settle(phone)
        #expect(try await phone.store.standing.fetchKept().titleID == "t1")

        // The other iPhone writes a lower title while this one keeps a higher: a title never goes down.
        await cloud.write(try await record(hero, ["heldTitleID": .string("t0")], for: phone), as: "dad")
        try await phone.store.standing.keep(titleID: "t2", catalog: .titlesAndAQuest)
        try await settle(phone)

        #expect(try await phone.store.standing.fetchKept().titleID == "t2")
        #expect(try await phone.cloudRecord(hero)?["heldTitleID"] == .string("t2"))
    }

    @Test("Given the dad's two entries, when another of his iPhones deletes one, then his title is kept and sent")
    func anOwnDeletionFromICloudKeepsTheTitle() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, entry) = try await started(on: cloud)
        let second = ProgressEvent(kind: .quest(id: "q1"), childID: nikos.id, date: entry.date.addingTimeInterval(60))
        try await phone.store.progress.add(second)
        try await settle(phone)
        #expect(try await phone.cloudRecord(.hero(.testDad))?["heldTitleID"] == nil)

        await cloud.delete(.entry(second.id), in: try await phone.family(), as: "dad")
        try await phone.fetch()
        try await phone.send()

        // Two entries had reached `t2`; one is left. A title never goes down (ADR-0006).
        #expect(try await phone.store.progress.fetchEvents() == [entry])
        #expect(try await phone.store.standing.fetchKept().titleID == "t2")
        #expect(try await phone.cloudRecord(.hero(.testDad))?["heldTitleID"] == .string("t2"))
    }

    @Test("Given a note cleared on another iPhone, when the entry comes, then the note is cleared here too")
    func aFieldClearedElsewhereIsClearedHere() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, entry) = try await started(on: cloud)

        await cloud.write(try await record(.entry(entry.id), ["note": .cleared], for: phone), as: "dad")
        try await settle(phone)

        let stored = try #require(try await phone.store.progress.fetchEvents().first)
        #expect(stored.id == entry.id)
        #expect(stored.note == nil)
        #expect(stored.photoIDs == entry.photoIDs)
    }

    @Test("Given a slot cleared and set again, when this iPhone's own deletion comes back, then the slot stays and is sent")
    func anOwnDeletionComingBackLeavesTheNewRow() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, _) = try await started(on: cloud)
        _ = try await phone.store.outfit.setChoice(.automatic, for: .care)
        try await phone.sendChanges()
        #expect(try await phone.cloudRecord(.wardrobe(skill: "care")) == nil)

        _ = try await phone.store.outfit.setChoice(.item("g-mug"), for: .care)
        await phone.coordinator.drain()
        try await phone.fetch()

        #expect(try await phone.store.outfit.fetchOutfit().choice(for: .care) == .item("g-mug"))
        try await settle(phone)
        #expect(try await phone.cloudRecord(.wardrobe(skill: "care")) == ["choice": .string("item:g-mug")])
        #expect(try await phone.store.outfit.fetchOutfit().choice(for: .care) == .item("g-mug"))
    }

    @Test("Given a removed child, when the dad deletes them for good, then iCloud keeps only the marker, no entry or photo")
    func deletingForGoodLeavesTheMarker() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, entry) = try await started(on: cloud)

        try await phone.store.profiles.save(FamilyEdit(removedIDs: [lena.id]))
        try await settle(phone)
        #expect(try await phone.cloudRecord(.child(lena.id))?["isRemoved"] == .bool(true))
        _ = try await phone.store.profiles.deleteForGood(childID: lena.id)
        try await settle(phone)

        #expect(try await phone.cloudRecord(.child(lena.id)) == ["gone": .bool(true)])
        #expect(try await phone.cloudRecord(.entry(entry.id)) == nil)
        #expect(try await phone.cloudRecord(.photo(entry.photoIDs[0])) == nil)
        #expect(try await phone.cloudRecord(.child(nikos.id))?["name"] == .string("Νίκος"))
        #expect(try await phone.ledger().goneIDs() == [lena.id])
        #expect(try await phone.ledger().pending().isEmpty)
    }
}
