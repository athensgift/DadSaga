import Domain
import Foundation
import Testing
@testable import Data

/// Which fields of a record that came reach the row (ADR-0065 §4): every one but those whose local change waits, a
/// kept title only upwards, and nothing this version can't hold.
@Suite("Merging a record that came, field by field")
struct FieldMergeTests {
    let zone = SyncZone.family(UUID(), owner: "_owner")
    let child = RecordName.child(UUID())
    let stored: [String: SyncValue] = [
        "name": .string("Λένα"), "gender": .string("girl"), "skinTone": .string("light"), "order": .int(0),
        "isRemoved": .bool(false), "birthDay": .string("2025-06-02")
    ]

    func hero(holding stored: String?, arriving: SyncValue, waiting: Set<String> = []) -> [String: SyncValue] {
        FieldMerge.fieldsToSet(
            SyncRecord(name: .hero(.testDad), zone: .personal, fields: ["heldTitleID": arriving]),
            stored: ["heldTitleID": stored.map(SyncValue.string) ?? .cleared], waiting: waiting, catalog: .threeTitles
        )
    }

    @Test("Given a tone change waiting, when a record comes with a name and a tone, then only the name is set")
    func waitingFieldsAreLeft() {
        let incoming = SyncRecord(name: child, zone: zone, fields: ["name": .string("Ελένη"), "skinTone": .string("dark")])

        let fields = FieldMerge.fieldsToSet(incoming, stored: stored, waiting: ["skinTone"], catalog: .threeTitles)

        #expect(fields == ["name": .string("Ελένη")])
    }

    @Test("Given nothing waiting, when a record comes, then every field that differs is set, and no equal one")
    func onlyValuesThatDiffer() {
        let incoming = SyncRecord(name: child, zone: zone, fields: [
            "name": .string("Λένα"), "order": .int(2), "isRemoved": .bool(true), "birthDay": .cleared,
            "gender": .string("girl")
        ])

        let fields = FieldMerge.fieldsToSet(incoming, stored: stored, waiting: [], catalog: .threeTitles)

        #expect(fields == ["order": .int(2), "isRemoved": .bool(true), "birthDay": .cleared])
        #expect(FieldMerge.fieldsToSet(
            SyncRecord(name: child, zone: zone, fields: stored), stored: stored, waiting: [], catalog: .threeTitles
        ).isEmpty)
    }

    @Test("Given no row, when a record comes, then every field this version holds is set")
    func aNewRowTakesEveryField() {
        let incoming = SyncRecord(name: child, zone: zone, fields: stored)

        #expect(FieldMerge.fieldsToSet(incoming, stored: nil, waiting: [], catalog: .threeTitles) == stored)
    }

    @Test("Given a kept title, when a higher one comes it is taken, and a lower one never is, whatever waits")
    func aKeptTitleOnlyGoesUp() {
        #expect(hero(holding: "t1", arriving: .string("t2")) == ["heldTitleID": .string("t2")])
        #expect(hero(holding: "t2", arriving: .string("t1")).isEmpty)
        #expect(hero(holding: "t1", arriving: .string("t1")).isEmpty)
        #expect(hero(holding: nil, arriving: .string("t0")) == ["heldTitleID": .string("t0")])
        // Time doesn't decide it: a local keep that waits doesn't hold a higher one back, and is never lowered.
        #expect(hero(holding: "t1", arriving: .string("t2"), waiting: ["heldTitleID"]) == ["heldTitleID": .string("t2")])
        #expect(hero(holding: "t2", arriving: .string("t1"), waiting: ["heldTitleID"]).isEmpty)
    }

    @Test("Given a kept title this version doesn't know, it is never replaced; one that comes is taken; nil never wins")
    func unknownAndMissingTitles() {
        #expect(hero(holding: "t-newer", arriving: .string("t2")).isEmpty)
        #expect(hero(holding: "t1", arriving: .string("t-newer")) == ["heldTitleID": .string("t-newer")])
        #expect(hero(holding: "t1", arriving: .cleared).isEmpty)
        #expect(hero(holding: nil, arriving: .cleared).isEmpty)
    }

    @Test("Given a closed card's title, when another comes, then the later save wins, nil too")
    func theSeenTitleIsAnOrdinaryField() {
        func seen(arriving: SyncValue) -> [String: SyncValue] {
            FieldMerge.fieldsToSet(
                SyncRecord(name: .hero(.testDad), zone: .personal, fields: ["seenTitleID": arriving]),
                stored: ["seenTitleID": .string("t2")], waiting: [], catalog: .threeTitles
            )
        }

        #expect(seen(arriving: .string("t1")) == ["seenTitleID": .string("t1")])
        #expect(seen(arriving: .cleared) == ["seenTitleID": .cleared])
    }

    @Test("Given a field this version doesn't map, or a value its column can't hold, then it is left out")
    func whatThisVersionCantHoldIsLeftOut() {
        let incoming = SyncRecord(name: child, zone: zone, fields: [
            "nickname": .string("Λενάκι"), "gone": .bool(false), "name": .cleared, "order": .string("2"),
            "isRemoved": .int(1), "birthDay": .string("2025-02-30"), "gender": .string("a-newer-gender")
        ])

        let fields = FieldMerge.fieldsToSet(incoming, stored: stored, waiting: [], catalog: .threeTitles)

        // A value this version doesn't know is still a string its column holds.
        #expect(fields == ["gender": .string("a-newer-gender")])
        let entry = SyncRecord(name: .entry(UUID()), zone: zone, fields: [
            "author": .string("not-a-uuid"), "childID": .string(UUID.partner.uuidString), "photoIDs": .string("a"),
            "date": .string("yesterday"), "note": .cleared
        ])
        #expect(FieldMerge.fieldsToSet(entry, stored: nil, waiting: [], catalog: .threeTitles) == [
            "childID": .string(UUID.partner.uuidString), "note": .cleared
        ])
    }

    @Test("Given a record of a kind that mirrors no row, then nothing is set")
    func recordsThatAreNotRows() {
        let member = SyncRecord(name: .member(.partner), zone: zone, fields: ["userRecordName": .string("_partner")])

        #expect(FieldMerge.fieldsToSet(member, stored: nil, waiting: [], catalog: .threeTitles).isEmpty)
    }

    @Test("Given the server's child is gone, then a save onto it is dropped; any other record is applied, then sent again")
    func aSaveOntoAGoneChildIsDropped() {
        let gone = ChildRecord.goneRecord(childID: UUID(), zones: SyncZones(family: zone))
        let renamed = SyncRecord(name: child, zone: zone, fields: ["name": .string("Ελένη"), "gone": .bool(false)])
        // Only a child is ever gone.
        let entry = SyncRecord(name: .entry(UUID()), zone: zone, fields: ["gone": .bool(true)])

        #expect(FieldMerge.resolve(server: gone) == .drop)
        // A local `gone` meets a record still there: it is sent again, and clears every other field.
        #expect(FieldMerge.resolve(server: renamed) == .applyThenResend)
        #expect(FieldMerge.resolve(server: entry) == .applyThenResend)
    }
}
