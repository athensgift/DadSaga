import Domain
import Foundation
import SwiftData

/// What was read from the store doesn't make sense: shown as a failure, never guessed at.
enum StoredDataError: Error, Equatable {
    /// A child's birth day columns are partly filled, or name a day the calendar doesn't have.
    case unreadableBirthDay(childID: UUID)
}

extension ChildRecord {
    /// `isRemoved`: removed from the family, kept to bring back or delete for good (ADR-0065 §4).
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
    func toDomain(children: [Child], removedChildren: [Child]) -> PlayerProfile {
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
            hasPartner: hasPartner, removedChildren: removedChildren
        )
    }
}

extension ModelContext {
    /// The profile, with every child row in order (then by id), split into the family and the children removed from it
    /// (ADR-0065 §4). `nil` before onboarding. A removed child is read like any other, so a damaged removed row fails
    /// the read as a damaged child in the family does; neither the app nor a copy writes one.
    func readProfile() throws -> PlayerProfile? {
        guard let profile = try fetch(FetchDescriptor<ProfileRecord>()).first else { return nil }
        return try readProfile(profile)
    }

    /// `profile` with its children, for a caller that already holds the row. By order, then by id: both parents may
    /// add a child offline at the same order, and every iPhone must show them the same way (ADR-0065 §4).
    func readProfile(_ profile: ProfileRecord) throws -> PlayerProfile {
        let rows = try fetch(FetchDescriptor<ChildRecord>()).sorted {
            ($0.order, $0.childID.uuidString) < ($1.order, $1.childID.uuidString)
        }
        return profile.toDomain(
            children: try rows.filter { !$0.isRemoved }.map { try $0.toDomain() },
            removedChildren: try rows.filter(\.isRemoved).map { try $0.toDomain() }
        )
    }

    /// The family, then the children removed from it, numbered in that order.
    func insertChildren(of profile: PlayerProfile) {
        let children = profile.children.map { ($0, false) } + profile.removedChildren.map { ($0, true) }
        for (order, (child, isRemoved)) in children.enumerated() {
            insert(ChildRecord(child: child, order: order, isRemoved: isRemoved))
        }
    }
}
