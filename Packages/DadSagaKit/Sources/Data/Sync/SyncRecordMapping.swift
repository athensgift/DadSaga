import Domain
import Foundation
import SwiftData

/// The fields of each record that mirrors a row of the saga store (ADR-0065 §1). CloudKit's production schema is
/// permanent, so these are written out as strings, never taken from a Swift name. Values are the strings the store
/// holds (a gender, a look part, a kind, a wardrobe choice), so one this version doesn't know passes through untouched.
enum SyncField {
    /// What a field's column holds, so a value that came in another shape is left on the server, never forced into
    /// the row.
    enum Kind: Sendable {
        case string, int, bool, date, strings
        /// A string, or `.cleared` for nil.
        case optionalString
        /// A UUID's string.
        case uuid
        /// `yyyy-MM-dd` (`BirthDayCoding`), or `.cleared` while the child is not born.
        case birthDay

        func holds(_ value: SyncValue) -> Bool {
            switch (self, value) {
            case (.string, .string), (.int, .int), (.bool, .bool), (.date, .date), (.strings, .strings),
                 (.optionalString, .string), (.optionalString, .cleared), (.birthDay, .cleared):
                true
            case (.uuid, .string(let string)): UUID(uuidString: string) != nil
            case (.birthDay, .string(let string)): BirthDayCoding.day(string) != nil
            default: false
            }
        }
    }

    enum Hero {
        static let classID = "classID"
        static let skinTone = "skinTone"
        static let hair = "hair"
        static let hairColor = "hairColor"
        static let beard = "beard"
        static let glasses = "glasses"
        static let hasPartner = "hasPartner"
        static let heldTitleID = "heldTitleID"
        static let seenTitleID = "seenTitleID"
        static let kinds: [String: Kind] = [
            classID: .string, skinTone: .string, hair: .string, hairColor: .string, beard: .string, glasses: .string,
            hasPartner: .bool, heldTitleID: .optionalString, seenTitleID: .optionalString
        ]
        static let all = Set(kinds.keys)
    }

    enum Wardrobe {
        static let choice = "choice"
        static let kinds: [String: Kind] = [choice: .string]
        static let all = Set(kinds.keys)
    }

    enum Child {
        static let name = "name"
        static let gender = "gender"
        static let skinTone = "skinTone"
        static let order = "order"
        static let isRemoved = "isRemoved"
        /// The three day columns as one field, so a day moves whole.
        static let birthDay = "birthDay"
        /// Set once the child is deleted for good, every other field cleared (ADR-0065 §4). No column: `Sync.store`
        /// keeps the id.
        static let gone = "gone"
        /// The fields a row has, and what each holds; `gone` is apart.
        static let kinds: [String: Kind] = [
            name: .string, gender: .string, skinTone: .string, order: .int, isRemoved: .bool, birthDay: .birthDay
        ]
        static let all = Set(kinds.keys)
    }

    enum Entry {
        static let author = "author"
        static let childID = "childID"
        static let kind = "kind"
        static let contentID = "contentID"
        static let date = "date"
        static let note = "note"
        static let photoIDs = "photoIDs"
        static let kinds: [String: Kind] = [
            author: .uuid, childID: .uuid, kind: .string, contentID: .string, date: .date, note: .optionalString,
            photoIDs: .strings
        ]
        static let all = Set(kinds.keys)
    }

    /// `photo-<photoID>`: the stored JPEG travels as the record's asset, never as a field.
    enum Photo {
        /// The entry the photo was recorded with, a UUID's string.
        static let entryID = "entryID"
    }

    /// `saga`, in the parent's own zone: which family their saga is in.
    enum Saga {
        /// The id in the family zone's name, a UUID's string.
        static let familyZone = "familyZone"
        /// The real user record name of the parent whose iCloud holds the family.
        static let familyOwner = "familyOwner"
        /// This parent's child ids to the family's, from the last join (`ChildMap`, as JSON text); absent: none.
        static let childMap = "childMap"
        /// How the family came to be this parent's, for their other iPhones that follow (ADR-0065 §4). Absent: by a
        /// join, a leave or a stop, and following merges. Anything else replaces the follower's saga with the zone's.
        static let how = "how"
    }

