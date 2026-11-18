import Domain
import Foundation

extension ChildRecord {
    convenience init(child: Child, order: Int) {
        self.init(
            childID: child.id,
            name: child.name,
            birthDate: child.birthDate,
            gender: child.gender.rawValue,
            skinTone: child.skinTone.rawValue,
            order: order
        )
    }

    func update(from child: Child, order: Int) {
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
