import Foundation
import SwiftData
import Testing
@testable import Data

/// What `Sync.store` keeps of the family (ADR-0065 §2, §4): who its members are, the family `saga` names, and what
/// waits while the saga moves to another zone. On a store on disk.
@Suite("Sync.store's ledger: the family", .serialized)
struct SyncLedgerFamilyTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-ledger-family-" + UUID().uuidString)
    let own = (id: UUID(), owner: "mum")
    let familys = (id: UUID(), owner: "dad")
    let child = RecordName.child(UUID())
    let mine = UUID()

    /// A ledger with iCloud on for `mum`, the family in her own zone, nothing waiting.
    func ledger() async throws -> SyncLedger {
        let directory = directory
        let ledger = try #require(try await SyncStoreConnection(directory: { directory }).open(creating: true))
        try await ledger.turnOn(account: "mum", family: own, token: nil, sending: [], afterFetch: false)
        return ledger
    }

    func fetched(_ name: RecordName, _ fields: [String: SyncValue] = [:], creator: String? = nil) -> SyncRecord {
        SyncRecord(name: name, zone: .personal, fields: fields, systemFields: Data([1]), creator: creator)
    }

    func saga(_ family: (id: UUID, owner: String), map: String? = nil, how: String? = nil) -> SyncRecord {
        var fields: [String: SyncValue] = ["familyZone": .string(family.id.uuidString), "familyOwner": .string(family.owner)]
        fields["childMap"] = map.map(SyncValue.string)
        fields["how"] = how.map(SyncValue.string)
        return fetched(.saga, fields)
    }

    @Test("Given member records, then one counts only when it names the account that created it, until it is deleted")
    func aMemberNamesItsCreator() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()
        let (dad, forged) = (UUID(), UUID())

        try await ledger.fetched(FetchOutcome(records: [
            fetched(.member(dad), ["userRecordName": .string("dad")], creator: "dad"),
            fetched(.member(forged), ["userRecordName": .string("mum")], creator: "dad"),
            fetched(.member(UUID()), [:], creator: "dad")
        ]))
        #expect(try await ledger.members() == [dad: "dad"])

        // Written again by someone else, it no longer counts; this parent's own counts once it is saved.
        try await ledger.fetched(FetchOutcome(records: [fetched(.member(dad), ["userRecordName": .string("dad")], creator: "x")]))
        try await ledger.sent(saved: [fetched(.member(mine))], revisions: [:], deleted: [])
        #expect(try await ledger.members() == [mine: "mum"])

        try await ledger.fetched(FetchOutcome(deleted: [.member(mine)]))
        #expect(try await ledger.members().isEmpty)
    }

    @Test("Given `saga` naming another family, then it is kept to follow, with its map and how; the same family ends that")
    func sagaNamingAnotherFamilyIsFollowed() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()

        try await ledger.fetched(FetchOutcome(records: [saga(familys, map: "{}", how: "replace")]))

        let follow = try #require(try await ledger.settings().follow)
        #expect(follow.zone == .family(familys.id, owner: "dad"))
        #expect(follow.childMap == Data("{}".utf8))
        #expect(!follow.merges)
        #expect(try await ledger.settings().familyWaits)
        #expect(try await ledger.settings().familyZone == .family(own.id, owner: "mum"))

        try await ledger.fetched(FetchOutcome(records: [saga(familys)]))
        #expect(try await ledger.settings().follow?.merges == true)
        try await ledger.fetched(FetchOutcome(records: [saga(own)]))
        #expect(try await ledger.settings().follow == nil)
        // A `saga` that names no family is not one to follow.
        try await ledger.fetched(FetchOutcome(records: [fetched(.saga, ["familyOwner": .string("dad")])]))
        #expect(try await ledger.settings().follow == nil)
    }

    @Test("Given this iPhone's own `saga` still to be written, when the zone's old one comes, then it is not followed")
    func theSagaAboutToBeReplacedIsNotFollowed() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()
        try await ledger.attach(family: familys, map: ChildMap(), writingSaga: true)

        // Until the family's zone holds what waited, `saga` in iCloud names the zone this iPhone left.
        try await ledger.fetched(FetchOutcome(records: [saga(own)]))
        #expect(try await ledger.settings().follow == nil)

        try await ledger.fullSend([], writingAgain: [])
        #expect(try await ledger.familySent())
        #expect(try await ledger.pending().map(\.name) == [.saga])
        try await ledger.fetched(FetchOutcome(records: [saga(own)]))
        #expect(try await ledger.settings().follow == nil)
        #expect(try await ledger.familySent() == false)
    }

    @Test("Given a join, then what waited still waits, nothing kept of the old zone stays, and `saga` waits for the family")
    func attachingKeepsWhatWaits() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()
        let map = ChildMap(familyIDs: [UUID(): UUID()])
        try await ledger.sent(saved: [fetched(child), fetched(.hero(mine)), fetched(.member(mine))], revisions: [:], deleted: [])
        try await ledger.store(engineState: Data([1]), for: .private)
        try await ledger.store(engineState: Data([2]), for: .shared)
        try await ledger.record([.save(child, fields: ["name"])])

        try await ledger.attach(family: familys, map: map, writingSaga: true)

        let settings = try await ledger.settings()
        #expect(settings.familyZone == .family(familys.id, owner: "dad"))
        #expect(settings.oldFamilyZoneID == own.id)
        #expect(settings.fullSendAfterFetch && settings.sagaWaitsForFamily && settings.childMapWaits)
        #expect(settings.childMap == map)
        #expect(try await ledger.pending().map(\.fields) == [["name"]])
        #expect(try await ledger.heldNames(.family).isEmpty)
        #expect(try await ledger.members().isEmpty)
        // Her own zone is as it was: its records and its engine carry on; the partner's database starts from nothing.
        #expect(try await ledger.systemFields(of: .hero(mine)) != nil)
        #expect(try await ledger.engineState(.private) == Data([1]))
        #expect(try await ledger.engineState(.shared) == nil)
        // `saga` only once nothing waits for the family.
        #expect(try await ledger.familySent() == false)
        try await ledger.fullSend([child], writingAgain: [])
        #expect(try await ledger.familySent() == false)
        try await ledger.sent(saved: [fetched(child)], revisions: [child: 2], deleted: [])
        #expect(try await ledger.familySent())
    }

    @Test("Given a record that goes whole because the zone lacked it, then only the fields the dad changed are left alone")
    func aWholeSaveStillKnowsWhatTheDadChanged() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()
        let (edited, untouched, added) = (child, RecordName.child(UUID()), RecordName.child(UUID()))
        try await ledger.record([.save(edited, fields: ["name"]), .save(added, fields: nil)])

        try await ledger.send(neverSent: [edited, untouched, added])

        #expect(try await ledger.pending().map(\.fields) == [nil, nil, nil])
        let waiting = try await ledger.waitingFields(for: [edited, untouched, added])
        #expect(waiting[edited] == ["name"])
        #expect(waiting[untouched] == [])
        #expect(waiting[added] == SyncField.Child.all)
    }

    @Test("Given a record to write again, then it is deleted first, and its save follows the deletion")
    func writingAgainDeletesThenSaves() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()
        let member = RecordName.member(mine)
        try await ledger.fetched(FetchOutcome(records: [fetched(member, ["userRecordName": .string("mum")], creator: "dad")]))

        try await ledger.fullSend([member], writingAgain: [member])

        var pending = try await ledger.pending()
        #expect(pending.map(\.isDeletion) == [true])
        // A save asked for meanwhile changes nothing: the record is saved once it is gone.
        try await ledger.send(neverSent: [member])
        #expect(try await ledger.pending().map(\.isDeletion) == [true])

        try await ledger.sent(saved: [], revisions: [:], deleted: [member])

        pending = try await ledger.pending()
        #expect(pending.map(\.isDeletion) == [false])
        #expect(pending.map(\.fields) == [nil])
        #expect(try await ledger.systemFields(of: member) == nil)
        try await ledger.sent(saved: [fetched(member)], revisions: [member: pending[0].revision], deleted: [])
        #expect(try await ledger.pending().isEmpty)
        #expect(try await ledger.members() == [mine: "mum"])
    }

    @Test("Given a rebuild, then every record goes whole into a zone of this parent's own, and `saga` after them")
    func rebuildingSendsEverything() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = try await ledger()
        try await ledger.attach(family: familys, map: ChildMap(), writingSaga: false)
        try await ledger.fullSend([], writingAgain: [])
        let dads = fetched(.member(UUID()), ["userRecordName": .string("dad")], creator: "dad")
        try await ledger.fetched(FetchOutcome(records: [fetched(child), dads]))
        try await ledger.record([.delete(.entry(UUID())), .save(child, fields: ["name"])])
        let zone = UUID()

        try await ledger.rebuild(family: zone, sending: [.member(mine), child])

        let settings = try await ledger.settings()
        #expect(settings.familyZone == .family(zone, owner: "mum"))
        #expect(settings.database(for: .family) == .private)
        #expect(try await ledger.pending().map(\.name) == [child, .member(mine)])
        #expect(try await ledger.pending().map(\.fields) == [nil, nil])
        #expect(try await ledger.heldNames(.family).isEmpty)
        #expect(try await ledger.members().isEmpty)
        #expect(settings.sagaWaitsForFamily)
    }
}
