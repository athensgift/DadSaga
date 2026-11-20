import Foundation
import SwiftData

/// The stored shape since ADR-0023, frozen as version 1 (ADR-0026). A released version is never edited: a change to a
/// stored property is a new version with a stage in `DadSagaMigrationPlan`.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ProfileRecord.self, ChildRecord.self, ProgressEventRecord.self, OutfitRecord.self]
    }

    /// The dad: his hero class and skin tone. The store keeps exactly one.
    @Model
    final class ProfileRecord {
        var heroClassID: String
        /// The literal default is part of version 1's shape; keep it.
        var dadSkinTone: String = "mediumLight"

        init(heroClassID: String, dadSkinTone: String) {
            self.heroClassID = heroClassID
            self.dadSkinTone = dadSkinTone
        }
    }

    /// One child.
    @Model
    final class ChildRecord {
        var childID: UUID
        var name: String
        var birthDate: Date
        var gender: String
        var skinTone: String
        /// Position in the family, as the dad entered them.
        var order: Int

        init(childID: UUID, name: String, birthDate: Date, gender: String, skinTone: String, order: Int) {
            self.childID = childID
            self.name = name
            self.birthDate = birthDate
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
        /// Optional only in this version; every event written since ADR-0023 has a child.
        var childID: UUID?
        var date: Date
        var note: String?
        var photoID: String?

        init(eventID: UUID, kind: String, contentID: String, childID: UUID?, date: Date, note: String?, photoID: String?) {
            self.eventID = eventID
            self.kind = kind
            self.contentID = contentID
            self.childID = childID
            self.date = date
            self.note = note
            self.photoID = photoID
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
