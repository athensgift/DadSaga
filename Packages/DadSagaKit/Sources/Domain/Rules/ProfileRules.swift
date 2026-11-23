import Foundation

public enum ProfileValidationError: Error, Equatable {
    case noChildren
    case tooManyChildren
    case emptyChildName
    case birthDateInFuture
    case unknownHeroClass(String)
}

/// What makes a profile or an edit acceptable before it is stored.
public enum ProfileRules {
    /// Onboarding: every child is added to an empty family, so one to `PlayerProfile.maxChildren`, names trimmed, and
    /// the hero one the content has now. Returns the profile with the names trimmed, or throws the first problem found.
    public static func validated(
        _ profile: PlayerProfile,
        on today: CalendarDay,
        heroClasses: [HeroClass]
    ) throws -> PlayerProfile {
        let family = try validated(FamilyEdit(added: profile.children), for: [], on: today)
        _ = try validated(HeroEdit(heroClassID: profile.heroClassID), heroClasses: heroClasses)
        var valid = profile
        valid.children = family.added
        return valid
    }

    /// `edit` with its names trimmed, checked against `family` as it stands (ADR-0065 §4). Only what the edit sets is
    /// checked: an added or renamed child needs a name, and an added child's birth day, or a changed one, can't be after
    /// today. `noChildren` when the edit leaves the family without a child; `tooManyChildren` only when the edit adds a
    /// child and the family after it holds more than `PlayerProfile.maxChildren`, so a family that holds more (a copy, or
    /// two parents adding at once) can still be edited.
    public static func validated(_ edit: FamilyEdit, for family: [Child], on today: CalendarDay) throws -> FamilyEdit {
        var valid = edit
        valid.added = try edit.added.map { try checked($0, fields: Set(ChildField.allCases), on: today) }
        valid.changed = try edit.changed.map { change in
            ChildEdit(child: try checked(change.child, fields: change.fields, on: today), fields: change.fields)
        }
        let after = valid.applied(to: family)
        guard !after.isEmpty else { throw ProfileValidationError.noChildren }
        let adds = after.contains { child in !family.contains { $0.id == child.id } }
        if adds, after.count > PlayerProfile.maxChildren { throw ProfileValidationError.tooManyChildren }
        return valid
    }

    /// Bringing a removed child back is adding one (ADR-0065 §4): `tooManyChildren` once `family` holds
    /// `PlayerProfile.maxChildren` or more. Only the count: the child comes back as stored, their name and day unchecked.
    public static func checkRoomToBringBack(into family: [Child]) throws {
        if family.count >= PlayerProfile.maxChildren { throw ProfileValidationError.tooManyChildren }
    }

    /// A hero the edit names must be one the content has; an edit naming none is never checked, so the look and the
    /// family can always be edited, even when the stored hero is one the content no longer has (ADR-0048 §5).
    public static func validated(_ edit: HeroEdit, heroClasses: [HeroClass]) throws -> HeroEdit {
        if let heroClassID = edit.heroClassID, !heroClasses.contains(where: { $0.id == heroClassID }) {
            throw ProfileValidationError.unknownHeroClass(heroClassID)
        }
        return edit
    }

    private static func checked(_ child: Child, fields: Set<ChildField>, on today: CalendarDay) throws -> Child {
        var child = child
        if fields.contains(.name) {
            child.name = child.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !child.name.isEmpty else { throw ProfileValidationError.emptyChildName }
        }
        // A child not born yet has no day to check (ADR-0053 §1).
        if fields.contains(.birthDay), let birthDay = child.birthDay, birthDay > today {
            throw ProfileValidationError.birthDateInFuture
        }
        return child
    }
}
