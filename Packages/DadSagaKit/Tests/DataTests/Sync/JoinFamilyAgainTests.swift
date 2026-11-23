import Application
import Domain
import Foundation
import Testing
@testable import Data

/// Joining a family again, and what a partner's iPhones do when sharing stops (ADR-0065 §2, §4, §8): the same id is
/// the same child or entry, no row stays on one iPhone only, and `saga` names one zone for all of a parent's iPhones.
@Suite("Joining a family again, and after sharing stops", .serialized)
struct JoinFamilyAgainTests: SyncBench {
    let root = FileManager.default.temporaryDirectory.appending(path: "dadsaga-rejoin-" + UUID().uuidString)
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)

    @Test("Given sharing stopped and each went on alone, when the partner joins again, then the same ids, nothing doubled")
    func rejoiningAfterAStop() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum, cloud) = (family.dad, family.mum, family.cloud)
        await cloud.stopSharing(family.zone)
        try await settle(dad, mum)
        let alone = try await mum.family()
        let hers = try await mum.record(nikos, by: .partner, minute: 1)
        let his = try await dad.record(lena, by: .testDad, minute: 2)
        try await dad.rename(nikos, to: "Νικόλας")
        try await settle(dad, mum)

        await cloud.share(family.zone, with: "mum")
        try await mum.coordinator.join(family.zone, childMap: ChildMap())
        try await settle(dad, mum)

        let everyone: Set = [family.dadsEntry.id, family.mumsEntry.id, hers.id, his.id]
        for phone in [dad, mum] {
            #expect(try await phone.children().map(\.name) == ["Λένα", "Νικόλας"])
            #expect(try await phone.entryIDs() == everyone)
            #expect(try await phone.store.progress.fetchEvents().count == 4)
            #expect(try await phone.ledger().pending().isEmpty)
        }
        let records = await cloud.records(in: family.zone, of: "dad")
        #expect(records.keys.filter { $0.type == .child }.count == 2)
        #expect(records.keys.filter { $0.type == .entry }.count == 4)
        #expect(records.keys.filter { $0.type == .member }.count == 2)
        // The zone she kept everything in while apart is gone, and `saga` names the family again.
        #expect(await cloud.zones(of: "mum") == [.personal])
        #expect(alone != family.zone)
        #expect(await saga(of: "mum", on: cloud)?["familyOwner"] == .string("dad"))
        #expect(await mum.coordinator.status() == ShareStatus(sharing: .partner))
    }

    @Test("Given the owner's encrypted data was reset, when the partner joins again, then one family, nothing doubled")
    func rejoiningAfterAnEncryptedDataReset() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum, cloud) = (family.dad, family.mum, family.cloud)
        await cloud.resetEncryptedData("dad")
        try await settle(dad, mum)
        #expect(await dad.coordinator.status() == ShareStatus(sharing: .alone))

        await cloud.share(family.zone, with: "mum")
        try await mum.coordinator.join(family.zone, childMap: ChildMap())
        try await settle(dad, mum)

        for phone in [dad, mum] {
            #expect(try await phone.children() == [lena, nikos])
            #expect(try await phone.store.progress.fetchEvents() == [family.dadsEntry, family.mumsEntry])
        }
        let records = await cloud.records(in: family.zone, of: "dad")
        #expect(records.count == 7)
        #expect(records[.member(.partner)] == ["userRecordName": .string("mum")])
        #expect(await cloud.zones(of: "mum") == [.personal])
        #expect(await dad.coordinator.status() == ShareStatus(sharing: .owner))
        #expect(await mum.coordinator.status() == ShareStatus(sharing: .partner))
    }

    @Test("Given a rejoin, then a member's entry the family lacks is deleted here; an earlier partner's and her own are sent")
    func theRejoinRuleForEntriesTheFamilyLacks() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum, cloud) = (family.dad, family.mum, family.cloud)
        await cloud.stopSharing(family.zone)
        try await settle(dad, mum)
        // While apart: the dad deletes his entry; she records one, and holds one by a partner of an earlier time.
        try await dad.store.progress.delete(id: family.dadsEntry.id)
        let hers = try await mum.record(nikos, by: .partner, minute: 1)
        let earlier = try await mum.record(nikos, by: UUID(), minute: 2)
        try await settle(dad, mum)
        let title = try await mum.home().standing.title?.id

        await cloud.share(family.zone, with: "mum")
        try await mum.coordinator.join(family.zone, childMap: ChildMap())
        try await settle(dad, mum)

        // His deletion is his: no row stays on her iPhone only, and its photo's file goes with it.
        let kept: Set = [family.mumsEntry.id, hers.id, earlier.id]
        #expect(try await mum.entryIDs() == kept)
        #expect(try await mum.photos.storedPhotos().isEmpty)
        #expect(try await dad.entryIDs() == kept)
        let records = await cloud.records(in: family.zone, of: "dad")
        #expect(records[.entry(family.dadsEntry.id)] == nil)
        #expect(records[.entry(earlier.id)]?["author"] == .string(earlier.authorID.uuidString))
        // Nothing of hers changed by it.
        #expect(try await mum.home().standing.title?.id == title)
        #expect(try await mum.ledger().pending().isEmpty)
    }

    @Test("Given a rejoin whose whole fetch has a batch that isn't applied, then no entry goes, and the next launch finishes it")
    func aRejoinWithAnUnappliedBatch() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let content = UnreadableContent()
        let family = try await family(on: makeCloud(), content: content)
        let (dad, mum, cloud) = (family.dad, family.mum, family.cloud)
        for minute in 0..<150 { try await dad.record(nikos, by: .testDad, minute: 10 + minute) }
        try await settle(dad, mum)
        let before = try await mum.entryIDs()
        #expect(before.count == 152)
        await cloud.stopSharing(family.zone)
        try await settle(dad, mum)

        await cloud.share(family.zone, with: "mum")
        try await mum.coordinator.join(family.zone, childMap: ChildMap())
        // The zone comes in batches of a hundred records: the second one can't be applied.
        await content.failRead(2)
        try await mum.fetch()

        // The zone wasn't fetched whole, so the rejoin's rule decides nothing yet: the dad's entries that batch
        // carried are not his deletions.
        #expect(try await mum.entryIDs() == before)
        #expect(try await mum.photos.storedPhotos().map(\.id) == family.dadsEntry.photoIDs)
        #expect(try await mum.ledger().settings().fullSendAfterFetch)

        let again = mum.relaunched()
        await again.coordinator.resume()
        try await settle(dad, again)

        for phone in [dad, again] {
            #expect(try await phone.entryIDs() == before)
            #expect(try await phone.ledger().pending().isEmpty)
        }
        #expect(await again.coordinator.status() == ShareStatus(sharing: .partner))
    }

    @Test("Given a join that replaced an engine, when the old one reports its fetch ended, then the rejoin's rule waits")
    func aReplacedEnginesFetchDecidesNothing() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum, cloud) = (family.dad, family.mum, family.cloud)
        let everyone: Set = [family.dadsEntry.id, family.mumsEntry.id]
        let replaced = try #require(mum.device.engine(.shared))

        // She opens the invitation once more: the family's zone is fetched whole again, by a new engine.
        try await mum.coordinator.join(family.zone, childMap: ChildMap())
        let engine = try #require(mum.device.engine(.shared))
        // Its fetch has brought only the members so far when the engine it replaced reports a fetch of its own ended.
        var members: [SyncRecord] = []
        for profileID in [UUID.testDad, .partner] {
            members.append(try #require(await cloud.record(.member(profileID), in: family.zone, of: "dad")))
        }
        await mum.coordinator.handle(.fetchedRecords(modified: members, deleted: []), from: engine.id)
        await mum.coordinator.handle(.didFetchChanges, from: replaced.id)

        // That fetch says nothing of the zone: the dad's entry, not fetched yet, is not his deletion.
        #expect(try await mum.entryIDs() == everyone)
        #expect(try await mum.photos.storedPhotos().map(\.id) == family.dadsEntry.photoIDs)
        #expect(try await mum.ledger().settings().fullSendAfterFetch)

        try await settle(dad, mum)
        for phone in [dad, mum] {
            #expect(try await phone.entryIDs() == everyone)
            #expect(try await phone.ledger().pending().isEmpty)
        }
    }

    @Test("Given both of the partner's iPhones when sharing stops, then one makes the zone, and the other asks and follows it")
    func twoIPhonesOfThePartnerAfterAStop() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum, cloud) = (family.dad, family.mum, family.cloud)
        let second = try await secondPhone(of: mum, named: "mum-2")
        await second.coordinator.resume()
        try await settle(dad, mum, second)
        let offline = try await second.record(nikos, by: .partner, minute: 7)

        await cloud.stopSharing(family.zone)
        try await settle(dad, mum)
        let own = try await mum.family()
        try await second.fetch()

        // `saga` already names the zone her first iPhone made: the second makes none of its own.
        #expect(await second.coordinator.status() == ShareStatus(sharing: .partner, waiting: .followFamily))
        #expect(Set(await cloud.zones(of: "mum")) == [.personal, own])

        try await second.coordinator.follow()
        try await settle(dad, mum, second)

        #expect(try await second.family() == own)
        #expect(Set(await cloud.zones(of: "mum")) == [.personal, own])
        let everyone: Set = [family.dadsEntry.id, family.mumsEntry.id, offline.id]
        #expect(try await mum.entryIDs() == everyone)
        #expect(try await second.entryIDs() == everyone)
        #expect(await second.coordinator.status() == ShareStatus(sharing: .alone))
        #expect(try await second.ledger().pending().isEmpty)
    }

    @Test("Given both of the partner's iPhones make a zone at once when sharing stops, then one follows the other, nothing lost")
    func twoIPhonesRebuildAtOnce() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum, cloud) = (family.dad, family.mum, family.cloud)
        let second = try await secondPhone(of: mum, named: "mum-2")
        await second.coordinator.resume()
        try await settle(dad, mum, second)
        let onFirst = try await mum.record(lena, by: .partner, minute: 3)
        let onSecond = try await second.record(nikos, by: .partner, minute: 7)
        await cloud.stopSharing(family.zone)

        // Each learns of the stop before the other's `saga` is written: each keeps everything in a zone it makes.
        try await mum.fetch()
        try await second.fetch()
        try await settle(dad, mum, second)

        // `saga` can name only one: the iPhone whose zone it doesn't name asks to follow.
        let waiting = await [mum, second].asyncFilter { await $0.coordinator.status().waiting == .followFamily }
        #expect(waiting.count == 1)
        try await waiting.first?.coordinator.follow()
        try await settle(dad, mum, second)

        #expect(try await mum.family() == (try await second.family()))
        let everyone: Set = [family.dadsEntry.id, family.mumsEntry.id, onFirst.id, onSecond.id]
        let records = await cloud.records(in: try await mum.family(), of: "mum")
        #expect(Set(records.keys.filter { $0.type == .entry }) == Set(everyone.map(RecordName.entry)))
        for phone in [mum, second] {
            #expect(try await phone.entryIDs() == everyone)
            #expect(try await phone.children() == [lena, nikos])
            #expect(await phone.coordinator.status() == ShareStatus(sharing: .alone))
            #expect(try await phone.ledger().pending().isEmpty)
        }
    }
}
