import Foundation
import Testing
@testable import Data

/// The fake iCloud's own rules (ADR-0065 §8), so no sync test passes on a fake that answers wrongly: change tags, the
/// answers to a stale save and to a new record over an existing one, zones made again, quotas, fetches from a token
/// and from none, sharing, and the three ways a zone goes.
@Suite("The fake iCloud")
struct FakeCloudTests {
    let cloud = FakeCloud(downloads: FileManager.default.temporaryDirectory.appending(path: "dadsaga-cloud-" + UUID().uuidString))
    let family = SyncZone.family(UUID(), owner: "dad")
    let child = RecordName.child(UUID())

    /// One record saved by `account` through its private database, or the shared one for a zone that isn't its own.
    func save(
        _ name: RecordName, _ fields: [String: SyncValue], on systemFields: Data? = nil, as account: String = "dad"
    ) async -> SentRecords {
        let record = SyncRecord(name: name, zone: family, fields: fields, systemFields: systemFields)
        return await cloud.modify(SyncBatch(saves: [record]), as: account, in: account == "dad" ? .private : .shared)
    }

    @Test("Given a saved record, when it is saved again on its system fields, then only the fields sent change")
    func aSaveSetsItsFieldsAndTheTagGrows() async throws {
        await cloud.saveZone(family, as: "dad")
        let first = try #require(await save(child, ["name": .string("Λένα"), "order": .int(0)]).saved.first)

        let second = await save(child, ["name": .string("Ελένη"), "order": .cleared], on: first.systemFields)

        #expect(second.failed.isEmpty)
        #expect(second.saved.first?.systemFields != first.systemFields)
        #expect(await cloud.records(in: family, of: "dad") == [child: ["name": .string("Ελένη")]])
    }

    @Test("Given a record saved since, when a save comes on older system fields, then the server's record comes back whole")
    func aStaleSaveGetsTheServersRecord() async throws {
        await cloud.saveZone(family, as: "dad")
        let first = try #require(await save(child, ["name": .string("Λένα")]).saved.first)
        let second = try #require(await save(child, ["order": .int(1)], on: first.systemFields).saved.first)

        let stale = await save(child, ["name": .string("Λ")], on: first.systemFields)

        let server = SyncRecord(
            name: child, zone: family, fields: ["name": .string("Λένα"), "order": .int(1)],
            systemFields: second.systemFields, creator: "dad"
        )
        #expect(stale.failed.map(\.error) == [.serverRecordChanged(server)])
        #expect(await cloud.records(in: family, of: "dad")[child]?["name"] == .string("Λένα"))
    }

    @Test("Given a record in the zone, when a new record is saved under its name, then the server's record comes back")
    func aNewRecordOverAnExistingNameIsAConflict() async throws {
        await cloud.saveZone(family, as: "dad")
        _ = await save(child, ["name": .string("Λένα")])

        let again = await save(child, ["name": .string("Άλλη")])

        guard case .serverRecordChanged(let server)? = again.failed.first?.error else {
            Issue.record("The save didn't meet the record that was there")
            return
        }
        #expect(server.fields == ["name": .string("Λένα")])
    }

    @Test("Given a record deleted, or its zone made again, when a save comes on old system fields, then unknownItem")
    func staleSystemFieldsNameNothing() async throws {
        await cloud.saveZone(family, as: "dad")
        let first = try #require(await save(child, ["name": .string("Λένα")]).saved.first)

        await cloud.delete(child, in: family, as: "dad")
        #expect(await save(child, ["name": .string("Λ")], on: first.systemFields).failed.map(\.error) == [.unknownItem])

        // The zone made again, and the record written into it by another iPhone: the old system fields are another
        // zone's.
        await cloud.deleteZone(family, by: "dad")
        await cloud.write(SyncRecord(name: child, zone: family, fields: ["name": .string("Νέα")]), as: "dad")
        #expect(await save(child, ["name": .string("Λ")], on: first.systemFields).failed.map(\.error) == [.unknownItem])
    }

    @Test("Given no such zone, when a record is saved or deleted, then zoneNotFound; a missing record deletes fine")
    func aMissingZoneAndAMissingRecord() async {
        #expect(await save(child, ["name": .string("Λένα")]).failed.map(\.error) == [.zoneNotFound])
        let deletion = SyncChange.delete(child, family)
        let refused = await cloud.modify(SyncBatch(deletions: [deletion]), as: "dad", in: .private)
        #expect(refused.failedDeletions.map(\.error) == [.zoneNotFound])

        await cloud.saveZone(family, as: "dad")
        #expect(await cloud.modify(SyncBatch(deletions: [deletion]), as: "dad", in: .private).deleted == [deletion])
    }

