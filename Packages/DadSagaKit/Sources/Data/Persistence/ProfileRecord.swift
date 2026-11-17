import Domain
import Foundation
import SwiftData

/// SwiftData storage shape of the player profile. Never leaves the Data layer.
@Model
final class ProfileRecord {
    var heroClassID: String
    /// A literal default, so SwiftData can add the column to stores created before it existed.
    var dadSkinTone: String = "mediumLight"

    init(heroClassID: String, dadSkinTone: String) {
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
