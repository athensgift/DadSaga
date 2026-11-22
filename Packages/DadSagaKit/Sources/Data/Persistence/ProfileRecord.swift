import Domain
import Foundation

/// What was read from the store doesn't make sense: shown as a failure, never guessed at.
enum StoredDataError: Error, Equatable {
    /// A child's birth day columns are partly filled, or name a day the calendar doesn't have.
    case unreadableBirthDay(childID: UUID)
}

extension ChildRecord {
    /// `isRemoved` is false for every child the app itself writes; only a copy brings a removed one (ADR-0065 §5).
    convenience init(child: Child, order: Int, isRemoved: Bool) {
        self.init(
            childID: child.id,
            name: child.name,
            birthYear: child.birthDay?.year,
            birthMonth: child.birthDay?.month,
            birthDay: child.birthDay?.day,
            gender: child.gender.rawValue,
            skinTone: child.skinTone.rawValue,
            order: order,
            isRemoved: isRemoved
        )
    }

    /// Never writes `childID` or `isRemoved`.
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
        let look = profile.dadAppearance
        self.init(
            profileID: profile.id,
            heroClassID: profile.heroClassID,
            dadSkinTone: profile.dadSkinTone.rawValue,
            hairStyle: look.hair.rawValue,
            hairColor: look.hairColor.rawValue,
            beard: look.beard.rawValue,
            glasses: look.glasses.rawValue,
            hasPartner: profile.hasPartner
        )
    }

    /// What the store keeps for titles. Never written by `update(from:)`, so editing the family can't lower it.
    var kept: KeptStanding {
        KeptStanding(titleID: heldTitleID, seenTitleID: seenTitleID)
    }

    /// Never writes `profileID`: the stored player keeps who they are.
    func update(from profile: PlayerProfile) {
        heroClassID = profile.heroClassID
        dadSkinTone = profile.dadSkinTone.rawValue
        hairStyle = profile.dadAppearance.hair.rawValue
        hairColor = profile.dadAppearance.hairColor.rawValue
        beard = profile.dadAppearance.beard.rawValue
        glasses = profile.dadAppearance.glasses.rawValue
        hasPartner = profile.hasPartner
    }

    /// A part unknown to this version reads as the standard look for the skin tone: the look is stored as strings,
    /// not as enums (ADR-0044 §6).
    func toDomain(children: [Child]) -> PlayerProfile {
        let tone = SkinTone(rawValue: dadSkinTone) ?? .mediumLight
        let standard = DadAppearance.standard(for: tone)
        let look = DadAppearance(
            hair: DadAppearance.Hair(rawValue: hairStyle) ?? standard.hair,
            hairColor: DadAppearance.HairColor(rawValue: hairColor) ?? standard.hairColor,
            beard: DadAppearance.Beard(rawValue: beard) ?? standard.beard,
            glasses: DadAppearance.Glasses(rawValue: glasses) ?? standard.glasses
        )
        return PlayerProfile(
            id: profileID, children: children, heroClassID: heroClassID, dadSkinTone: tone, dadAppearance: look,
            hasPartner: hasPartner
        )
    }
}
