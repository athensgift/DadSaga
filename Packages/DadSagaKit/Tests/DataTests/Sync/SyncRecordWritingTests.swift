import Foundation
import Testing
@testable import Data

/// Fields that came, into the rows that mirror them (ADR-0065 §1): the other way of `SyncRecordRowsTests`. Every field
/// a row sends, it can also take, and a record that lacks what a row needs makes none.
@Suite("Sync records into rows")
struct SyncRecordWritingTests {
    let zones = SyncZones(family: .family(UUID(), owner: "_owner"))

    /// `row` after taking every field of `other`: it must then send what `other` sends.
    func taking<Row: SyncedRow>(_ other: Row, into row: Row) -> [String: SyncValue] {
        row.set(other.syncFields)
        return row.syncFields
    }

    @Test("Given two rows of each kind, when one takes every field of the other, then it sends the same fields")
    func everyFieldBothWays() {
        let hero = ProfileRecord(
            profileID: UUID(), heroClassID: "h-chef", dadSkinTone: "mediumDark", hairStyle: "curly", hairColor: "grey",
            beard: "full", glasses: "round", hasPartner: true
        )
        hero.heldTitleID = "t2"
        hero.seenTitleID = "t1"
        let plainHero = ProfileRecord(
            profileID: UUID(), heroClassID: "h-cool", dadSkinTone: "light", hairStyle: "short", hairColor: "black",
            beard: "none", glasses: "none", hasPartner: false
        )
        let child = ChildRecord(
            childID: UUID(), name: "Λένα", birthYear: 2024, birthMonth: 3, birthDay: 1, gender: "girl", skinTone: "light",
            order: 2, isRemoved: true
        )
        let unborn = ChildRecord(
            childID: UUID(), name: "Νίκος", birthYear: nil, birthMonth: nil, birthDay: nil, gender: "boy",
            skinTone: "dark", order: 0, isRemoved: false
        )
        let entry = ProgressEventRecord(
            eventID: UUID(), authorID: UUID(), kind: "first", contentID: "f-smile", childID: UUID(),
            date: Date(timeIntervalSince1970: 1_750_000_000.5), note: "Χαμόγελο", photoIDs: ["b", "a"]
        )
        let bare = ProgressEventRecord(
            eventID: UUID(), authorID: UUID(), kind: "quest", contentID: "q1", childID: UUID(), date: .distantPast,
            note: nil, photoIDs: []
        )
        let (hidden, mug) = (OutfitRecord(skill: "care", choice: "hidden"), OutfitRecord(skill: "care", choice: "item:g-mug"))

        #expect(taking(hero, into: plainHero) == hero.syncFields)
        #expect(taking(child, into: unborn) == child.syncFields)
        #expect(taking(entry, into: bare) == entry.syncFields)
        #expect(taking(mug, into: hidden) == mug.syncFields)
        // And back to nil: a title's card not closed, a child not born, an entry with no note.
        hero.set(["seenTitleID": .cleared])
        child.set(["birthDay": .cleared])
        entry.set(["note": .cleared, "photoIDs": .strings([])])
        #expect(hero.seenTitleID == nil)
        #expect((child.birthYear, child.birthMonth, child.birthDay) == (nil, nil, nil))
        #expect((entry.note, entry.photoIDs) == (nil, []))
    }

    @Test("Given every field a row sends, then its column is said to hold the value, and no field is without a kind")
    func everyFieldHasItsKind() {
        let rows: [(RecordType, [String: SyncValue])] = [
            (.hero, ProfileRecord(
                profileID: UUID(), heroClassID: "h", dadSkinTone: "light", hairStyle: "short", hairColor: "black",
                beard: "none", glasses: "none", hasPartner: false
            ).syncFields),
            (.child, ChildRecord(
                childID: UUID(), name: "Λένα", birthYear: 2024, birthMonth: 3, birthDay: 1, gender: "girl",
                skinTone: "light", order: 2, isRemoved: true
            ).syncFields),
            (.entry, ProgressEventRecord(
                eventID: UUID(), authorID: UUID(), kind: "first", contentID: "f", childID: UUID(), date: .now, note: nil,
                photoIDs: ["a"]
            ).syncFields),
            (.wardrobe, OutfitRecord(skill: "care", choice: "hidden").syncFields)
        ]

        for (type, fields) in rows {
            let kinds = SyncField.kinds(of: type)
            #expect(Set(fields.keys) == Set(kinds.keys))
            #expect(fields.allSatisfy { kinds[$0.key]?.holds($0.value) == true })
        }
        for type in [RecordType.member, .photo, .offer, .saga] {
            #expect(SyncField.kinds(of: type).isEmpty)
        }
    }

    @Test("Given a value in a shape its column doesn't hold, when set, then the row is as it was")
    func aValueOfAnotherShapeIsIgnored() {
        let child = ChildRecord(
            childID: UUID(), name: "Λένα", birthYear: 2024, birthMonth: 3, birthDay: 1, gender: "girl", skinTone: "light",
            order: 2, isRemoved: false
        )
        let before = child.syncFields

        child.set([
            "name": .cleared, "order": .string("3"), "isRemoved": .int(1), "birthDay": .string("2024-02-30"),
            "gone": .bool(true), "nickname": .string("Λενάκι")
        ])

        #expect(child.syncFields == before)
    }

    @Test("Given a record with what a row needs, then the row, with what else it brings; lacking any of it, no row")
    func rowsFromRecords() throws {
        let (childID, eventID, authorID) = (UUID(), UUID(), UUID())
        let childFields: [String: SyncValue] = [
            "name": .string("Λένα"), "gender": .string("girl"), "skinTone": .string("light"), "order": .int(1)
        ]
        let entryFields: [String: SyncValue] = [
            "author": .string(authorID.uuidString), "childID": .string(childID.uuidString), "kind": .string("first"),
            "contentID": .string("f-smile"), "date": .date(Date(timeIntervalSince1970: 1_750_000_000))
        ]

        let child = try #require(ChildRecord.inserted(childID: childID, from: childFields))
        #expect(child.syncFields == childFields.merging(["isRemoved": .bool(false), "birthDay": .cleared]) { first, _ in first })
        let removed = try #require(ChildRecord.inserted(
            childID: childID, from: childFields.merging(["isRemoved": .bool(true), "birthDay": .string("2024-03-01")]) { $1 }
        ))
        #expect((removed.isRemoved, removed.birthYear, removed.birthMonth, removed.birthDay) == (true, 2024, 3, 1))
        let entry = try #require(ProgressEventRecord.inserted(eventID: eventID, from: entryFields))
        #expect(entry.syncFields == entryFields.merging(["note": .cleared, "photoIDs": .strings([])]) { first, _ in first })
        #expect(entry.recordName == .entry(eventID))
        #expect(OutfitRecord.inserted(skill: "care", from: ["choice": .string("hidden")])?.recordName == .wardrobe(skill: "care"))

        for missing in childFields.keys {
            #expect(ChildRecord.inserted(childID: childID, from: childFields.filter { $0.key != missing }) == nil)
        }
        for missing in entryFields.keys {
            #expect(ProgressEventRecord.inserted(eventID: eventID, from: entryFields.filter { $0.key != missing }) == nil)
        }
        #expect(OutfitRecord.inserted(skill: "care", from: [:]) == nil)
    }
}
