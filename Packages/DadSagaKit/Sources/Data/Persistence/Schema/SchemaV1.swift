import Foundation
import SwiftData

/// The one stored version (ADR-0026, ADR-0060 §2). Until the first App Store release nothing has shipped, so it is
/// changed in place: a PR that changes it says so, and devices running `develop` delete the app first. From that
/// release on it is never edited: a change to a stored property is a new version with a stage in
/// `DadSagaMigrationPlan`.
/// A column is optional only where nil means something. No literal defaults and no indexes. Every id is `#Unique`, one
/// row per id, and kept in the history when its row is deleted, so a change can name the row it took (ADR-0065 §5).
/// No write relies on the upsert a unique column does: a row whose id may be stored is fetched, then updated or
/// deleted, and only a new id (an entry's fresh UUID, a new child) is inserted without a fetch.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ProfileRecord.self, ChildRecord.self, ProgressEventRecord.self, OutfitRecord.self]
    }

    /// The dad: his hero class, skin tone, look and partner answer, and what he keeps for titles. The store keeps
    /// exactly one.
    @Model
    final class ProfileRecord {
        #Unique<ProfileRecord>([\.profileID])

        /// `PlayerProfile.id`: made at onboarding or brought by a copy, and never changed (ADR-0065 §5).
        @Attribute(.preserveValueOnDeletion) var profileID: UUID
        var heroClassID: String
        var dadSkinTone: String
        /// The look's raw values (`DadAppearance`). An unknown one reads as that part of the standard look for the skin
        /// tone (ADR-0044 §6).
        var hairStyle: String
        var hairColor: String
        var beard: String
        var glasses: String
        /// "I have a partner" (ADR-0053 §4).
        var hasPartner: Bool
        /// The highest title held when an entry was last deleted (ADR-0055 §3). Nil before any deletion.
        var heldTitleID: String?
        /// The title whose card the dad closed last, or the one an Undo left him with. Nil until he closes one.
        var seenTitleID: String?

        init(
            profileID: UUID,
            heroClassID: String,
            dadSkinTone: String,
            hairStyle: String,
            hairColor: String,
            beard: String,
            glasses: String,
            hasPartner: Bool
        ) {
            self.profileID = profileID
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
        #Unique<ChildRecord>([\.childID])

        @Attribute(.preserveValueOnDeletion) var childID: UUID
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
        /// Removed from the family (ADR-0065 §4): on no screen and in no count, their entries kept. Set by removing a
        /// child in "My family", cleared by bringing them back.
        var isRemoved: Bool

        init(
            childID: UUID,
            name: String,
            birthYear: Int?,
            birthMonth: Int?,
            birthDay: Int?,
            gender: String,
            skinTone: String,
            order: Int,
            isRemoved: Bool
        ) {
            self.childID = childID
            self.name = name
            self.birthYear = birthYear
            self.birthMonth = birthMonth
            self.birthDay = birthDay
            self.gender = gender
            self.skinTone = skinTone
            self.order = order
            self.isRemoved = isRemoved
        }
    }

    /// One progress event.
    @Model
    final class ProgressEventRecord {
        #Unique<ProgressEventRecord>([\.eventID])

        @Attribute(.preserveValueOnDeletion) var eventID: UUID
        /// `ProgressEvent.authorID`: the profile id of whoever recorded it (ADR-0065 §5).
        var authorID: UUID
        /// "quest", "boss" or "first".
        var kind: String
        var contentID: String
        var childID: UUID
        var date: Date
        var note: String?
        /// Every photo, in the dad's order; the first is the cover. At most `ProgressEvent.photoLimit`.
        var photoIDs: [String]

        init(
            eventID: UUID,
            authorID: UUID,
            kind: String,
            contentID: String,
            childID: UUID,
            date: Date,
            note: String?,
            photoIDs: [String]
        ) {
            self.eventID = eventID
            self.authorID = authorID
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
        #Unique<OutfitRecord>([\.skill])

        @Attribute(.preserveValueOnDeletion) var skill: String
        /// "hidden" or "item:<gear id>".
        var choice: String

        init(skill: String, choice: String) {
            self.skill = skill
            self.choice = choice
        }
    }
}
