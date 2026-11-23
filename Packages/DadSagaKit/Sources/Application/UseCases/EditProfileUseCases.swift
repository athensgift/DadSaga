import Domain
import Foundation

public enum ProfileEditError: Error, Equatable {
    /// There is nothing to edit before onboarding.
    case noProfile
    /// Onboarding over a stored player: there is one per iPhone (ADR-0065 §5).
    case profileExists
    /// No child removed from the family has this id: bringing back and deleting for good act on a removed child only
    /// (ADR-0065 §4).
    case notRemoved
}

/// Changes what the dad changed of his hero, skin tone and look, and nothing else. Progress and wardrobe are untouched:
/// a class is only an identity and a look (ADR-0008, ADR-0030, ADR-0044).
public protocol UpdateHeroUseCase: Sendable {
    func execute(_ edit: HeroEdit) async throws
}

/// Changes what the dad changed of the children and the partner answer, and keeps the dad's hero.
public protocol UpdateFamilyUseCase: Sendable {
    func execute(_ edit: FamilyEdit, on date: Date) async throws
}

public struct DefaultUpdateHeroUseCase: UpdateHeroUseCase {
    private let contentRepository: any ContentRepository
    private let profileRepository: any ProfileRepository

    public init(contentRepository: any ContentRepository, profileRepository: any ProfileRepository) {
        self.contentRepository = contentRepository
        self.profileRepository = profileRepository
    }

    /// A hero the edit names must be one the content has now: the page only offers those. An edit that names no hero
    /// keeps the stored one, even one the content no longer has (ADR-0065 §1).
    public func execute(_ edit: HeroEdit) async throws {
        guard !edit.isEmpty else { return }
        if edit.heroClassID != nil {
            let catalog = try await contentRepository.fetchCatalog()
            _ = try ProfileRules.validated(edit, heroClasses: catalog.heroClasses)
        }
        try await profileRepository.save(edit)
    }
}

/// Keeps the stored hero as it is, even one the content no longer has: editing the family never asks for a hero
/// (ADR-0048 §5).
public struct DefaultUpdateFamilyUseCase: UpdateFamilyUseCase {
    private let profileRepository: any ProfileRepository
    private let timeZone: TimeZone

    public init(profileRepository: any ProfileRepository, timeZone: TimeZone = .autoupdatingCurrent) {
        self.profileRepository = profileRepository
        self.timeZone = timeZone
    }

    /// Checked against the family as it stands; an empty edit saves nothing.
    public func execute(_ edit: FamilyEdit, on date: Date) async throws {
        guard let profile = try await profileRepository.fetchProfile() else { throw ProfileEditError.noProfile }
        guard !edit.isEmpty else { return }
        let valid = try ProfileRules.validated(edit, for: profile.children, on: CalendarDay(date, in: timeZone))
        try await profileRepository.save(valid)
    }
}
