import Application
import Domain
import Foundation
import Testing
@testable import Data

/// A child removed, brought back and deleted for good, between two parents (ADR-0065 §4, §8): removing is a field
/// like any other, a removal never leaves the family without a child, and nothing brings back a child deleted for
/// good: not a save that raced it, not a zone built later, not an iPhone that was off. Only a copy the parent chose.
@Suite("A removed child, between two parents", .serialized)
struct RemovedChildSyncTests: SyncBench {
    let root = FileManager.default.temporaryDirectory.appending(path: "dadsaga-removed-sync-" + UUID().uuidString)
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)

    func deleteForGood(_ child: Child, on phone: SyncPhone) async throws {
        try await DefaultDeleteChildForGoodUseCase(
            contentRepository: phone.content, profileRepository: phone.store.profiles,
            progressRepository: phone.store.progress, standingRepository: phone.store.standing, photoStore: phone.photos,
            renewReminders: NoReminders()
        ).execute(childID: child.id, on: .now)
    }

    /// The family, with Λένα removed on both iPhones.
    func familyWithLenaRemoved() async throws -> SyncedFamily {
        let family = try await family(on: makeCloud())
        try await family.dad.store.profiles.save(FamilyEdit(removedIDs: [lena.id]))
        try await settle(family.dad, family.mum)
        return family
    }

    @Test("Given one removes a child while the other renames them, then removed and renamed on both; brought back, likewise")
    func removingMergesByField() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum) = (family.dad, family.mum)

        try await dad.store.profiles.save(FamilyEdit(removedIDs: [lena.id]))
        try await mum.rename(lena, to: "Ελένη")
        try await settle(dad, mum)

        for phone in [dad, mum] {
            #expect(try await phone.children() == [nikos])
            #expect(try await phone.removedChildren().map(\.name) == ["Ελένη"])
        }

        // Brought back by one while the other changes another field of the removed child's record.
        try await mum.store.profiles.bringBack(childID: lena.id)
        await family.cloud.write(try await record(.child(lena.id), ["skinTone": .string("dark")], for: dad), as: "dad")
        try await settle(dad, mum)

        for phone in [dad, mum] {
            let back = try #require(try await phone.children().first)
            #expect(back.name == "Ελένη")
            #expect(back.skinTone == .dark)
            #expect(try await phone.removedChildren().isEmpty)
        }
    }

    @Test("Given each parent removes the other's last child offline, then the family is never empty, and both come back")
    func theLastChildStays() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum) = (family.dad, family.mum)

        try await dad.store.profiles.save(FamilyEdit(removedIDs: [lena.id]))
        try await mum.store.profiles.save(FamilyEdit(removedIDs: [nikos.id]))
        #expect(try await dad.children() == [nikos])
        #expect(try await mum.children() == [lena])
        try await settle(dad, mum)

        // On each iPhone the removal that came would have left no child: that child stays, and is sent again. Nothing
        // is lost, and either parent can remove again.
        for phone in [dad, mum] {
            #expect(try await phone.children() == [lena, nikos])
            #expect(try await phone.removedChildren().isEmpty)
            #expect(try await phone.ledger().pending().isEmpty)
        }
        let records = await family.cloud.records(in: family.zone, of: "dad")
        #expect(records[.child(lena.id)]?["isRemoved"] == .bool(false))
        #expect(records[.child(nikos.id)]?["isRemoved"] == .bool(false))
    }

    @Test("Given a removed child, when one parent deletes them for good, then only the marker stays, on both iPhones too")
    func deletingForGoodReachesThePartner() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await familyWithLenaRemoved()
        let (dad, mum, cloud) = (family.dad, family.mum, family.cloud)
        let photoID = family.dadsEntry.photoIDs[0]
        let withNikos = try await dad.record(nikos, by: .testDad, minute: 1)
        try await settle(dad, mum)
        #expect(try await dad.home().progress.totalXP == 40)

        try await deleteForGood(lena, on: mum)
        try await settle(dad, mum)

        // The marker, every other field cleared; no entry with the child and no photo of theirs is left in the zone.
        let records = await cloud.records(in: family.zone, of: "dad")
        #expect(records[.child(lena.id)] == ["gone": .bool(true)])
        #expect(Set(records.keys.filter { $0.type == .entry }) == [.entry(withNikos.id)])
        #expect(records.keys.filter { $0.type == .photo }.isEmpty)
        // On the dad's iPhone the child goes with every entry, his own too, and the photo's file.
        #expect(try await dad.children() == [nikos])
        #expect(try await dad.removedChildren().isEmpty)
        #expect(try await dad.entryIDs() == [withNikos.id])
        #expect(try await dad.photos.fileURL(id: photoID) == nil)
        #expect(try await dad.ledger().goneIDs() == [lena.id])
        // The entries' XP goes for both, and each one's title is kept (ADR-0055 §3): his by his own iPhone, before
        // it applied the marker, and sent to his own zone.
        #expect(try await dad.home().progress.totalXP == 20)
        #expect(try await dad.home().standing.title?.id == "t2")
        #expect(try await dad.cloudRecord(.hero(.testDad))?["heldTitleID"] == .string("t2"))
        #expect(try await mum.home().progress.totalXP == 0)
        #expect(try await mum.home().standing.title?.id == "t1")
        #expect(try await dad.ledger().pending().isEmpty)
        #expect(try await mum.ledger().pending().isEmpty)
    }

    @Test(
        "Given a bring-back racing a delete for good, whichever reaches iCloud first, then the child is gone on both",
        arguments: [true, false]
    )
    func aBringBackRacingADeleteForGood(markerFirst: Bool) async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await familyWithLenaRemoved()
        let (dad, mum, cloud) = (family.dad, family.mum, family.cloud)

        try await deleteForGood(lena, on: mum)
        try await dad.store.profiles.bringBack(childID: lena.id)
        try await dad.rename(lena, to: "Ελένη")
        #expect(try await dad.children().map(\.name) == ["Ελένη", "Νίκος"])
        if markerFirst {
            // His save lands on the marker and is ignored: `gone` is final.
            try await settle(mum, dad)
        } else {
            // His save lands first: her marker goes over it, every field cleared.
            try await settle(dad, mum)
        }

        #expect(await cloud.records(in: family.zone, of: "dad")[.child(lena.id)] == ["gone": .bool(true)])
        for phone in [dad, mum] {
            #expect(try await phone.children() == [nikos])
            #expect(try await phone.removedChildren().isEmpty)
            #expect(try await phone.entryIDs().isEmpty)
            #expect(try await phone.ledger().goneIDs() == [lena.id])
            #expect(try await phone.ledger().pending().isEmpty)
        }
    }

    @Test("Given a delete for good that takes the last child on an iPhone, then only the removal that came last is undone")
    func aMarkerThatTakesTheLastChild() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await familyWithLenaRemoved()
        let (dad, mum) = (family.dad, family.mum)
        // Offline, he brings Λένα back and removes Νίκος; meanwhile she deletes Λένα for good.
        try await dad.store.profiles.bringBack(childID: lena.id)
        try await dad.store.profiles.save(FamilyEdit(removedIDs: [nikos.id]))
        try await deleteForGood(lena, on: mum)
        try await mum.sendChanges()
        try await dad.sendChanges()
        try await dad.fetch()

        // The marker is final, and brings no one back by itself: his iPhone shows no child for now.
        #expect(try await dad.children().isEmpty)
        #expect(try await dad.removedChildren() == [nikos])

        // His removal reaches her iPhone, where it would leave no child: it is not applied, and is sent again.
        try await settle(mum, dad)
        for phone in [dad, mum] {
            #expect(try await phone.children() == [nikos])
            #expect(try await phone.removedChildren().isEmpty)
            #expect(try await phone.ledger().goneIDs() == [lena.id])
            #expect(try await phone.ledger().pending().isEmpty)
        }
    }

    @Test("Given a child deleted for good, when an iPhone that was off writes them and an entry again, then the marker goes back")
    func aLateUploadDoesNotBringThemBack() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await familyWithLenaRemoved()
        let (dad, mum, cloud) = (family.dad, family.mum, family.cloud)
        try await deleteForGood(lena, on: mum)
        try await settle(dad, mum)
        let late = ProgressEvent(kind: .quest(id: "q1"), childID: lena.id, date: .now, photoIDs: ["late-photo"])

        // An iPhone that never saw the marker saves the child whole, and an entry with them and its photo.
        let zones = SyncZones(family: family.zone)
        var whole = ChildRecord(child: lena, order: 0, isRemoved: false).syncRecord(fields: nil, zones: zones)
        whole.fields["gone"] = .cleared
        await cloud.write(whole, as: "dad")
        await cloud.write(ProgressEventRecord(event: late).syncRecord(fields: nil, zones: zones), as: "dad")
        await cloud.write(try await record(.photo("late-photo"), ["entryID": .string(late.id.uuidString)], for: dad), as: "dad")
        try await settle(dad, mum)

        let records = await cloud.records(in: family.zone, of: "dad")
        #expect(records[.child(lena.id)] == ["gone": .bool(true)])
        #expect(records[.entry(late.id)] == nil)
        #expect(records[.photo("late-photo")] == nil)
        for phone in [dad, mum] {
            #expect(try await phone.children() == [nikos])
            #expect(try await phone.entryIDs().isEmpty)
            #expect(try await phone.ledger().pending().isEmpty)
        }
    }

    @Test("Given iCloud off on an iPhone while a child is deleted for good, when turned on again, then the child goes there too")
    func turningOnAgainNeverSendsAGoneChild() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await familyWithLenaRemoved()
        let (dad, mum, cloud) = (family.dad, family.mum, family.cloud)
        let second = try await secondPhone(of: dad, named: "dad-2")
        await second.coordinator.resume()
        // Another account for a while: sync is off there, and stays off when his own account is back.
        await second.device.switchAccount(to: "other")
        await second.device.signIn("dad")
        #expect(await second.coordinator.status() == ShareStatus(sharing: .off))
        try await second.store.profiles.bringBack(childID: lena.id)
        try await deleteForGood(lena, on: mum)
        try await settle(dad, mum)

        #expect(try await second.coordinator.turnOn() == .turnedOn)
        try await settle(dad, mum, second)

        // A full send follows a fetch of the whole zone: the child it holds as gone is deleted here, never sent.
        #expect(await cloud.records(in: family.zone, of: "dad")[.child(lena.id)] == ["gone": .bool(true)])
        #expect(try await second.children() == [nikos])
        #expect(try await second.removedChildren().isEmpty)
        #expect(try await second.entryIDs().isEmpty)
        #expect(try await second.ledger().goneIDs() == [lena.id])
        #expect(try await second.home().standing.title?.id == "t1")
        #expect(try await dad.children() == [nikos])
        #expect(try await second.ledger().pending().isEmpty)
    }

    @Test("Given a child deleted for good, when a copy the parent chose brings them back and iCloud is turned on, then they stay")
    func aCopyBringsBackAChildDeletedForGood() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, _) = try await started(on: cloud)
        let family = try await phone.family()
        try await phone.record(nikos, by: .testDad, minute: 3)
        try await settle(phone)
        let copy = try #require(try await phone.store.wholeSaga.readAll())
        try await phone.store.profiles.save(FamilyEdit(removedIDs: [nikos.id]))
        try await deleteForGood(nikos, on: phone)
        try await settle(phone)
        #expect(try await phone.ledger().goneIDs() == [nikos.id])
        // Another of his iPhones deletes the family's zone: sync is off here, and `Sync.store` keeps the child's id.
        await cloud.deleteZone(family, by: "dad")
        try await phone.fetch()
        #expect(await phone.coordinator.status() == ShareStatus(sharing: .off))

        try await phone.store.wholeSaga.replaceAll(with: copy)
        let entries = try await phone.entryIDs()
        #expect(try await phone.coordinator.turnOn() == .turnedOn)
        try await settle(phone)

        // A confirmed replace wins: the child is a child again, here and in the zone, with every entry.
        #expect(try await phone.children() == [lena, nikos])
        #expect(try await phone.entryIDs() == entries)
        #expect(try await phone.ledger().goneIDs().isEmpty)
        let records = await cloud.records(in: try await phone.family(), of: "dad")
        #expect(records[.child(nikos.id)]?["name"] == .string("Νίκος"))
        #expect(Set(records.keys.filter { $0.type == .entry }) == Set(entries.map(RecordName.entry)))
        #expect(try await phone.ledger().pending().isEmpty)
    }

    @Test("Given an iPhone off through a delete for good and a stop, when it follows and sends, then the child stays gone")
    func aStaleIPhoneThatFollows() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await familyWithLenaRemoved()
        let (dad, mum, cloud) = (family.dad, family.mum, family.cloud)
        // Her second iPhone still has the child, removed, and every entry with them.
        let stale = try await secondPhone(of: mum, named: "mum-2")
        try await deleteForGood(lena, on: mum)
        try await settle(dad, mum)
        await cloud.stopSharing(family.zone)
        try await settle(dad, mum)
        let own = try await mum.family()
        #expect(await cloud.records(in: own, of: "mum")[.child(lena.id)] == ["gone": .bool(true)])

        await stale.coordinator.resume()
        try await stale.store.profiles.bringBack(childID: lena.id)
        try await settle(stale)
        #expect(await stale.coordinator.status().waiting == .followFamily)
        try await stale.coordinator.follow()
        try await settle(mum, stale)

        // The zone her first iPhone built carries the marker: the stale one deletes the child, and sends nothing of them.
        let records = await cloud.records(in: own, of: "mum")
        #expect(records[.child(lena.id)] == ["gone": .bool(true)])
        #expect(records.keys.filter { $0.type == .entry }.isEmpty)
        for phone in [mum, stale] {
            #expect(try await phone.children() == [nikos])
            #expect(try await phone.removedChildren().isEmpty)
            #expect(try await phone.entryIDs().isEmpty)
        }
        #expect(try await stale.ledger().goneIDs() == [lena.id])
        #expect(try await stale.home().standing.title?.id == "t1")
        #expect(try await stale.ledger().pending().isEmpty)
    }
}
