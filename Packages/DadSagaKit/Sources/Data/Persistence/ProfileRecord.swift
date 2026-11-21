import Domain
import Foundation

/// What was read from the store doesn't make sense: shown as a failure, never guessed at.
public enum StoredDataError: Error, Equatable {
    /// A child's birth day columns are partly filled, or name a day the calendar doesn't have.
    case unreadableBirthDay(childID: UUID)
}

extension ChildRecord {
    convenience init(child: Child, order: Int) {
        self.init(
            childID: child.id,
            name: child.name,
            birthYear: child.birthDay?.year,
            birthMonth: child.birthDay?.month,
            birthDay: child.birthDay?.day,
            gender: child.gender.rawValue,
            skinTone: child.skinTone.rawValue,
            order: order
        )
    }

    func update(from child: Child, order: Int) {
        name = child.name
        birthYear = child.birthDay?.year
        birthMonth = child.birthDay?.month
        birthDay = child.birthDay?.day
        gender = child.gender.rawValue
        skinTone = child.skinTone.rawValue
        self.order = order
    }

    /// Three empty day columns are a child not born yet (ADR-0053 §8). Some of them, or a day the calendar doesn't have,
    /// is a damaged row: it throws rather than quietly making a born child not born.
    func toDomain() throws -> Child {
        let storedDay: CalendarDay?
        switch (birthYear, birthMonth, birthDay) {
        case (nil, nil, nil):
            storedDay = nil
        case (let year?, let month?, let day?):
            guard let day = CalendarDay(year: year, month: month, day: day) else {
                throw StoredDataError.unreadableBirthDay(childID: childID)
            }
            storedDay = day
        default:
            throw StoredDataError.unreadableBirthDay(childID: childID)
        }
        return Child(
            id: childID,
            name: name,
            birthDay: storedDay,
            gender: Gender(rawValue: gender) ?? .boy,
            skinTone: SkinTone(rawValue: skinTone) ?? .mediumLight
        )
    }
}

extension ProfileRecord {
    convenience init(profile: PlayerProfile) {
        self.init(heroClassID: profile.heroClassID, dadSkinTone: profile.dadSkinTone.rawValue)
        update(from: profile)
    }

    /// Every save writes the whole look and the partner answer, so a row never keeps a part from an earlier version.
    func update(from profile: PlayerProfile) {
        heroClassID = profile.heroClassID
        dadSkinTone = profile.dadSkinTone.rawValue
        hairStyle = profile.dadAppearance.hair.rawValue
        hairColor = profile.dadAppearance.hairColor.rawValue
        beard = profile.dadAppearance.beard.rawValue
        glasses = profile.dadAppearance.glasses.rawValue
        hasPartner = profile.hasPartner
    }

    /// A part missing (a row from version 3) or unknown to this version reads as the standard look for the skin tone.
    /// No partner answer (a row from version 5) reads yes, so no one loses a card he saw (ADR-0053 §4).
    func toDomain(children: [Child]) -> PlayerProfile {
        let tone = SkinTone(rawValue: dadSkinTone) ?? .mediumLight
        let standard = DadAppearance.standard(for: tone)
        let look = DadAppearance(
            hair: hairStyle.flatMap(DadAppearance.Hair.init(rawValue:)) ?? standard.hair,
            hairColor: hairColor.flatMap(DadAppearance.HairColor.init(rawValue:)) ?? standard.hairColor,
            beard: beard.flatMap(DadAppearance.Beard.init(rawValue:)) ?? standard.beard,
            glasses: glasses.flatMap(DadAppearance.Glasses.init(rawValue:)) ?? standard.glasses
        )
        return PlayerProfile(
            children: children, heroClassID: heroClassID, dadSkinTone: tone, dadAppearance: look,
            hasPartner: hasPartner ?? true
        )
    }
}
