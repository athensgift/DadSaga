import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// Each saga row as the record it syncs as (ADR-0065 §1): the names, the fields and their values. CloudKit's production
/// schema is permanent, so every name and field is written out here as the string it travels as.
@Suite("Rows as sync records")
struct SyncRecordRowsTests {
    let zones = SyncZones(family: .family(UUID(), owner: "_owner"))
    let profileID = UUID()
    let childID = UUID()
    let eventID = UUID()

    func hero(held: String? = nil, seen: String? = nil, beard: String = "full") -> ProfileRecord {
        let row = ProfileRecord(
            profileID: profileID, heroClassID: "h-chef", dadSkinTone: "mediumDark", hairStyle: "curly", hairColor: "grey",
            beard: beard, glasses: "round", hasPartner: true
        )
        row.heldTitleID = held
        row.seenTitleID = seen
        return row
    }

    func child(year: Int? = 2024, month: Int? = 3, day: Int? = 1, gender: String = "girl") -> ChildRecord {
        ChildRecord(
            childID: childID, name: "Λένα 🌟", birthYear: year, birthMonth: month, birthDay: day, gender: gender,
            skinTone: "light", order: 2, isRemoved: true
        )
    }

    func entry(kind: String = "first", note: String? = "Χαμόγελο") -> ProgressEventRecord {
        ProgressEventRecord(
            eventID: eventID, authorID: profileID, kind: kind, contentID: "f-smile", childID: childID,
            date: Date(timeIntervalSince1970: 1_750_000_000.5), note: note, photoIDs: ["b", "a"]
        )
    }

    @Test("Given each kind of record, when named, then its type's prefix and its id, and the name reads back")
    func namesBothWays() throws {
        let id = try #require(UUID(uuidString: "0A0A0A0A-0000-4000-8000-000000000002"))
        let names: [(RecordName, String)] = [
            (.member(id), "member-0A0A0A0A-0000-4000-8000-000000000002"),
            (.child(id), "child-0A0A0A0A-0000-4000-8000-000000000002"),
            (.entry(id), "entry-0A0A0A0A-0000-4000-8000-000000000002"),
            (.photo("3F2504E0-4F89-41D3-9A0C-0305E82C3301"), "photo-3F2504E0-4F89-41D3-9A0C-0305E82C3301"),
            (.hero(id), "hero-0A0A0A0A-0000-4000-8000-000000000002"),
            (.wardrobe(skill: "care"), "wardrobe-care"),
            (.offer(occasionID: "lena/birthday/1"), "offer-lena%2Fbirthday%2F1"),
            (.saga, "saga")
        ]

        for (name, string) in names {
            #expect(name.string == string)
            #expect(RecordName(string) == name)
        }
        #expect(Set(names.map(\.0.type)) == Set(RecordType.allCases))
        #expect(RecordName.child(id).uuid == id)
        #expect(RecordType.allCases.map(\.rawValue) == ["Member", "Child", "Entry", "Photo", "Hero", "Wardrobe", "Offer", "Saga"])
    }

    @Test("Given a name of a type this version doesn't know, or one with no id, when read, then nil: it is left alone")
    func unknownNamesReadAsNil() {
        for string in ["badge-123", "", "child-", "sagas", "saga-2", "Child-0A0A0A0A-0000-4000-8000-000000000002"] {
            #expect(RecordName(string) == nil, "\(string)")
        }
    }

    @Test("Given occasion ids with / and %, when named and read back, then each is itself again")
    func offerNamesRoundTrip() {
        for occasion in ["lena/birthday/1", "50%/a", "%2F", "%25/%", "a%2Fb/c", "plain", "/", "%"] {
            let name = RecordName.offer(occasionID: occasion)
            #expect(!name.id.contains("/"))
            #expect(name.occasionID == occasion)
            #expect(RecordName(name.string)?.occasionID == occasion)
        }
        #expect(RecordName.offer(occasionID: "50%/a").string == "offer-50%25%2Fa")
        // An escape this version didn't write, and a record that is no offer.
        #expect(RecordName("offer-a%2Gb")?.occasionID == nil)
        #expect(RecordName("offer-a%")?.occasionID == nil)
        #expect(RecordName.saga.occasionID == nil)
    }

