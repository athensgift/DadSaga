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
    /// Returns the profile with the children's names trimmed, or throws the first problem found.
    public static func validated(
        _ profile: PlayerProfile,
        on date: Date,
        heroClasses: [HeroClass]
    ) throws -> PlayerProfile {
        guard !profile.children.isEmpty else { throw ProfileValidationError.noChildren }
        guard profile.children.count <= PlayerProfile.maxChildren else { throw ProfileValidationError.tooManyChildren }
        let children = try profile.children.map { child in
            var child = child
            child.name = child.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !child.name.isEmpty else { throw ProfileValidationError.emptyChildName }
            guard child.birthDate <= date else { throw ProfileValidationError.birthDateInFuture }
            return child
        }
        guard heroClasses.contains(where: { $0.id == profile.heroClassID }) else {
            throw ProfileValidationError.unknownHeroClass(profile.heroClassID)
        }
        var valid = profile
        valid.children = children
        return valid
    }
}
