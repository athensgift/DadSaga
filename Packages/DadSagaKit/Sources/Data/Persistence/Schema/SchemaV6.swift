import Foundation
import SwiftData

/// The stored shape since a child can be not born yet (ADR-0051 §8): version 5 without the child's `birthDate`, and with
/// the dad's partner answer. All three day columns empty mean "not born yet"; no stored flag says it, so two fields can
/// never disagree.
/// No `#Unique` and no indexes: a unique column upserts silently, and a store with duplicates would not open.
/// Released versions are never edited: a change to a stored property is a new version with a stage in
/// `DadSagaMigrationPlan`.
enum SchemaV6: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(6, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ProfileRecord.self, ChildRecord.self, ProgressEventRecord.self, OutfitRecord.self]
    }

    /// The dad: his hero class, skin tone and look. The store keeps exactly one.
    @Model
    final class ProfileRecord {
        var heroClassID: String
        /// The literal default is part of the stored shape since version 1; keep it.
        var dadSkinTone: String = "mediumLight"
        /// The look's raw values (`DadAppearance`). Nil in rows from version 3, and nil or unknown reads as that part
        /// of the standard look for the skin tone.
        var hairStyle: String?
        var hairColor: String?
        var beard: String?
        var glasses: String?
        /// "I'm raising them with a partner" (ADR-0051 §4). Nil in rows from version 5, and nil reads yes.
        var hasPartner: Bool?

        init(
            heroClassID: String,
            dadSkinTone: String,
            hairStyle: String? = nil,
            hairColor: String? = nil,
            beard: String? = nil,
            glasses: String? = nil,
            hasPartner: Bool? = nil
        ) {
            self.heroClassID = heroClassID
            self.dadSkinTone = dadSkinTone
            self.hairStyle = hairStyle
            self.hairColor = hairColor
            self.beard = beard
            self.glasses = glasses
            self.hasPartner = hasPartner
        }
    }

    /// One child.
    @Model
    final class ChildRecord {
        var childID: UUID
        var name: String
        /// The birth day the dad picked, on the Gregorian calendar (`CalendarDay`). All three nil while the child is
        /// not born yet.
        var birthYear: Int?
        var birthMonth: Int?
        var birthDay: Int?
        var gender: String
        var skinTone: String
        /// Position in the family, as the dad entered them.
        var order: Int

        init(
            childID: UUID,
            name: String,
            birthYear: Int?,
            birthMonth: Int?,
            birthDay: Int?,
            gender: String,
            skinTone: String,
            order: Int
        ) {
            self.childID = childID
            self.name = name
            self.birthYear = birthYear
            self.birthMonth = birthMonth
            self.birthDay = birthDay
            self.gender = gender
            self.skinTone = skinTone
            self.order = order
        }
    }

    /// One progress event.
    @Model
    final class ProgressEventRecord {
        var eventID: UUID
        /// "quest", "boss" or "first".
        var kind: String
        var contentID: String
        /// Optional still; every event written since ADR-0023 has a child. Non-optional waits for sync (ADR-0042 §2).
        var childID: UUID?
        var date: Date
        var note: String?
        /// Every photo, in the dad's order; the first is the cover. At most `ProgressEvent.photoLimit`.
        var photoIDs: [String] = []

        init(eventID: UUID, kind: String, contentID: String, childID: UUID?, date: Date, note: String?, photoIDs: [String]) {
            self.eventID = eventID
            self.kind = kind
            self.contentID = contentID
            self.childID = childID
            self.date = date
            self.note = note
            self.photoIDs = photoIDs
        }
    }

    /// One wardrobe choice. Slots that are automatic have no record.
    @Model
    final class OutfitRecord {
        var skill: String
        /// "hidden" or "item:<gear id>".
        var choice: String

        init(skill: String, choice: String) {
            self.skill = skill
            self.choice = choice
        }
    }
}
