import Domain

/// What the "Your hero" page shows: every class and the dad's current choice.
public struct HeroChoice: Sendable {
    public let heroClasses: [HeroClass]
    public let heroClassID: String
    public let skinTone: SkinTone

    public init(heroClasses: [HeroClass], heroClassID: String, skinTone: SkinTone) {
        self.heroClasses = heroClasses
        self.heroClassID = heroClassID
        self.skinTone = skinTone
    }
}

/// The hero page's one query (ADR-0028). `nil` before onboarding.
public protocol GetHeroChoiceUseCase: Sendable {
    func execute() async throws -> HeroChoice?
}

public struct DefaultGetHeroChoiceUseCase: GetHeroChoiceUseCase {
    private let contentRepository: any ContentRepository
    private let profileRepository: any ProfileRepository

    public init(contentRepository: any ContentRepository, profileRepository: any ProfileRepository) {
        self.contentRepository = contentRepository
        self.profileRepository = profileRepository
    }

    public func execute() async throws -> HeroChoice? {
        async let catalog = contentRepository.fetchCatalog()
        async let profile = profileRepository.fetchProfile()
        guard let profile = try await profile else { return nil }
        return HeroChoice(
            heroClasses: try await catalog.heroClasses,
            heroClassID: profile.heroClassID,
            skinTone: profile.dadSkinTone
        )
    }
}
