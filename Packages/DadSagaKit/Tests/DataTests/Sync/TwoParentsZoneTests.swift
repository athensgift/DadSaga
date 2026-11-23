import Application
import Domain
import Foundation
import Testing
@testable import Data

/// When sharing ends, and when a parent's iPhones go different ways (ADR-0065 §4, §8): the owner stops, the owner's
/// iCloud data goes, the account's encrypted data is reset, and a second iPhone follows a join. A zone that goes never
/// deletes the saga on any iPhone.
@Suite("Two parents: sharing ends, and iPhones that follow", .serialized)
struct TwoParentsZoneTests: SyncBench {
    let root = FileManager.default.temporaryDirectory.appending(path: "dadsaga-two-zones-" + UUID().uuidString)
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)

    /// What an iPhone shows of the saga: the family, the removed children and every entry.
    func saga(on phone: SyncPhone) async throws -> StoredSaga {
        try #require(try await phone.store.wholeSaga.readAll())
    }

    @Test("Given the owner stops sharing, then the partner keeps everything in a zone of their own, and the owner keeps theirs")
    func theOwnerStopsSharing() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum, cloud) = (family.dad, family.mum, family.cloud)
        // A child deleted for good while they shared: no zone built later may bring them back.
        try await dad.store.profiles.save(FamilyEdit(removedIDs: [nikos.id]))
        try await settle(dad, mum)
        _ = try await mum.store.profiles.deleteForGood(childID: nikos.id)
        try await settle(dad, mum)
        let (before, owners) = (try await saga(on: mum), await cloud.records(in: family.zone, of: "dad"))

        await cloud.stopSharing(family.zone)
        try await settle(dad, mum)

        // Without a question: every child, every entry, the dad's too, and his photo.
        #expect(try await saga(on: mum) == before)
        #expect(try await mum.photos.storedPhotos().map(\.id) == family.dadsEntry.photoIDs)
        let own = try await mum.family()
        guard case .family(_, "mum") = own, own != family.zone else {
            Issue.record("The partner's saga is not in a zone of their own")
            return
        }
        let records = await cloud.records(in: own, of: "mum")
        #expect(Set(records.keys) == [
            .member(.partner), .child(lena.id), .child(nikos.id), .entry(family.dadsEntry.id), .entry(family.mumsEntry.id),
            .photo(family.dadsEntry.photoIDs[0])
        ])
        #expect(records[.child(nikos.id)] == ["gone": .bool(true)])
        #expect(records[.entry(family.dadsEntry.id)]?["author"] == .string(UUID.testDad.uuidString))
        #expect(await cloud.asset(of: .photo(family.dadsEntry.photoIDs[0]), in: own, of: "mum") != nil)
        #expect(try await mum.cloudRecord(.saga)?["familyOwner"] == .string("mum"))
        #expect(await mum.coordinator.status() == ShareStatus(sharing: .alone))
        #expect(try await mum.ledger().pending().isEmpty)
        // The owner keeps the zone as it was, and from now on each saga is its own.
        #expect(await cloud.records(in: family.zone, of: "dad") == owners)
        try await mum.rename(lena, to: "Ελένη")
        try await settle(dad, mum)
        #expect(try await dad.children().map(\.name) == ["Λένα"])
        #expect(await cloud.records(in: own, of: "mum")[.child(lena.id)]?["name"] == .string("Ελένη"))
    }

    @Test("Given the owner deletes DadSaga's iCloud data, then sync is off for them, and the partner keeps everything")
    func theOwnersDataIsPurged() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum, cloud) = (family.dad, family.mum, family.cloud)
        let (his, hers) = (try await saga(on: dad), try await saga(on: mum))

        await cloud.purge("dad")
        try await settle(dad, mum)

        #expect(await dad.coordinator.status() == ShareStatus(sharing: .off))
        #expect(await cloud.zones(of: "dad").isEmpty)
        #expect(try await saga(on: dad) == his)
        #expect(try await saga(on: mum) == hers)
        let own = try await mum.family()
        #expect(Set(await cloud.zones(of: "mum")) == [.personal, own])
        #expect(await cloud.records(in: own, of: "mum").keys.filter { $0.type == .entry }.count == 2)
        #expect(await mum.coordinator.status() == ShareStatus(sharing: .alone))
    }

    @Test("Given sharing ended while the partner's engine started over, when their save finds no zone, then they keep everything")
    func aSharedZoneNoFetchReportsGone() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum, cloud) = (family.dad, family.mum, family.cloud)
        // Signed out and in again, her engines start from nothing: no fetch will say the zone went.
        await mum.device.signOut()
        await cloud.stopSharing(family.zone)
        await mum.device.signIn("mum")

        let recorded = try await mum.record(lena, by: .partner, minute: 1)
        try await settle(dad, mum)

        let own = try await mum.family()
        #expect(own != family.zone)
        #expect(Set(await cloud.records(in: own, of: "mum").keys.filter { $0.type == .entry }) == [
            .entry(family.dadsEntry.id), .entry(family.mumsEntry.id), .entry(recorded.id)
        ])
        #expect(try await mum.entryIDs() == [family.dadsEntry.id, family.mumsEntry.id, recorded.id])
        #expect(try await dad.entryIDs() == [family.dadsEntry.id, family.mumsEntry.id])
        #expect(try await mum.ledger().pending().isEmpty)
    }

    @Test("Given a save that found no zone, when the fetch that follows lists the family's zone, then she is still in the family")
    func aZoneNotFoundOnceIsNotSharingEnded() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (dad, dadsEntry) = try await started("dad", on: cloud)
        let partner = try await partnerAlone(on: cloud)
        let (mum, zone) = (partner.phone, try await dad.family())

        // She accepts before the partner's database shows the zone: her first fetch brings nothing, and her saves
        // find no zone.
        try await mum.coordinator.join(zone, childMap: ChildMap(familyIDs: [partner.ownLena.id: lena.id]))
        try await mum.fetch()
        try await mum.send()
        #expect(await cloud.records(in: zone, of: "dad")[.entry(partner.entry.id)] == nil)
        await cloud.share(zone, with: "mum")
        try await settle(dad, mum)

        // The fetch listed the zone, so sharing has not ended: nothing is rebuilt, and what waited is sent.
        #expect(try await mum.family() == zone)
        #expect(await mum.coordinator.status() == ShareStatus(sharing: .partner))
        #expect(await cloud.zones(of: "mum") == [.personal])
        for phone in [dad, mum] {
            #expect(try await phone.entryIDs() == [dadsEntry.id, partner.entry.id])
            #expect(try await phone.ledger().pending().isEmpty)
        }
    }

    @Test("Given the encrypted data reset with two of the owner's iPhones, then one zone, every row once; the partner keeps all")
    func encryptedDataResetOnTwoIPhones() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum, cloud) = (family.dad, family.mum, family.cloud)
        let second = try await secondPhone(of: dad, named: "dad-2")
        await second.coordinator.resume()
        try await settle(dad, second, mum)
        let (before, hers) = (await cloud.records(in: family.zone, of: "dad"), try await saga(on: mum))
        // Each of his iPhones changes something the other hasn't seen when the zones go.
        try await dad.rename(lena, to: "Ελένη")
        let recorded = try await second.record(nikos, by: .testDad, minute: 5)

        await cloud.resetEncryptedData("dad")
        try await settle(dad, second, mum)

        // The same two zones under the same names, made once, holding what both iPhones had.
        #expect(Set(await cloud.zones(of: "dad")) == [.personal, family.zone])
        let records = await cloud.records(in: family.zone, of: "dad")
        var expected = Set(before.keys)
        // A zone this parent rebuilds carries their own member only: the partner is invited again.
        expected.remove(.member(.partner))
        expected.insert(.entry(recorded.id))
        #expect(Set(records.keys) == expected)
        #expect(records[.child(lena.id)]?["name"] == .string("Ελένη"))
        #expect(records[.entry(family.mumsEntry.id)]?["author"] == .string(UUID.partner.uuidString))
        for phone in [dad, second] {
            #expect(try await phone.children().map(\.name) == ["Ελένη", "Νίκος"])
            #expect(try await phone.entryIDs() == [family.dadsEntry.id, family.mumsEntry.id, recorded.id])
            #expect(try await phone.ledger().pending().isEmpty)
            #expect(await phone.coordinator.status() == ShareStatus(sharing: .alone))
        }
        // For the partner the shared zone went: she keeps everything, in a zone of her own.
        #expect(try await saga(on: mum) == hers)
        #expect(await mum.coordinator.status() == ShareStatus(sharing: .alone))
    }

    @Test("Given `saga` names another family and the parent hasn't answered, then only the family's sync is off on that iPhone")
    func untilItFollowsOnlyTheFamilyWaits() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (dad, _) = try await started("dad", on: cloud)
        let partner = try await partnerAlone(on: cloud)
        let (first, second) = (partner.phone, try await secondPhone(of: partner.phone, named: "mum-2"))
        await second.coordinator.resume()
        let (left, zone) = (try await first.family(), try await dad.family())
        await cloud.share(zone, with: "mum")
        try await first.coordinator.join(zone, childMap: ChildMap(familyIDs: [partner.ownLena.id: lena.id]))
        // As far as `saga`: the zone the first iPhone left is still there.
        try await first.fetch()
        try await first.send()
        try await first.send()
        #expect(await cloud.zones(of: "mum").contains(left))
        try await second.fetch()
        #expect(await second.coordinator.status() == ShareStatus(sharing: .alone, waiting: .followFamily))

        // A third iPhone, stale, still writes into the old zone; and her hero changes on another.
        let renamed = SyncRecord(name: .child(partner.ownLena.id), zone: left, fields: ["name": .string("Παλιά")])
        await cloud.write(renamed, as: "mum")
        await cloud.write(SyncRecord(name: .hero(.partner), zone: .personal, fields: ["beard": .string("full")]), as: "mum")
        try await settle(second)

        // Her own zone goes on: or this iPhone would never see `saga` change.
        #expect(try await second.store.profiles.fetchProfile()?.dadAppearance.beard == .full)
        // The family's doesn't: nothing of the zone it is about to leave comes in, and nothing goes out.
        #expect(try await second.children().map(\.name) == ["Λένα"])
        try await second.rename(partner.ownLena, to: "Ελένη")
        try await settle(second)
        #expect(await cloud.records(in: left, of: "mum")[.child(partner.ownLena.id)]?["name"] == .string("Παλιά"))
        #expect(try await second.ledger().pending().map(\.name) == [.child(partner.ownLena.id)])
        #expect(await second.coordinator.status() == ShareStatus(sharing: .alone, waiting: .followFamily))
    }

    @Test("Given a parent's second iPhone, when the first joins a family, then it asks, follows, and shows no child twice")
    func aSecondIPhoneFollowsAJoin() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (dad, _) = try await started("dad", on: cloud)
        let partner = try await partnerAlone(on: cloud)
        let (first, second) = (partner.phone, try await secondPhone(of: partner.phone, named: "mum-2"))
        await second.coordinator.resume()
        let left = try await first.family()
        let zone = try await dad.family()
        await cloud.share(zone, with: "mum")
        // Recorded on the second iPhone and never sent: it is offline until after the join.
        let offline = try await second.record(partner.ownLena, by: .partner, minute: 9)

        try await first.coordinator.join(zone, childMap: ChildMap(familyIDs: [partner.ownLena.id: lena.id]))
        try await settle(dad, first)
        // The first iPhone's own zone is gone, and `saga` names the family.
        #expect(await cloud.zones(of: "mum") == [.personal])
        try await second.fetch()

        // Asked once, and nothing of the family moves meanwhile: its saga stays as it was.
        #expect(await second.coordinator.status() == ShareStatus(sharing: .alone, waiting: .followFamily))
        #expect(try await second.family() == left)
        #expect(try await second.children() == [partner.ownLena])
        try await settle(second)
        #expect(await cloud.zones(of: "mum") == [.personal])
        #expect(try await second.ledger().pending().map(\.name) == [.entry(offline.id)])

        try await second.coordinator.follow()
        try await settle(dad, first, second)

        // The mapped child became the family's: never shown twice, never read as deleted for good.
        for phone in [first, second] {
            #expect(try await phone.children() == [lena, nikos])
            #expect(try await phone.removedChildren().isEmpty)
            #expect(try await phone.ledger().goneIDs().isEmpty)
            #expect(await phone.offers.answeredOccasionIDs() == ["\(lena.id.uuidString)/birthday/1"])
            #expect(await phone.coordinator.status() == ShareStatus(sharing: .partner))
            #expect(try await phone.ledger().pending().isEmpty)
        }
        let records = await cloud.records(in: zone, of: "dad")
        #expect(records[.child(partner.ownLena.id)] == nil)
        #expect(records[.entry(offline.id)]?["childID"] == .string(lena.id.uuidString))
        #expect(try await dad.store.progress.fetchEvents().first { $0.id == offline.id }?.childID == lena.id)
        #expect(try await second.entryIDs() == (try await first.entryIDs()))
        // The answers follow the child, in the parent's own zone too.
        let personal = await cloud.records(in: .personal, of: "mum")
        #expect(Set(personal.keys.filter { $0.type == .offer }) == [.offer(occasionID: "\(lena.id.uuidString)/birthday/1")])
        #expect(await cloud.zones(of: "mum") == [.personal])
    }
}
