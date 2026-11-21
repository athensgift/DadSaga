import Domain

/// What the "Your hero" page shows: every class, every look option, and the dad's current choice.
public struct HeroChoice: Sendable {
    public let heroClasses: [HeroClass]
    public let heroClassID: String
    public let skinTone: SkinTone
    public let appearance: DadAppearance
    /// The names of the look options, in the order the menus show them (ADR-0044).
    public let appearanceOptions: [DadAppearanceOption]

    public init(
        heroClasses: [HeroClass],
        heroClassID: String,
        skinTone: SkinTone,
        appearance: DadAppearance,
        appearanceOptions: [DadAppearanceOption]
    ) {
        self.heroClasses = heroClasses
        self.heroClassID = heroClassID
        self.skinTone = skinTone
        self.appearance = appearance
        self.appearanceOptions = appearanceOptions
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
        async let pendingCatalog = contentRepository.fetchCatalog()
        async let profile = profileRepository.fetchProfile()
        guard let profile = try await profile else { return nil }
        let catalog = try await pendingCatalog
        return HeroChoice(
            heroClasses: catalog.heroClasses,
            // A hero the content no longer has shows as the first one, and is stored only if the dad changes something.
            heroClassID: catalog.hero(for: profile)?.id ?? profile.heroClassID,
            skinTone: profile.dadSkinTone,
            appearance: profile.dadAppearance,
            appearanceOptions: catalog.appearanceOptions
        )
    }
}
