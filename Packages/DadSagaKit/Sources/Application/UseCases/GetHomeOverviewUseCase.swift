import Domain
import Foundation

/// Everything home shows for one child: the family, the child's adventure, which world's quests and bosses are on
/// screen, and what the hero wears. Home's one query: the presenter only turns it into what the screen displays.
public struct HomeOverview: Sendable {
    public let profile: PlayerProfile
    /// The child home is about.
    public let child: Child
    public let catalog: ContentCatalog
    public let adventure: Adventure
    public let progress: DadProgress
    /// The world whose quests and bosses are shown: an earlier one the dad chose on the map, or the current one.
    public let shownWorld: World?
    /// The shown world's quests for the child's age, evergreen ones from earlier worlds included (ADR-0020).
    public let quests: [Quest]
    /// The shown world's bosses this family can meet.
    public let bosses: [BossFight]
    /// What the hero wears, one item per skill at most.
    public let equippedGear: [GearItem]

    public var childCount: Int { profile.children.count }

    /// The child with `id`, or the first child when `id` is `nil` or no longer in the family. `nil` without children.
    public static func child(_ id: UUID?, in profile: PlayerProfile) -> Child? {
        profile.children.first { $0.id == id } ?? profile.children.first
    }
    public var isShowingCurrentWorld: Bool { shownWorld?.id == adventure.currentWorld?.id }
    public var defeatedBossIDs: Set<String> { progress.defeatedBossIDs(for: child.id) }

    /// - Parameter worldID: a world the dad chose on the map; ignored unless it is unlocked for this child.
    public init(
        profile: PlayerProfile,
        child: Child,
        catalog: ContentCatalog,
        adventure: Adventure,
        progress: DadProgress,
        outfit: Outfit,
        worldID: String?
    ) {
        self.profile = profile
        self.child = child
        self.catalog = catalog
        self.adventure = adventure
        self.progress = progress
        let shownWorld = adventure.unlockedWorlds.first { $0.id == worldID } ?? adventure.currentWorld
        self.shownWorld = shownWorld
        quests = shownWorld.map { UnlockRules.quests(for: $0, in: catalog, ageInMonths: adventure.ageInMonths) } ?? []
        bosses = adventure.availableBosses.filter { $0.worldID == shownWorld?.id }
        equippedGear = GearRules.equipped(catalog.gear, skillXP: progress.skillXP, outfit: outfit)
    }
}

public protocol GetHomeOverviewUseCase: Sendable {
    /// `childID` falls back to the first child when it is `nil` or no longer in the family, and `worldID` to the
    /// child's current world. `nil` while there is no family.
    func execute(childID: UUID?, worldID: String?, on date: Date) async throws -> HomeOverview?
}

public struct DefaultGetHomeOverviewUseCase: GetHomeOverviewUseCase {
    private let contentRepository: any ContentRepository
    private let profileRepository: any ProfileRepository
    private let progressRepository: any ProgressRepository
    private let outfitRepository: any OutfitRepository
    private let calendar: Calendar

    public init(
        contentRepository: any ContentRepository,
        profileRepository: any ProfileRepository,
        progressRepository: any ProgressRepository,
        outfitRepository: any OutfitRepository,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.contentRepository = contentRepository
        self.profileRepository = profileRepository
        self.progressRepository = progressRepository
        self.outfitRepository = outfitRepository
        self.calendar = calendar
    }

    public func execute(childID: UUID?, worldID: String?, on date: Date) async throws -> HomeOverview? {
        async let pendingCatalog = contentRepository.fetchCatalog()
        async let pendingEvents = progressRepository.fetchEvents()
        async let pendingOutfit = outfitRepository.fetchOutfit()
        guard let profile = try await profileRepository.fetchProfile(),
              let child = HomeOverview.child(childID, in: profile)
        else { return nil }
        let catalog = try await pendingCatalog
        return HomeOverview(
            profile: profile,
            child: child,
            catalog: catalog,
            adventure: Adventure(
                for: child, childCount: profile.children.count, catalog: catalog, on: date, calendar: calendar
            ),
            progress: DadProgress(events: try await pendingEvents, catalog: catalog),
            outfit: try await pendingOutfit,
            worldID: worldID
        )
    }
}
