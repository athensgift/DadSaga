import Foundation

public enum ProfileValidationError: Error, Equatable {
    case emptyChildName
    case birthDateInFuture
    case unknownHeroClass(String)
}

/// What makes a profile acceptable before it is stored.
public enum ProfileRules {
    /// Returns the profile with the child's name trimmed, or throws the first problem found.
    public static func validated(
        _ profile: PlayerProfile,
        on date: Date,
        heroClasses: [HeroClass]
    ) throws -> PlayerProfile {
        let name = profile.child.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ProfileValidationError.emptyChildName }
        guard profile.child.birthDate <= date else { throw ProfileValidationError.birthDateInFuture }
        guard heroClasses.contains(where: { $0.id == profile.heroClassID }) else {
            throw ProfileValidationError.unknownHeroClass(profile.heroClassID)
        }
        return PlayerProfile(child: Child(name: name, birthDate: profile.child.birthDate), heroClassID: profile.heroClassID)
    }
}
