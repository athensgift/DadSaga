import Domain

/// The hero's wardrobe: the family's dad, the gear he has, his progress and what he chose to wear. Only what he has:
/// an item not earned yet would tell him what the next title brings (ADR-0055 §8).
public struct Wardrobe: Sendable {
    public let profile: PlayerProfile?
    /// The dad's hero class, if the content still has it.
    public let hero: HeroClass?
    /// Every item he has, by slot, the best last in each.
    public let earned: [GearItem]
    public let progress: DadProgress
    public var outfit: Outfit

    /// What the hero wears with the current choices.
    public var equipped: [GearItem] { GearRules.equipped(earned, outfit: outfit) }

    public init(profile: PlayerProfile?, hero: HeroClass?, earned: [GearItem], progress: DadProgress, outfit: Outfit) {
        self.profile = profile
        self.hero = hero
        self.earned = earned
        self.progress = progress
        self.outfit = outfit
    }

    public func isEarned(itemID: String, skill: Skill) -> Bool {
        earned.contains { $0.has(id: itemID) && $0.skill == skill }
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
    private let standingRepository: any StandingRepository

    public init(
        contentRepository: any ContentRepository,
        profileRepository: any ProfileRepository,
        progressRepository: any ProgressRepository,
        outfitRepository: any OutfitRepository,
        standingRepository: any StandingRepository
    ) {
        self.contentRepository = contentRepository
        self.profileRepository = profileRepository
        self.progressRepository = progressRepository
        self.outfitRepository = outfitRepository
        self.standingRepository = standingRepository
    }

    public func execute() async throws -> Wardrobe {
        async let pendingCatalog = contentRepository.fetchCatalog()
        async let pendingProfile = profileRepository.fetchProfile()
        async let pendingEvents = progressRepository.fetchEvents()
        async let pendingOutfit = outfitRepository.fetchOutfit()
        async let pendingKept = standingRepository.fetchKept()
        let catalog = try await pendingCatalog
        let profile = try await pendingProfile
        let events = try await pendingEvents
        let progress = profile.map { DadProgress(of: $0, events: events, catalog: catalog) } ?? .none
        return Wardrobe(
            profile: profile,
            hero: profile.flatMap(catalog.hero(for:)),
            earned: DadStanding(progress: progress, catalog: catalog, kept: try await pendingKept).gear,
            progress: progress,
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
    private let profileRepository: any ProfileRepository
    private let progressRepository: any ProgressRepository
    private let outfitRepository: any OutfitRepository
    private let standingRepository: any StandingRepository

    public init(
        contentRepository: any ContentRepository,
        profileRepository: any ProfileRepository,
        progressRepository: any ProgressRepository,
        outfitRepository: any OutfitRepository,
        standingRepository: any StandingRepository
    ) {
        self.contentRepository = contentRepository
        self.profileRepository = profileRepository
        self.progressRepository = progressRepository
        self.outfitRepository = outfitRepository
        self.standingRepository = standingRepository
    }

    public func execute(skill: Skill, choice: OutfitChoice) async throws -> Outfit {
        if case .item(let id) = choice {
            let catalog = try await contentRepository.fetchCatalog()
            let events = try await progressRepository.fetchEvents()
            let progress = try await profileRepository.fetchProfile()
                .map { DadProgress(of: $0, events: events, catalog: catalog) } ?? .none
            let earned = DadStanding(progress: progress, catalog: catalog, kept: try await standingRepository.fetchKept()).gear
            guard earned.contains(where: { $0.id == id && $0.skill == skill }) else { throw OutfitError.notEarned(id) }
        }
        return try await outfitRepository.setChoice(choice, for: skill)
    }
}
