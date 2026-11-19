import Domain

/// The hero's wardrobe: the family's dad, every item in the game, his progress and what he chose to wear.
public struct Wardrobe: Sendable {
    public let profile: PlayerProfile?
    /// The dad's hero class, if the content still has it.
    public let hero: HeroClass?
    /// Every item, earned or not.
    public let gear: [GearItem]
    public let progress: DadProgress
    public var outfit: Outfit

    /// What the hero wears with the current choices.
    public var equipped: [GearItem] { GearRules.equipped(gear, skillXP: progress.skillXP, outfit: outfit) }

    public init(profile: PlayerProfile?, hero: HeroClass?, gear: [GearItem], progress: DadProgress, outfit: Outfit) {
        self.profile = profile
        self.hero = hero
        self.gear = gear
        self.progress = progress
        self.outfit = outfit
    }

    public func isEarned(itemID: String, skill: Skill) -> Bool {
        GearRules.earned(gear, skillXP: progress.skillXP).contains { $0.id == itemID && $0.skill == skill }
    }
}

public protocol GetWardrobeUseCase: Sendable {
    func execute() async throws -> Wardrobe
}

public struct DefaultGetWardrobeUseCase: GetWardrobeUseCase {
    private let contentRepository: any ContentRepository
    private let profileRepository: any ProfileRepository
    private let progressRepository: any ProgressRepository
    private let outfitRepository: any OutfitRepository

    public init(
        contentRepository: any ContentRepository,
        profileRepository: any ProfileRepository,
        progressRepository: any ProgressRepository,
        outfitRepository: any OutfitRepository
    ) {
        self.contentRepository = contentRepository
        self.profileRepository = profileRepository
        self.progressRepository = progressRepository
        self.outfitRepository = outfitRepository
    }

    public func execute() async throws -> Wardrobe {
        async let pendingCatalog = contentRepository.fetchCatalog()
        async let pendingProfile = profileRepository.fetchProfile()
        async let pendingEvents = progressRepository.fetchEvents()
        async let pendingOutfit = outfitRepository.fetchOutfit()
        let catalog = try await pendingCatalog
        let profile = try await pendingProfile
        return Wardrobe(
            profile: profile,
            hero: catalog.heroClasses.first { $0.id == profile?.heroClassID },
            gear: catalog.gear,
            progress: DadProgress(events: try await pendingEvents, catalog: catalog),
            outfit: try await pendingOutfit
        )
    }
}

public enum OutfitError: Error, Equatable {
    /// The item is not in the game, belongs to another slot, or the dad has not earned it yet.
    case notEarned(String)
}

/// Changes what the hero wears in one slot. Only an earned item of that slot can be worn.
public protocol SetOutfitChoiceUseCase: Sendable {
    func execute(skill: Skill, choice: OutfitChoice) async throws -> Outfit
}

public struct DefaultSetOutfitChoiceUseCase: SetOutfitChoiceUseCase {
    private let contentRepository: any ContentRepository
    private let progressRepository: any ProgressRepository
    private let outfitRepository: any OutfitRepository

    public init(
        contentRepository: any ContentRepository,
        progressRepository: any ProgressRepository,
        outfitRepository: any OutfitRepository
    ) {
        self.contentRepository = contentRepository
        self.progressRepository = progressRepository
        self.outfitRepository = outfitRepository
    }

    public func execute(skill: Skill, choice: OutfitChoice) async throws -> Outfit {
        if case .item(let id) = choice {
            let catalog = try await contentRepository.fetchCatalog()
            let progress = DadProgress(events: try await progressRepository.fetchEvents(), catalog: catalog)
            let earned = GearRules.earned(catalog.gear, skillXP: progress.skillXP)
            guard earned.contains(where: { $0.id == id && $0.skill == skill }) else { throw OutfitError.notEarned(id) }
        }
        return try await outfitRepository.setChoice(choice, for: skill)
    }
}
