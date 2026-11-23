import Application
import Domain
import Foundation
import Testing
@testable import Data

/// Joining a family and joining it again (ADR-0065 §2, §4, §8), as far as the sync core goes: the child map, the
/// rejoin's rule for what the family lacks, the member each parent writes for themselves, and `saga` and the
/// joiner's own zone, in that order. Matching the children and the waiting room come with the screens.
@Suite("Joining a family, and joining it again", .serialized)
struct JoinFamilyTests: SyncBench {
    let root = FileManager.default.temporaryDirectory.appending(path: "dadsaga-join-" + UUID().uuidString)
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)

    @Test("Given a joiner with a saga, when they join, then their entries move, then `saga`, then their own zone goes")
    func joiningMovesEntriesThenSagaThenTheZone() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (dad, _) = try await started("dad", on: cloud)
        let partner = try await partnerAlone(on: cloud)
        let mum = partner.phone
        let zoe = Child(name: "Ζωή", birthDay: nil)
        try await mum.store.profiles.save(FamilyEdit(added: [zoe]))
        let withZoe = try await mum.record(zoe, by: .partner, minute: 4)
        try await settle(mum)
        let (own, zone) = (try await mum.family(), try await dad.family())
        guard case .family(let zoneID, _) = zone else { return }
        await cloud.share(zone, with: "mum")
        let map = ChildMap(familyIDs: [partner.ownLena.id: lena.id])
        // An edit of hers that hasn't been sent when she joins.
        try await mum.store.progress.update(ProgressEvent(
            id: partner.entry.id, authorID: .partner, kind: partner.entry.kind, childID: partner.ownLena.id,
            date: partner.entry.date, note: "πριν", photoIDs: []
        ))

        try await mum.coordinator.join(zone, childMap: map)
        // Nothing of the family is sent before its zone has been fetched whole: not into the zone she leaves, and
        // not into the family's, where her entry would still name her own child.
        try await mum.sendChanges()
        #expect(await cloud.records(in: zone, of: "dad")[.entry(partner.entry.id)] == nil)
        #expect(await cloud.records(in: own, of: "mum")[.entry(partner.entry.id)]?["note"] == .string("δικό της"))
        try await mum.fetch()

        // The family is whole on her iPhone in one step: her Λένα is the family's, and the child she didn't match
        // joins as a new one. Nothing is sent before the zone has been fetched.
        let children = try await mum.children()
        #expect(Set(children) == [lena, nikos, zoe])
        #expect(try await mum.store.progress.fetchEvents().first { $0.id == partner.entry.id }?.childID == lena.id)
        #expect(await cloud.records(in: zone, of: "dad")[.member(.partner)] == nil)

        try await mum.send()
        // Her entries are in the family's zone, as hers. Until then `saga` names her own zone, which is still there.
        let records = await cloud.records(in: zone, of: "dad")
        #expect(records[.entry(partner.entry.id)]?["childID"] == .string(lena.id.uuidString))
        #expect(records[.entry(partner.entry.id)]?["author"] == .string(UUID.partner.uuidString))
        #expect(records[.entry(partner.entry.id)]?["note"] == .string("πριν"))
        #expect(records[.entry(withZoe.id)]?["childID"] == .string(zoe.id.uuidString))
        #expect(records[.child(zoe.id)]?["name"] == .string("Ζωή"))
        #expect(records[.child(partner.ownLena.id)] == nil)
        #expect(await saga(of: "mum", on: cloud)?["familyOwner"] == .string("mum"))
        #expect(await cloud.zones(of: "mum").contains(own))

        try await mum.send()
        // `saga` first, so her other iPhones learn where the saga went before they see its old zone go.
        #expect(await saga(of: "mum", on: cloud) == [
            "familyZone": .string(zoneID.uuidString), "familyOwner": .string("dad"),
            "childMap": .string(#"{"\#(partner.ownLena.id.uuidString)":"\#(lena.id.uuidString)"}"#)
        ])
        #expect(await cloud.zones(of: "mum").contains(own))

        try await settle(dad, mum)
        #expect(await cloud.zones(of: "mum") == [.personal])
        #expect(try await mum.ledger().settings().oldFamilyZoneID == nil)
        // Two children at one place in the order show the same way on both iPhones.
        #expect(try await dad.children() == children)
        #expect(try await mum.ledger().goneIDs().isEmpty)
        #expect(await mum.offers.answeredOccasionIDs() == ["\(lena.id.uuidString)/birthday/1"])
    }

    @Test("Given a photo only her own zone still holds, when she joins, then that zone stays until the family's holds the photo")
    func theZoneSheLeavesKeepsTheOnlyCopyOfAPhoto() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (dad, _) = try await started("dad", on: cloud)
        let partner = try await partnerAlone(on: cloud)
        let mum = partner.phone
        let photoID = try await mum.photos.save(try smallImage())
        let jpeg = try await mum.photos.storedData(id: photoID)
        let pictured = try await mum.record(partner.ownLena, by: .partner, minute: 2, photoIDs: [photoID])
        try await settle(mum)
        let (own, zone) = (try await mum.family(), try await dad.family())
        // The file is no longer on this iPhone (swept, or a restore that came without it): iCloud has the only copy.
        await mum.photos.delete(id: photoID)
        await cloud.share(zone, with: "mum")

        try await mum.coordinator.join(zone, childMap: ChildMap(familyIDs: [partner.ownLena.id: lena.id]))
        try await settle(dad, mum)

        // The move is done, but for the zone she left: it still holds the photo, and the family's doesn't.
        #expect(await saga(of: "mum", on: cloud)?["familyOwner"] == .string("dad"))
        #expect(try await dad.entryIDs().contains(pictured.id))
        #expect(await cloud.records(in: zone, of: "dad")[.photo(photoID)] == nil)
        #expect(await cloud.zones(of: "mum").contains(own))
        #expect(await cloud.asset(of: .photo(photoID), in: own, of: "mum") == jpeg)
        #expect(try await mum.ledger().pending().isEmpty)

        // Another of her iPhones has the file, follows, and sends it: now her old zone can go.
        let file = root.appending(path: "from-her-other-iphone.jpg")
        try jpeg.write(to: file)
        var photo = SyncRecord(name: .photo(photoID), zone: zone, fields: ["entryID": .string(pictured.id.uuidString)])
        photo.asset = file
        await cloud.write(photo, as: "mum")
        try await settle(dad, mum)

        #expect(await cloud.zones(of: "mum") == [.personal])
        #expect(try await mum.photos.storedData(id: photoID) == jpeg)
        #expect(try await mum.ledger().settings().oldFamilyZoneID == nil)
    }

    @Test("Given iCloud just turned on, when she joins before `saga` was sent, then `saga` waits for the family's zone")
    func aSagaNotSentYetWaitsForTheFamily() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (dad, _) = try await started("dad", on: cloud)
        let mum = phone("mum", account: "mum", on: cloud)
        let zoe = Child(name: "Ζωή", birthDay: nil)
        try await mum.store.profiles.create(PlayerProfile(id: .partner, children: [zoe], heroClassID: "h-chef"))
        let hers = try await mum.record(zoe, by: .partner, minute: 1)
        #expect(try await mum.coordinator.turnOn() == .turnedOn)
        let zone = try await dad.family()
        await cloud.share(zone, with: "mum")

        try await mum.coordinator.join(zone, childMap: ChildMap())
        try await mum.send()

        // Her own records go, but not `saga`: it would name a family whose zone holds nothing of hers yet, and her
        // other iPhones would follow it there.
        #expect(await cloud.records(in: .personal, of: "mum")[.hero(.partner)] != nil)
        #expect(await saga(of: "mum", on: cloud) == nil)

        try await settle(dad, mum)
        #expect(await cloud.records(in: zone, of: "dad")[.entry(hers.id)] != nil)
        #expect(await saga(of: "mum", on: cloud)?["familyOwner"] == .string("dad"))
        #expect(await cloud.zones(of: "mum") == [.personal])
        #expect(try await mum.ledger().pending().isEmpty)
    }

    @Test("Given the family's children come after its entries, when a joiner fetches, then the map waits for them")
    func theMapWaitsForTheFamilysChildren() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (dad, _) = try await started("dad", on: cloud)
        for minute in 0..<120 { try await dad.record(nikos, by: .testDad, minute: minute) }
        try await settle(dad)
        let partner = try await partnerAlone(on: cloud)
        let zone = try await dad.family()
        await cloud.share(zone, with: "mum")
        await cloud.setDeliversInReverse(true)

        try await partner.phone.coordinator.join(zone, childMap: ChildMap(familyIDs: [partner.ownLena.id: lena.id]))
        try await settle(dad, partner.phone)

        #expect(try await partner.phone.children() == [lena, nikos])
        #expect(try await partner.phone.entryIDs().count == 122)
        #expect(try await dad.store.progress.fetchEvents().first { $0.id == partner.entry.id }?.childID == lena.id)
        #expect(try await partner.phone.ledger().pending().isEmpty)
    }

    @Test("Given a map that names a child the family doesn't have, when joined, then that child stays theirs, as a new one")
    func aChildTheFamilyLacksIsNotMapped() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (dad, _) = try await started("dad", on: cloud)
        let partner = try await partnerAlone(on: cloud)
        let zone = try await dad.family()
        await cloud.share(zone, with: "mum")

        try await partner.phone.coordinator.join(zone, childMap: ChildMap(familyIDs: [partner.ownLena.id: UUID()]))
        try await settle(dad, partner.phone)

        // Nothing she recorded is hidden behind a child that isn't there.
        let children = try await partner.phone.children()
        #expect(Set(children) == [lena, nikos, partner.ownLena])
        #expect(try await dad.children() == children)
        #expect(try await dad.store.progress.fetchEvents().first { $0.id == partner.entry.id }?.childID == partner.ownLena.id)
        #expect(await saga(of: "mum", on: cloud)?["childMap"] == nil)
        #expect(await partner.phone.offers.answeredOccasionIDs() == [partner.occasion])
    }

    @Test("Given the family holds a member for this parent that another account wrote, when they join, then it is written again")
    func aMemberAnotherAccountCreatedIsWrittenAgain() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (dad, _) = try await started("dad", on: cloud)
        let partner = try await partnerAlone(on: cloud)
        let zone = try await dad.family()
        let member = RecordName.member(.partner)
        await cloud.write(SyncRecord(name: member, zone: zone, fields: ["userRecordName": .string("mum")]), as: "dad")
        try await settle(dad)
        // A record written for someone else never makes them a member.
        #expect(await dad.coordinator.status() == ShareStatus(sharing: .alone))
        await cloud.share(zone, with: "mum")

        try await partner.phone.coordinator.join(zone, childMap: ChildMap(familyIDs: [partner.ownLena.id: lena.id]))
        try await settle(dad, partner.phone)

        let written = try #require(await cloud.record(member, in: zone, of: "dad"))
        #expect(written.creator == "mum")
        #expect(written.fields == ["userRecordName": .string("mum")])
        #expect(await dad.coordinator.status() == ShareStatus(sharing: .owner))
        #expect(try await partner.phone.ledger().pending().isEmpty)
        #expect(try await dad.entryIDs().contains(partner.entry.id))
    }

    @Test("Given iCloud off, a map that moves a child twice, or no family to follow, when asked to move, then it says why")
    func whatCantBeJoinedOrFollowed() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (dad, _) = try await started("dad", on: cloud)
        let zone = try await dad.family()
        let off = phone("off", account: "mum", on: cloud)
        try await off.store.profiles.create(PlayerProfile(id: .partner, children: [nikos], heroClassID: "h-chef"))
        let (first, second) = (UUID(), UUID())

        await #expect(throws: FamilyMoveError.off) { try await off.coordinator.join(zone, childMap: ChildMap()) }
        await #expect(throws: FamilyMoveError.notAFamily) { try await dad.coordinator.join(.personal, childMap: ChildMap()) }
        await #expect(throws: FamilyMoveError.unusableChildMap) {
            try await dad.coordinator.join(zone, childMap: ChildMap(familyIDs: [first: second, second: UUID()]))
        }
        await #expect(throws: FamilyMoveError.nothingToFollow) { try await dad.coordinator.follow() }
        #expect(try await dad.family() == zone)
        #expect(!FileManager.default.fileExists(atPath: off.syncStoreURL.path))
    }
}
