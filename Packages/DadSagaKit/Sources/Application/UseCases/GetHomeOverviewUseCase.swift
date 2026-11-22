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
    /// The shown world's quests offered to this child and family, evergreen ones from earlier worlds included
    /// (ADR-0020, ADR-0053).
    public let quests: [Quest]
    /// The shown world's bosses offered to this child and family, evergreen ones included, without the situational ones.
    public let bosses: [BossFight]
    /// The shown world's bosses for when life changes: home keeps them in one closed row (ADR-0053 §5).
    public let situationalBosses: [BossFight]
    /// The dad's title, the gear he has and a title card not closed yet (ADR-0055).
    public let standing: DadStanding
    /// What the hero wears, one item per skill at most.
    public let equippedGear: [GearItem]
    /// How much each of the four skills has grown, in `Skill.allCases` order (ADR-0059 §2). From the entries alone: an
    /// undo or a deletion takes back what its card gave.
    public let skills: [SkillGrowth]
    /// The one film to offer the family today, if the dad hasn't answered it (ADR-0037 §5). It can be about a child
    /// other than the one home shows.
    public let sagaOffer: SagaOccasion?
    /// The day home is read on, in the phone's time zone: every child's age is counted to it.
    public let today: CalendarDay

    /// Who the cards are for in this family.
    public var family: FamilyFacts { adventure.family }

    public var isShowingCurrentWorld: Bool { shownWorld?.id == adventure.currentWorld?.id }
    public var defeatedBossIDs: Set<String> { progress.defeatedBossIDs(for: child.id) }

    /// - Parameter worldID: a world the dad chose on the map; ignored unless it is unlocked for this child.
    public init(
        profile: PlayerProfile,
        child: Child,
        catalog: ContentCatalog,
        adventure: Adventure,
        progress: DadProgress,
        kept: KeptStanding,
        outfit: Outfit,
        worldID: String?,
        sagaOffer: SagaOccasion? = nil,
        today: CalendarDay
    ) {
        self.profile = profile
        self.child = child
        self.catalog = catalog
        self.adventure = adventure
        self.progress = progress
        let shownWorld = adventure.unlockedWorlds.first { $0.id == worldID } ?? adventure.currentWorld
        self.shownWorld = shownWorld
        let age = adventure.age
        let family = adventure.family
        quests = shownWorld.map { UnlockRules.quests(for: $0, in: catalog, age: age, family: family) } ?? []
        let bosses = shownWorld.map { UnlockRules.bosses(for: $0, in: catalog, age: age, family: family) } ?? []
        self.bosses = bosses.filter { !$0.isSituational }
        situationalBosses = bosses.filter(\.isSituational)
        let standing = DadStanding(progress: progress, catalog: catalog, kept: kept)
        self.standing = standing
        equippedGear = GearRules.equipped(standing.gear, outfit: outfit)
        skills = SkillGrowth.all(progress, catalog: catalog)
        self.sagaOffer = sagaOffer
        self.today = today
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
    private let standingRepository: any StandingRepository
    private let sagaOfferRepository: any SagaOfferRepository
    private let timeZone: TimeZone

    public init(
        contentRepository: any ContentRepository,
        profileRepository: any ProfileRepository,
        progressRepository: any ProgressRepository,
        outfitRepository: any OutfitRepository,
        standingRepository: any StandingRepository,
        sagaOfferRepository: any SagaOfferRepository,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.contentRepository = contentRepository
        self.profileRepository = profileRepository
        self.progressRepository = progressRepository
        self.outfitRepository = outfitRepository
        self.standingRepository = standingRepository
        self.sagaOfferRepository = sagaOfferRepository
        self.timeZone = timeZone
    }

    public func execute(childID: UUID?, worldID: String?, on date: Date) async throws -> HomeOverview? {
        async let pendingCatalog = contentRepository.fetchCatalog()
        async let pendingEvents = progressRepository.fetchEvents()
        async let pendingOutfit = outfitRepository.fetchOutfit()
        async let pendingKept = standingRepository.fetchKept()
        async let answeredOffers = sagaOfferRepository.answeredOccasionIDs()
        guard let profile = try await profileRepository.fetchProfile(),
              let child = profile.child(childID)
        else { return nil }
        let catalog = try await pendingCatalog
        let events = try await pendingEvents
        let today = CalendarDay(date, in: timeZone)
        return HomeOverview(
            profile: profile,
            child: child,
            catalog: catalog,
            adventure: Adventure(
                for: child, family: FamilyFacts(profile: profile, child: child), catalog: catalog, on: today
            ),
            progress: DadProgress(events: events, catalog: catalog),
            kept: try await pendingKept,
            outfit: try await pendingOutfit,
            worldID: worldID,
            sagaOffer: SagaOccasions.latest(
                forFamily: profile.children, events: events, catalog: catalog, on: date,
                answered: await answeredOffers, timeZone: timeZone
            ),
            today: today
        )
    }
}