    @Test("Given the hero's row, when read as a record, then every field by its name, a title not kept as cleared")
    func heroFields() {
        let record = hero(held: "t-second").syncRecord(fields: nil, zones: zones)

        #expect(record == SyncRecord(name: .hero(profileID), zone: .personal, fields: [
            "classID": .string("h-chef"), "skinTone": .string("mediumDark"), "hair": .string("curly"),
            "hairColor": .string("grey"), "beard": .string("full"), "glasses": .string("round"), "hasPartner": .bool(true),
            "heldTitleID": .string("t-second"), "seenTitleID": .cleared
        ]))
        #expect(Set(record.fields.keys) == SyncField.Hero.all)
    }

    @Test("Given a wardrobe row, when read as a record, then its choice, named by its skill")
    func wardrobeFields() {
        let record = OutfitRecord(skill: "care", choice: "item:g-mug").syncRecord(fields: nil, zones: zones)

        #expect(record == SyncRecord(name: .wardrobe(skill: "care"), zone: .personal, fields: ["choice": .string("item:g-mug")]))
    }

    @Test("Given a child's row, when read as a record, then every field, the day as one zero-padded field")
    func childFields() {
        let record = child().syncRecord(fields: nil, zones: zones)

        #expect(record == SyncRecord(name: .child(childID), zone: zones.family, fields: [
            "name": .string("Λένα 🌟"), "gender": .string("girl"), "skinTone": .string("light"), "order": .int(2),
            "isRemoved": .bool(true), "birthDay": .string("2024-03-01")
        ]))
        #expect(Set(record.fields.keys) == SyncField.Child.all)
    }

    @Test("Given a child not born, then birthDay is cleared; given a row with part of a day, then it sends no birthDay")
    func birthDayOfAChildNotBornAndOfADamagedRow() {
        #expect(child(year: nil, month: nil, day: nil).syncFields["birthDay"] == .cleared)
        #expect(child(year: 2024, month: nil, day: 1).syncFields["birthDay"] == nil)
        #expect(child(year: 812, month: 11, day: 30).syncFields["birthDay"] == .string("0812-11-30"))
    }

    @Test("Given a child deleted for good, when its record is built, then gone and every other field cleared")
    func goneRecord() {
        let record = ChildRecord.goneRecord(childID: childID, zones: zones)

        #expect(record == SyncRecord(name: .child(childID), zone: zones.family, fields: [
            "gone": .bool(true), "name": .cleared, "gender": .cleared, "skinTone": .cleared, "order": .cleared,
            "isRemoved": .cleared, "birthDay": .cleared
        ]))
    }

    @Test("Given an entry's row, when read as a record, then every field, its photos in order, no note as cleared")
    func entryFields() {
        let record = entry().syncRecord(fields: nil, zones: zones)

        #expect(record == SyncRecord(name: .entry(eventID), zone: zones.family, fields: [
            "author": .string(profileID.uuidString), "childID": .string(childID.uuidString), "kind": .string("first"),
            "contentID": .string("f-smile"), "date": .date(Date(timeIntervalSince1970: 1_750_000_000.5)),
            "note": .string("Χαμόγελο"), "photoIDs": .strings(["b", "a"])
        ]))
        #expect(Set(record.fields.keys) == SyncField.Entry.all)
        #expect(entry(note: nil).syncFields["note"] == .cleared)
    }

    @Test("Given a record asked with some fields, then only those; fields the row doesn't have are not made up")
    func onlyTheFieldsAsked() {
        #expect(child().syncRecord(fields: ["name", "order", "gone", "nope"], zones: zones).fields == [
            "name": .string("Λένα 🌟"), "order": .int(2)
        ])
        #expect(entry().syncRecord(fields: [], zones: zones).fields.isEmpty)
    }

    @Test("Given a gender, a look part, a kind and a wardrobe choice this version doesn't know, then each goes as stored")
    func unknownValuesPassThrough() {
        #expect(child(gender: "a-newer-gender").syncFields["gender"] == .string("a-newer-gender"))
        #expect(hero(beard: "a-newer-beard").syncFields["beard"] == .string("a-newer-beard"))
        #expect(entry(kind: "a-newer-kind").syncFields["kind"] == .string("a-newer-kind"))
        let slot = OutfitRecord(skill: "a-newer-skill", choice: "a-newer-choice")
        #expect(slot.syncRecord(fields: nil, zones: zones) == SyncRecord(
            name: .wardrobe(skill: "a-newer-skill"), zone: .personal, fields: ["choice": .string("a-newer-choice")]
        ))
    }

    @Test("Given each column, when the feed maps it, then its field; a column that names the row maps to none")
    func columnsToFields() {
        #expect(ProfileRecord.syncField(for: \.heroClassID) == "classID")
        #expect(ProfileRecord.syncField(for: \.dadSkinTone) == "skinTone")
        #expect(ProfileRecord.syncField(for: \.hairStyle) == "hair")
        #expect(ProfileRecord.syncField(for: \.hairColor) == "hairColor")
        #expect(ProfileRecord.syncField(for: \.beard) == "beard")
        #expect(ProfileRecord.syncField(for: \.glasses) == "glasses")
        #expect(ProfileRecord.syncField(for: \.hasPartner) == "hasPartner")
        #expect(ProfileRecord.syncField(for: \.heldTitleID) == "heldTitleID")
        #expect(ProfileRecord.syncField(for: \.seenTitleID) == "seenTitleID")
        #expect(ProfileRecord.syncField(for: \.profileID) == nil)

        #expect(OutfitRecord.syncField(for: \.choice) == "choice")
        #expect(OutfitRecord.syncField(for: \.skill) == nil)

        #expect(ChildRecord.syncField(for: \.name) == "name")
        #expect(ChildRecord.syncField(for: \.gender) == "gender")
        #expect(ChildRecord.syncField(for: \.skinTone) == "skinTone")
        #expect(ChildRecord.syncField(for: \.order) == "order")
        #expect(ChildRecord.syncField(for: \.isRemoved) == "isRemoved")
        #expect(ChildRecord.syncField(for: \.birthYear) == "birthDay")
        #expect(ChildRecord.syncField(for: \.birthMonth) == "birthDay")
        #expect(ChildRecord.syncField(for: \.birthDay) == "birthDay")
        #expect(ChildRecord.syncField(for: \.childID) == nil)

        #expect(ProgressEventRecord.syncField(for: \.authorID) == "author")
        #expect(ProgressEventRecord.syncField(for: \.childID) == "childID")
        #expect(ProgressEventRecord.syncField(for: \.kind) == "kind")
        #expect(ProgressEventRecord.syncField(for: \.contentID) == "contentID")
        #expect(ProgressEventRecord.syncField(for: \.date) == "date")
        #expect(ProgressEventRecord.syncField(for: \.note) == "note")
        #expect(ProgressEventRecord.syncField(for: \.photoIDs) == "photoIDs")
        #expect(ProgressEventRecord.syncField(for: \.eventID) == nil)
    }

    @Test("Given every stored column, then each is a field or names its row: none is forgotten when one is added")
    func everyColumnIsMappedOrNamesTheRow() {
        func columns<Row: SyncedRow>(_: Row.Type) -> [String] {
            Schema(versionedSchema: CurrentSchema.self).entities
                .first { $0.name == String(describing: Row.self) }?
                .attributes.map(\.name) ?? ["no entity"]
        }
        // The columns each model stores, and how many of them the mapping covers: its fields (the three day columns
        // are one) and the one id that names the row.
        #expect(columns(ProfileRecord.self).count == SyncField.Hero.all.count + 1)
        #expect(columns(OutfitRecord.self).count == SyncField.Wardrobe.all.count + 1)
        #expect(columns(ChildRecord.self).count == SyncField.Child.all.count + 2 + 1)
        #expect(columns(ProgressEventRecord.self).count == SyncField.Entry.all.count + 1)
    }

    @Test("Given a birth day as it travels, when read, then the day; anything else reads as nil and is left out")
    func birthDayCoding() {
        #expect(BirthDayCoding.day("2024-03-01") == .day(2024, 3, 1))
        #expect(BirthDayCoding.day("2024-02-29") == .day(2024, 2, 29))
        for malformed in ["", "2024-3-1", "2024-02-30", "2024-13-01", "24-03-01", "2024-03-01T00:00", "2024/03/01",
                          "abcd-ef-gh", "2024-03", "2024-03-01-01", "٢٠٢٤-٠٣-٠١", " 2024-03-01"] {
            #expect(BirthDayCoding.day(malformed) == nil, "\(malformed)")
        }
        #expect(BirthDayCoding.value(2024, 3, 1) == .string("2024-03-01"))
    }
}