    @Test("Given a zone shared with the partner, when the owner's iCloud is full, then the partner's save is refused")
    func aPartnersSavesCountInTheOwnersQuota() async {
        await cloud.saveZone(family, as: "dad")
        await cloud.share(family, with: "partner")
        _ = await save(child, ["name": .string("Λένα")])
        await cloud.setQuota("dad", bytes: await cloud.usage(of: "dad") + 10)

        let entry = RecordName.entry(UUID())
        let long = await save(entry, ["note": .string("ένα μακρύ σημείωμα")], as: "partner")
        #expect(long.failed.map(\.error) == [.quotaExceeded])
        #expect(await save(entry, ["note": .string("ok")], as: "partner").failed.isEmpty)
        #expect(await cloud.records(in: family, of: "dad")[entry] == ["note": .string("ok")])
    }

    @Test("Given changes since a token, when the zone is fetched, then only they come; from none, every record, no deletion")
    func fetchingFromATokenAndFromNone() async throws {
        await cloud.saveZone(family, as: "dad")
        let entry = RecordName.entry(UUID())
        _ = await save(child, ["name": .string("Λένα")])
        _ = await save(entry, ["note": .string("x")])
        let first = try #require(await cloud.recordChanges(in: family, for: "dad", .private, since: nil))
        #expect(first.modified.map(\.name) == [child, entry])

        await cloud.write(SyncRecord(name: child, zone: family, fields: ["order": .int(2)]), as: "dad")
        await cloud.delete(entry, in: family, as: "dad")

        let next = try #require(await cloud.recordChanges(in: family, for: "dad", .private, since: first.token))
        #expect(next.modified.map(\.fields) == [["name": .string("Λένα"), "order": .int(2)]])
        #expect(next.deleted == [entry])
        let scratch = try #require(await cloud.recordChanges(in: family, for: "dad", .private, since: nil))
        #expect(scratch.modified.map(\.name) == [child])
        #expect(scratch.deleted.isEmpty)
        let last = try #require(await cloud.recordChanges(in: family, for: "dad", .private, since: next.token))
        #expect(last.modified.isEmpty)
    }

    @Test("Given a zone shared and then not, when the partner's database is read, then it appears and then goes, deleted")
    func sharingAndStopping() async {
        await cloud.saveZone(family, as: "dad")
        let start = await cloud.zoneChanges(for: "partner", in: .shared, since: nil)
        #expect(start.appeared.isEmpty)

        await cloud.share(family, with: "partner")
        let shared = await cloud.zoneChanges(for: "partner", in: .shared, since: start.token)
        #expect(shared.appeared == [family])
        #expect(await save(RecordName.entry(UUID()), ["note": .string("x")], as: "partner").failed.isEmpty)

        await cloud.stopSharing(family)
        let stopped = await cloud.zoneChanges(for: "partner", in: .shared, since: shared.token)
        #expect(stopped.deleted == [ZoneDeletion(zone: family, reason: .deleted)])
        #expect(await save(child, ["name": .string("Λένα")], as: "partner").failed.map(\.error) == [.zoneNotFound])
        // The owner keeps the zone and what the partner wrote.
        #expect(await cloud.records(in: family, of: "dad").count == 1)
    }

    @Test(
        "Given zones in an account, when they go, then each of its iPhones learns why, and a partner too",
        arguments: [ZoneDeletionReason.deleted, .purged, .encryptedDataReset]
    )
    func zonesGoForAReason(_ reason: ZoneDeletionReason) async {
        await cloud.saveZone(.personal, as: "dad")
        await cloud.saveZone(family, as: "dad")
        await cloud.share(family, with: "partner")
        let own = await cloud.zoneChanges(for: "dad", in: .private, since: nil)
        let partners = await cloud.zoneChanges(for: "partner", in: .shared, since: nil)
        #expect(Set(own.appeared) == [.personal, family])

        switch reason {
        case .deleted: await cloud.deleteZone(family, by: "dad")
        case .purged: await cloud.purge("dad")
        case .encryptedDataReset: await cloud.resetEncryptedData("dad")
        }

        // Deleting one zone leaves Personal; a purge and a reset take every zone of the account.
        let gone = reason == .deleted ? [family] : [.personal, family]
        let after = await cloud.zoneChanges(for: "dad", in: .private, since: own.token)
        #expect(Set(after.deleted) == Set(gone.map { ZoneDeletion(zone: $0, reason: reason) }))
        #expect(await cloud.zoneChanges(for: "partner", in: .shared, since: partners.token).deleted
            == [ZoneDeletion(zone: family, reason: reason)])
        #expect(await cloud.zones(of: "dad").count == 2 - gone.count)
    }

    @Test("Given a record the partner created, when the owner changes it, then its creator is still the partner")
    func theCreatorIsKept() async throws {
        await cloud.saveZone(family, as: "dad")
        await cloud.share(family, with: "partner")
        let member = RecordName.member(UUID())
        let created = try #require(await save(member, ["userRecordName": .string("partner")], as: "partner").saved.first)

        #expect(await save(member, ["userRecordName": .string("dad")], on: created.systemFields).failed.isEmpty)

        #expect(await cloud.record(member, in: family, of: "dad")?.creator == "partner")
    }
}
