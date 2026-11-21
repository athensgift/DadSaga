import Domain
import Foundation

extension ChildRecord {
    convenience init(child: Child, order: Int) {
        self.init(
            childID: child.id,
            name: child.name,
            birthDate: child.birthDay.start(in: .autoupdatingCurrent),
            birthYear: child.birthDay.year,
            birthMonth: child.birthDay.month,
            birthDay: child.birthDay.day,
            gender: child.gender.rawValue,
            skinTone: child.skinTone.rawValue,
            order: order
        )
    }

    func update(from child: Child, order: Int) {
        name = child.name
        birthDate = child.birthDay.start(in: .autoupdatingCurrent)
        birthYear = child.birthDay.year
        birthMonth = child.birthDay.month
        birthDay = child.birthDay.day
        gender = child.gender.rawValue
        skinTone = child.skinTone.rawValue
        self.order = order
    }

    /// A row without a day (one the migration didn't fill) reads its moment in the phone's time zone, as the migration
    /// would have.
    func toDomain() -> Child {
        let storedDay = birthYear.flatMap { year in
            birthMonth.flatMap { month in birthDay.flatMap { CalendarDay(year: year, month: month, day: $0) } }
        }
        return Child(
            id: childID,
            name: name,
            birthDay: storedDay ?? CalendarDay(birthDate, in: .autoupdatingCurrent),
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

    /// Every save writes the whole look, so a row never keeps a part from an earlier version.
    func update(from profile: PlayerProfile) {
        heroClassID = profile.heroClassID
        dadSkinTone = profile.dadSkinTone.rawValue
        hairStyle = profile.dadAppearance.hair.rawValue
        hairColor = profile.dadAppearance.hairColor.rawValue
        beard = profile.dadAppearance.beard.rawValue
        glasses = profile.dadAppearance.glasses.rawValue
    }

    /// A part missing (a row from version 3) or unknown to this version reads as the standard look for the skin tone.
    func toDomain(children: [Child]) -> PlayerProfile {
        let tone = SkinTone(rawValue: dadSkinTone) ?? .mediumLight
        let standard = DadAppearance.standard(for: tone)
        let look = DadAppearance(
            hair: hairStyle.flatMap(DadAppearance.Hair.init(rawValue:)) ?? standard.hair,
            hairColor: hairColor.flatMap(DadAppearance.HairColor.init(rawValue:)) ?? standard.hairColor,
            beard: beard.flatMap(DadAppearance.Beard.init(rawValue:)) ?? standard.beard,
            glasses: glasses.flatMap(DadAppearance.Glasses.init(rawValue:)) ?? standard.glasses
        )
        return PlayerProfile(children: children, heroClassID: heroClassID, dadSkinTone: tone, dadAppearance: look)
    }
}