    /// `member-<profileID>`, written by the parent it names.
    enum Member {
        static let userRecordName = "userRecordName"
    }

    /// Each field of a record that mirrors a saga row, and what it holds; empty for the records `Sync.store` and the
    /// defaults hold.
    static func kinds(of type: RecordType) -> [String: Kind] {
        switch type {
        case .hero: Hero.kinds
        case .wardrobe: Wardrobe.kinds
        case .child: Child.kinds
        case .entry: Entry.kinds
        case .member, .photo, .offer, .saga: [:]
        }
    }

    /// Every field of a record that mirrors a saga row.
    static func all(of type: RecordType) -> Set<String> {
        Set(kinds(of: type).keys)
    }
}

/// A row of the saga store that syncs as one record (ADR-0065 §1). The columns that name a row (`profileID`, a child's
/// `childID`, `eventID`, `skill`) never map to a field. Key paths are compared inline, inside the store's queue, never
/// stored.
protocol SyncedRow: PersistentModel {
    var recordName: RecordName { get }
    /// The record a deleted row was, from the id its tombstone kept (ADR-0065 §5).
    static func recordName(from tombstone: HistoryTombstone<Self>) -> RecordName?
    /// The field a column is sent as; `nil` for a column that names the row.
    static func syncField(for column: PartialKeyPath<Self>) -> String?
    /// Every field's value now.
    var syncFields: [String: SyncValue] { get }
    /// Sets the field's column, only when the value differs and is one the column holds (`SyncRecordWriting`).
    func set(_ field: String, to value: SyncValue)
}

extension SyncedRow {
    /// The record with only the `wanted` fields; `nil`: every field.
    func syncRecord(fields wanted: Set<String>?, zones: SyncZones) -> SyncRecord {
        let fields = wanted.map { wanted in syncFields.filter { wanted.contains($0.key) } } ?? syncFields
        return SyncRecord(name: recordName, zone: zones.zone(for: recordName.type), fields: fields)
    }
}

extension ProfileRecord: SyncedRow {
    var recordName: RecordName { .hero(profileID) }

    static func recordName(from tombstone: HistoryTombstone<ProfileRecord>) -> RecordName? {
        (tombstone[\.profileID] as? UUID).map(RecordName.hero)
    }

    static func syncField(for column: PartialKeyPath<ProfileRecord>) -> String? {
        switch column {
        case \ProfileRecord.heroClassID: SyncField.Hero.classID
        case \ProfileRecord.dadSkinTone: SyncField.Hero.skinTone
        case \ProfileRecord.hairStyle: SyncField.Hero.hair
        case \ProfileRecord.hairColor: SyncField.Hero.hairColor
        case \ProfileRecord.beard: SyncField.Hero.beard
        case \ProfileRecord.glasses: SyncField.Hero.glasses
        case \ProfileRecord.hasPartner: SyncField.Hero.hasPartner
        case \ProfileRecord.heldTitleID: SyncField.Hero.heldTitleID
        case \ProfileRecord.seenTitleID: SyncField.Hero.seenTitleID
        default: nil
        }
    }

    var syncFields: [String: SyncValue] {
        [
            SyncField.Hero.classID: .string(heroClassID),
            SyncField.Hero.skinTone: .string(dadSkinTone),
            SyncField.Hero.hair: .string(hairStyle),
            SyncField.Hero.hairColor: .string(hairColor),
            SyncField.Hero.beard: .string(beard),
            SyncField.Hero.glasses: .string(glasses),
            SyncField.Hero.hasPartner: .bool(hasPartner),
            SyncField.Hero.heldTitleID: heldTitleID.map(SyncValue.string) ?? .cleared,
            SyncField.Hero.seenTitleID: seenTitleID.map(SyncValue.string) ?? .cleared
        ]
    }
}

