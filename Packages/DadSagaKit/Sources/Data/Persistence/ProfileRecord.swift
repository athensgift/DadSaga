import Domain
import Foundation
import SwiftData

/// SwiftData storage shape of the player profile. Never leaves the Data layer.
@Model
final class ProfileRecord {
    /// Legacy: the only child, from before families. Read once by `LegacyProfileMigration`; still written (first
    /// child) so an older build can open the store.
    var childName: String
    /// Legacy, see `childName`.
    var birthDate: Date
    var heroClassID: String
    /// A literal default, so SwiftData can add the column to stores created before it existed.
    var dadSkinTone: String = "mediumLight"

    init(childName: String, birthDate: Date, heroClassID: String, dadSkinTone: String) {
        self.childName = childName
        self.birthDate = birthDate
        self.heroClassID = heroClassID
        self.dadSkinTone = dadSkinTone
    }
}

/// SwiftData storage shape of one child.
@Model
final class ChildRecord {
    var childID: UUID
    var name: String
    var birthDate: Date
    var gender: String
    var skinTone: String
    /// Position in the family, as the dad entered them.
    var order: Int

    init(child: Child, order: Int) {
        childID = child.id
        name = child.name
        birthDate = child.birthDate
        gender = child.gender.rawValue
        skinTone = child.skinTone.rawValue
        self.order = order
    }

    func toDomain() -> Child {
        Child(
            id: childID,
            name: name,
            birthDate: birthDate,
            gender: Gender(rawValue: gender) ?? .boy,
            skinTone: SkinTone(rawValue: skinTone) ?? .mediumLight
        )
    }
}

/// Turns a store from before families (one child on the profile, events without a child) into the current shape:
/// the child becomes a `ChildRecord`, and every unlinked event is linked to them, so nothing earned is lost.
enum LegacyProfileMigration {
    static func run(in context: ModelContext) throws {
        guard let profile = try context.fetch(FetchDescriptor<ProfileRecord>()).first,
              try context.fetchCount(FetchDescriptor<ChildRecord>()) == 0 else { return }
        let child = Child(name: profile.childName, birthDate: profile.birthDate)
        context.insert(ChildRecord(child: child, order: 0))
        let unlinked = FetchDescriptor<ProgressEventRecord>(predicate: #Predicate { $0.childID == nil })
        for event in try context.fetch(unlinked) {
            event.childID = child.id
        }
        try context.save()
    }
}
