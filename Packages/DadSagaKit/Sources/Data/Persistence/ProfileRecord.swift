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

    /// Sets only the fields the edit names, and only values that differ (ADR-0065 §1). Never writes `childID`, `order`
    /// or `isRemoved`.
    func apply(_ edit: ChildEdit) {
        let child = edit.child
        if edit.fields.contains(.name) { update(\.name, to: child.name) }
        if edit.fields.contains(.birthDay) {
            update(\.birthYear, to: child.birthDay?.year)
            update(\.birthMonth, to: child.birthDay?.month)
            update(\.birthDay, to: child.birthDay?.day)
        }
        if edit.fields.contains(.gender) { update(\.gender, to: child.gender.rawValue) }
        if edit.fields.contains(.skinTone) { update(\.skinTone, to: child.skinTone.rawValue) }
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

    /// What the store keeps for titles. Never written by a family or hero edit, so editing can't lower it.
    var kept: KeptStanding {
        KeptStanding(titleID: heldTitleID, seenTitleID: seenTitleID)
    }

    /// Sets only the parts the edit names, and only values that differ, so a part this version can't name stays as
    /// stored (ADR-0065 §1). Never writes `profileID`, `hasPartner` or the kept titles.
    func apply(_ edit: HeroEdit) {
        if let heroClassID = edit.heroClassID { update(\.heroClassID, to: heroClassID) }
        if let tone = edit.dadSkinTone { update(\.dadSkinTone, to: tone.rawValue) }
        if let hair = edit.hair { update(\.hairStyle, to: hair.rawValue) }
        if let color = edit.hairColor { update(\.hairColor, to: color.rawValue) }
        if let beard = edit.beard { update(\.beard, to: beard.rawValue) }
        if let glasses = edit.glasses { update(\.glasses, to: glasses.rawValue) }
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