extension OutfitRecord: SyncedRow {
    var recordName: RecordName { .wardrobe(skill: skill) }

    static func recordName(from tombstone: HistoryTombstone<OutfitRecord>) -> RecordName? {
        (tombstone[\.skill] as? String).map(RecordName.wardrobe(skill:))
    }

    static func syncField(for column: PartialKeyPath<OutfitRecord>) -> String? {
        column == \OutfitRecord.choice ? SyncField.Wardrobe.choice : nil
    }

    var syncFields: [String: SyncValue] { [SyncField.Wardrobe.choice: .string(choice)] }
}

extension ChildRecord: SyncedRow {
    var recordName: RecordName { .child(childID) }

    static func recordName(from tombstone: HistoryTombstone<ChildRecord>) -> RecordName? {
        (tombstone[\.childID] as? UUID).map(RecordName.child)
    }

    static func syncField(for column: PartialKeyPath<ChildRecord>) -> String? {
        switch column {
        case \ChildRecord.name: SyncField.Child.name
        case \ChildRecord.gender: SyncField.Child.gender
        case \ChildRecord.skinTone: SyncField.Child.skinTone
        case \ChildRecord.order: SyncField.Child.order
        case \ChildRecord.isRemoved: SyncField.Child.isRemoved
        case \ChildRecord.birthYear, \ChildRecord.birthMonth, \ChildRecord.birthDay: SyncField.Child.birthDay
        default: nil
        }
    }

    /// A row whose day columns are partly filled (a damaged row, which the app reads as a failure) sends no
    /// `birthDay`: the server keeps what it has.
    var syncFields: [String: SyncValue] {
        var fields: [String: SyncValue] = [
            SyncField.Child.name: .string(name),
            SyncField.Child.gender: .string(gender),
            SyncField.Child.skinTone: .string(skinTone),
            SyncField.Child.order: .int(order),
            SyncField.Child.isRemoved: .bool(isRemoved)
        ]
        switch (birthYear, birthMonth, birthDay) {
        case (nil, nil, nil): fields[SyncField.Child.birthDay] = .cleared
        case (let year?, let month?, let day?): fields[SyncField.Child.birthDay] = BirthDayCoding.value(year, month, day)
        default: break
        }
        return fields
    }

    /// What is left of a child deleted for good (ADR-0065 §4): the marker, and every other field cleared, so no iPhone
    /// that was off can send them again.
    static func goneRecord(childID: UUID, zones: SyncZones) -> SyncRecord {
        var fields = Dictionary(uniqueKeysWithValues: SyncField.Child.all.map { ($0, SyncValue.cleared) })
        fields[SyncField.Child.gone] = .bool(true)
        return SyncRecord(name: .child(childID), zone: zones.zone(for: .child), fields: fields)
    }
}

extension ProgressEventRecord: SyncedRow {
    var recordName: RecordName { .entry(eventID) }

    static func recordName(from tombstone: HistoryTombstone<ProgressEventRecord>) -> RecordName? {
        (tombstone[\.eventID] as? UUID).map(RecordName.entry)
    }

    static func syncField(for column: PartialKeyPath<ProgressEventRecord>) -> String? {
        switch column {
        case \ProgressEventRecord.authorID: SyncField.Entry.author
        case \ProgressEventRecord.childID: SyncField.Entry.childID
        case \ProgressEventRecord.kind: SyncField.Entry.kind
        case \ProgressEventRecord.contentID: SyncField.Entry.contentID
        case \ProgressEventRecord.date: SyncField.Entry.date
        case \ProgressEventRecord.note: SyncField.Entry.note
        case \ProgressEventRecord.photoIDs: SyncField.Entry.photoIDs
        default: nil
        }
    }

