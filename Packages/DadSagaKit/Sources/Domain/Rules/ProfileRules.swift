import Foundation

public enum ProfileValidationError: Error, Equatable {
    case noChildren
    case tooManyChildren
    case emptyChildName
    case birthDateInFuture
    case unknownHeroClass(String)
}

/// What makes a profile acceptable before it is stored.
public enum ProfileRules {
    /// Returns the profile with the children's names trimmed, or throws the first problem found. The hero must be one
    /// the content has now: this is for a hero the dad picks. `storedCount` is as in `validatedChildren`.
    public static func validated(
        _ profile: PlayerProfile,
        on today: CalendarDay,
        heroClasses: [HeroClass],
        storedCount: Int = 0
    ) throws -> PlayerProfile {
        let children = try validatedChildren(profile.children, on: today, storedCount: storedCount)
        guard heroClasses.contains(where: { $0.id == profile.heroClassID }) else {
            throw ProfileValidationError.unknownHeroClass(profile.heroClassID)
        }
        var valid = profile
        valid.children = children
        return valid
    }

    /// Returns the children with their names trimmed, or throws the first problem found. The hero is not looked at, so
    /// a family can always be edited, even when the stored hero is one the content no longer has (ADR-0048 §5).
    ///
    /// The limit of `PlayerProfile.maxChildren` is on adding only (ADR-0065 §4): `storedCount` is how many the family
    /// holds now, and a family a copy brought with more keeps them and can still be edited.
    public static func validatedChildren(_ children: [Child], on today: CalendarDay, storedCount: Int = 0) throws -> [Child] {
        guard !children.isEmpty else { throw ProfileValidationError.noChildren }
        guard children.count <= max(PlayerProfile.maxChildren, storedCount) else {
            throw ProfileValidationError.tooManyChildren
        }
        return try children.map { child in
            var child = child
            child.name = child.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !child.name.isEmpty else { throw ProfileValidationError.emptyChildName }
            // A child not born yet has no day to check (ADR-0053 §1).
            if let birthDay = child.birthDay, birthDay > today { throw ProfileValidationError.birthDateInFuture }
            return child
        }
    }
}
