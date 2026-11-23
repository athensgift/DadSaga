import Foundation
import SwiftData

/// Fields that came, into the rows that mirror them (ADR-0065 §1, §2): the other way of `SyncRecordMapping`. Values
/// are written as the strings they came as, so a gender, a look part, a kind or a wardrobe choice from a newer version
/// is kept, never turned into one this version knows. `FieldMerge` hands only values a column can hold; anything else
/// is ignored here, never forced in.
extension SyncedRow {
    /// Sets each field's column, only where the value differs.
    func set(_ fields: [String: SyncValue]) {
        for (field, value) in fields { set(field, to: value) }
    }
}

extension ProfileRecord {
    func set(_ field: String, to value: SyncValue) {
        switch (field, value) {
        case (SyncField.Hero.hasPartner, .bool(let value)): update(\.hasPartner, to: value)
        case (SyncField.Hero.heldTitleID, .string(let value)): update(\.heldTitleID, to: value)
        case (SyncField.Hero.seenTitleID, .string(let value)): update(\.seenTitleID, to: value)
        case (SyncField.Hero.seenTitleID, .cleared): update(\.seenTitleID, to: nil)
        case (_, .string(let value)): setLook(field, to: value)
        default: break
        }
    }

    private func setLook(_ field: String, to value: String) {
        switch field {
        case SyncField.Hero.classID: update(\.heroClassID, to: value)
        case SyncField.Hero.skinTone: update(\.dadSkinTone, to: value)
        case SyncField.Hero.hair: update(\.hairStyle, to: value)
        case SyncField.Hero.hairColor: update(\.hairColor, to: value)
        case SyncField.Hero.beard: update(\.beard, to: value)
        case SyncField.Hero.glasses: update(\.glasses, to: value)
        default: break
        }
    }
}

extension OutfitRecord {
    func set(_ field: String, to value: SyncValue) {
        if field == SyncField.Wardrobe.choice, case .string(let value) = value { update(\.choice, to: value) }
    }

    /// The row of a record with no row yet; nil while it lacks its choice.
    static func inserted(skill: String, from fields: [String: SyncValue]) -> OutfitRecord? {
        guard case .string(let choice)? = fields[SyncField.Wardrobe.choice] else { return nil }
        return OutfitRecord(skill: skill, choice: choice)
    }
}

extension ChildRecord {
    func set(_ field: String, to value: SyncValue) {
        switch (field, value) {
        case (SyncField.Child.name, .string(let value)): update(\.name, to: value)
        case (SyncField.Child.gender, .string(let value)): update(\.gender, to: value)
        case (SyncField.Child.skinTone, .string(let value)): update(\.skinTone, to: value)
        case (SyncField.Child.order, .int(let value)): update(\.order, to: value)
        case (SyncField.Child.isRemoved, .bool(let value)): update(\.isRemoved, to: value)
        case (SyncField.Child.birthDay, .cleared): setBirthDay(year: nil, month: nil, day: nil)
        case (SyncField.Child.birthDay, .string(let value)):
            if let day = BirthDayCoding.day(value) { setBirthDay(year: day.year, month: day.month, day: day.day) }
        default: break
        }
    }

    private func setBirthDay(year: Int?, month: Int?, day: Int?) {
        update(\.birthYear, to: year)
        update(\.birthMonth, to: month)
        update(\.birthDay, to: day)
    }

    /// The row of a child with no row yet; nil while the record lacks a name, a gender, a skin tone or an order. A
    /// child comes in the family, and not born, unless the record says otherwise.
    static func inserted(childID: UUID, from fields: [String: SyncValue]) -> ChildRecord? {
        guard case .string(let name)? = fields[SyncField.Child.name],
              case .string(let gender)? = fields[SyncField.Child.gender],
              case .string(let skinTone)? = fields[SyncField.Child.skinTone],
              case .int(let order)? = fields[SyncField.Child.order] else { return nil }
        let row = ChildRecord(
            childID: childID, name: name, birthYear: nil, birthMonth: nil, birthDay: nil, gender: gender,
            skinTone: skinTone, order: order, isRemoved: false
        )
        row.set(fields)
        return row
    }
}

extension ProgressEventRecord {
    func set(_ field: String, to value: SyncValue) {
        switch (field, value) {
        case (SyncField.Entry.kind, .string(let value)): update(\.kind, to: value)
        case (SyncField.Entry.contentID, .string(let value)): update(\.contentID, to: value)
        case (SyncField.Entry.date, .date(let value)): update(\.date, to: value)
        case (SyncField.Entry.note, .string(let value)): update(\.note, to: value)
        case (SyncField.Entry.note, .cleared): update(\.note, to: nil)
        case (SyncField.Entry.photoIDs, .strings(let value)): update(\.photoIDs, to: value)
        case (_, .string(let value)): setID(field, to: UUID(uuidString: value))
        default: break
        }
    }

    /// The author and the child travel as UUID strings; one that is no UUID is ignored.
    private func setID(_ field: String, to id: UUID?) {
        guard let id else { return }
        if field == SyncField.Entry.author { update(\.authorID, to: id) }
        if field == SyncField.Entry.childID { update(\.childID, to: id) }
    }

    /// The row of an entry with no row yet; nil while the record lacks its author, kind, content, child or date. No
    /// note and no photos unless the record brings them.
    static func inserted(eventID: UUID, from fields: [String: SyncValue]) -> ProgressEventRecord? {
        guard case .string(let author)? = fields[SyncField.Entry.author], let authorID = UUID(uuidString: author),
              case .string(let child)? = fields[SyncField.Entry.childID], let childID = UUID(uuidString: child),
              case .string(let kind)? = fields[SyncField.Entry.kind],
              case .string(let contentID)? = fields[SyncField.Entry.contentID],
              case .date(let date)? = fields[SyncField.Entry.date] else { return nil }
        let row = ProgressEventRecord(
            eventID: eventID, authorID: authorID, kind: kind, contentID: contentID, childID: childID, date: date,
            note: nil, photoIDs: []
        )
        row.set(fields)
        return row
    }
}