    var syncFields: [String: SyncValue] {
        [
            SyncField.Entry.author: .string(authorID.uuidString),
            SyncField.Entry.childID: .string(childID.uuidString),
            SyncField.Entry.kind: .string(kind),
            SyncField.Entry.contentID: .string(contentID),
            SyncField.Entry.date: .date(date),
            SyncField.Entry.note: note.map(SyncValue.string) ?? .cleared,
            SyncField.Entry.photoIDs: .strings(photoIDs)
        ]
    }
}

/// A birth day as one field, `yyyy-MM-dd` on the Gregorian calendar, zero-padded and written by hand: a formatter
/// would follow the iPhone's calendar and locale (ADR-0065 §1).
enum BirthDayCoding {
    static func value(_ year: Int, _ month: Int, _ day: Int) -> SyncValue {
        .string("\(padded(year, to: 4))-\(padded(month, to: 2))-\(padded(day, to: 2))")
    }

    /// `nil` for anything but four, two and two digits that name a day the calendar has: the field is then left out,
    /// never guessed at.
    static func day(_ string: String) -> CalendarDay? {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.map(\.count) == [4, 2, 2],
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        return CalendarDay(year: year, month: month, day: day)
    }

    private static func padded(_ number: Int, to width: Int) -> String {
        let digits = String(number)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}

extension SyncRecord {
    /// The entry a photo's record names.
    var photoEntryID: UUID? {
        guard case .string(let id)? = fields[SyncField.Photo.entryID] else { return nil }
        return UUID(uuidString: id)
    }

    /// A fetched record is whole, and iCloud keeps no field that is nil (ADR-0065 §1, "absent"): each field of the row
    /// that may be absent, and didn't come, comes as cleared. A field this version doesn't know is not touched.
    var clearingAbsentFields: SyncRecord {
        var record = self
        for (field, kind) in SyncField.kinds(of: name.type) where fields[field] == nil {
            if kind == .optionalString || kind == .birthDay { record.fields[field] = .cleared }
        }
        return record
    }

    /// The family a `saga` record names.
    var sagaFamilyZone: SyncZone? {
        sagaFamily.map { .family($0.zoneID, owner: $0.owner) }
    }

    /// The family a `saga` record names, with what a follower needs of it.
    var sagaFamily: FamilyToFollow? {
        guard case .string(let zone)? = fields[SyncField.Saga.familyZone], let id = UUID(uuidString: zone),
              case .string(let owner)? = fields[SyncField.Saga.familyOwner] else { return nil }
        var (map, how): (Data?, String?) = (nil, nil)
        if case .string(let text)? = fields[SyncField.Saga.childMap] { map = Data(text.utf8) }
        if case .string(let text)? = fields[SyncField.Saga.how] { how = text }
        return FamilyToFollow(zoneID: id, owner: owner, childMap: map, how: how)
    }

    /// Whether a `member-` record counts (ADR-0065 §2): it names the account that created it. Returns that account.
    var memberAccount: String? {
        guard name.type == .member, case .string(let account)? = fields[SyncField.Member.userRecordName],
              creator == account else { return nil }
        return account
    }
}

extension RecordType {
    /// Whether its records mirror a row of the saga store; the others are `Sync.store`'s, the defaults' and files.
    var mirrorsARow: Bool {
        switch self {
        case .hero, .wardrobe, .child, .entry: true
        case .member, .photo, .offer, .saga: false
        }
    }

    /// Where its records go in a batch (ADR-0065 §1). The parent's own first, since they are few and must not wait
    /// behind every photo: `saga` before all, so iCloud is seen to hold this saga from the first request on, and
    /// another iPhone that turns iCloud on meanwhile is asked which to keep (§2). Then members, children, entries,
    /// and photos last, so a partner's timeline fills before its pictures.
    var batchRank: Int {
        switch self {
        case .saga: 0
        case .hero: 1
        case .wardrobe: 2
        case .offer: 3
        case .member: 4
        case .child: 5
        case .entry: 6
        case .photo: 7
        }
    }
}
