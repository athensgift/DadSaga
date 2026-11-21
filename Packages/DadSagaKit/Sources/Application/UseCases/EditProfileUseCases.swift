import Domain
import Foundation

public enum ProfileEditError: Error, Equatable {
    /// There is nothing to edit before onboarding.
    case noProfile
}

/// Changes the dad's hero, skin tone and look. Progress and wardrobe are untouched: a class is only an identity and a
/// look (ADR-0008, ADR-0030, ADR-0044).
public protocol UpdateHeroUseCase: Sendable {
    func execute(heroClassID: String, skinTone: SkinTone, appearance: DadAppearance, on date: Date) async throws
}

/// Changes the children and the partner answer, and keeps the dad's hero.
public protocol UpdateFamilyUseCase: Sendable {
    func execute(children: [Child], hasPartner: Bool, on date: Date) async throws
}

public struct DefaultUpdateHeroUseCase: UpdateHeroUseCase {
    private let contentRepository: any ContentRepository
    private let profileRepository: any ProfileRepository
    private let timeZone: TimeZone

    public init(
        contentRepository: any ContentRepository,
        profileRepository: any ProfileRepository,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.contentRepository = contentRepository
        self.profileRepository = profileRepository
        self.timeZone = timeZone
    }

    /// The hero must be one the content has now: the page only offers those.
    public func execute(heroClassID: String, skinTone: SkinTone, appearance: DadAppearance, on date: Date) async throws {
        async let catalog = contentRepository.fetchCatalog()
        guard var profile = try await profileRepository.fetchProfile() else { throw ProfileEditError.noProfile }
        profile.heroClassID = heroClassID
        profile.dadSkinTone = skinTone
        profile.dadAppearance = appearance
        let valid = try ProfileRules.validated(
            profile, on: CalendarDay(date, in: timeZone), heroClasses: try await catalog.heroClasses
        )
        try await profileRepository.save(valid)
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

    public func execute(children: [Child], hasPartner: Bool, on date: Date) async throws {
        guard var profile = try await profileRepository.fetchProfile() else { throw ProfileEditError.noProfile }
        profile.children = try ProfileRules.validatedChildren(children, on: CalendarDay(date, in: timeZone))
        profile.hasPartner = hasPartner
        try await profileRepository.save(profile)
    }
}
