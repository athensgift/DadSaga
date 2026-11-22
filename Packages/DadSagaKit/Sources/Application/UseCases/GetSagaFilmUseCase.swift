import Domain
import Foundation

/// Everything a saga film shows for one child and one period (ADR-0036): its scenes, and the hero and the child as they
/// were when the period ended. The film sheet's one query (ADR-0028).
public struct SagaFilm: Sendable {
    public let profile: PlayerProfile
    /// The child the film is about.
    public let child: Child
    public let catalog: ContentCatalog
    public let storyboard: SagaStoryboard
    /// The periods the dad can choose instead, in order: only those with something in them, and everything.
    public let availablePeriods: [SagaPeriod]
    /// Bosses beaten with any child before `storyboard.asOf`, as home counts the hero's medals.
    public let medalCount: Int
    /// This child's firsts captured before `storyboard.asOf`, in content order: what the child is drawn doing.
    public let childFirsts: [FirstMoment]
    /// What the hero wore then: the gear he had by then, chosen with today's wardrobe.
    public let equippedGear: [GearItem]
    /// The dad's title then, for the credits (ADR-0055 §9). Today's for a film that runs to today.
    public let title: DadTitle?
    /// Every bundled track, in order: the choices (ADR-0046 §2).
    public let soundtracks: [Soundtrack]
    /// The remembered one, or the first when none was chosen or it is no longer bundled (ADR-0046 §4).
    public let soundtrack: Soundtrack
    /// Whether the film shows its dates: the switch on the film sheet, remembered (ADR-0041 §5).
    public let showsDates: Bool

    public var period: SagaPeriod { storyboard.period }

    /// Public so the film sheet's tests can stand in for the use case, like `HomeOverview`'s.
    public init(
        profile: PlayerProfile,
        child: Child,
        catalog: ContentCatalog,
        storyboard: SagaStoryboard,
        availablePeriods: [SagaPeriod],
        medalCount: Int,
        childFirsts: [FirstMoment],
        equippedGear: [GearItem],
        title: DadTitle?,
        soundtracks: [Soundtrack],
        soundtrack: Soundtrack,
        showsDates: Bool
    ) {
        self.profile = profile
        self.child = child
        self.catalog = catalog
        self.storyboard = storyboard
        self.availablePeriods = availablePeriods
        self.medalCount = medalCount
        self.childFirsts = childFirsts
        self.equippedGear = equippedGear
        self.title = title
        self.soundtracks = soundtracks
        self.soundtrack = soundtrack
        self.showsDates = showsDates
    }
}

public enum SagaFilmError: Error, Equatable {
    /// No music is bundled: the app is broken, not the saga.
    case noSoundtrack
}

public protocol GetSagaFilmUseCase: Sendable {
    /// `childID` falls back to the first child when it is `nil` or no longer in the family. `period` falls back to
    /// today's occasion (a birthday or a new world, answered or not), else to everything; a period that hasn't started
    /// also means everything. `nil` while there is no family.
    func execute(childID: UUID?, period: SagaPeriod?, on date: Date) async throws -> SagaFilm?
}

public struct DefaultGetSagaFilmUseCase: GetSagaFilmUseCase {
    private let contentRepository: any ContentRepository
    private let profileRepository: any ProfileRepository
    private let progressRepository: any ProgressRepository
    private let outfitRepository: any OutfitRepository
    private let standingRepository: any StandingRepository
    private let soundtrackRepository: any SoundtrackRepository
    private let choicesRepository: any SagaFilmChoicesRepository
    private let timeZone: TimeZone

    public init(
        contentRepository: any ContentRepository,
        profileRepository: any ProfileRepository,
        progressRepository: any ProgressRepository,
        outfitRepository: any OutfitRepository,
        standingRepository: any StandingRepository,
        soundtrackRepository: any SoundtrackRepository,
        choicesRepository: any SagaFilmChoicesRepository,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.contentRepository = contentRepository
        self.profileRepository = profileRepository
        self.progressRepository = progressRepository
        self.outfitRepository = outfitRepository
        self.standingRepository = standingRepository
        self.soundtrackRepository = soundtrackRepository
        self.choicesRepository = choicesRepository
        self.timeZone = timeZone
    }

    public func execute(childID: UUID?, period: SagaPeriod?, on date: Date) async throws -> SagaFilm? {
        async let pendingCatalog = contentRepository.fetchCatalog()
        async let pendingEvents = progressRepository.fetchEvents()
        async let pendingOutfit = outfitRepository.fetchOutfit()
        async let pendingKept = standingRepository.fetchKept()
        async let pendingSoundtracks = soundtrackRepository.fetchSoundtracks()
        async let pendingShowsDates = choicesRepository.showsDates()
        async let pendingSoundtrackID = choicesRepository.soundtrackID()
        guard let profile = try await profileRepository.fetchProfile(),
              let child = profile.child(childID)
        else { return nil }
        let soundtracks = try await pendingSoundtracks
        guard let first = soundtracks.first else { throw SagaFilmError.noSoundtrack }
        let chosenID = await pendingSoundtrackID
        let soundtrack = soundtracks.first { $0.id == chosenID } ?? first
        let catalog = try await pendingCatalog
        let events = try await pendingEvents

        let chosen = period
            ?? SagaOccasions.latest(for: child, events: events, catalog: catalog, on: date, timeZone: timeZone)?.period
            ?? .everything
        let storyboard = [chosen, .everything].lazy.compactMap {
            SagaStoryboard.make(
                events: events, child: child, period: $0, catalog: catalog, now: date, timeZone: timeZone
            )
        }.first
        guard let storyboard else { preconditionFailure("Everything always has an interval") }
        let progress = DadProgress(events: events.filter { $0.date < storyboard.asOf }, catalog: catalog)
        let firsts = progress.capturedFirstIDs(for: child.id)
        let kept = try await pendingKept
        // A film that runs to today shows the dad as home does, so it never shows a lower title (ADR-0055 §9).
        let standing = storyboard.asOf >= date
            ? DadStanding(progress: DadProgress(events: events, catalog: catalog), catalog: catalog, kept: kept)
            : DadStanding.asOf(progress, catalog: catalog)
        return SagaFilm(
            profile: profile,
            child: child,
            catalog: catalog,
            storyboard: storyboard,
            availablePeriods: SagaPeriod.available(
                for: child, events: events, catalog: catalog, now: date, timeZone: timeZone
            ),
            medalCount: progress.allDefeatedBossIDs.count,
            childFirsts: catalog.firsts.filter { firsts.contains($0.id) },
            equippedGear: GearRules.equipped(standing.gear, outfit: try await pendingOutfit),
            title: standing.title,
            soundtracks: soundtracks,
            soundtrack: soundtrack,
            showsDates: await pendingShowsDates
        )
    }
}
