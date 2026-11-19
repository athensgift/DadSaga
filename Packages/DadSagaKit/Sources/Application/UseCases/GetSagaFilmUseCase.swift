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
    /// What the hero wore then: the gear earned by then, chosen with today's wardrobe.
    public let equippedGear: [GearItem]
    public let soundtrack: Soundtrack

    public var period: SagaPeriod { storyboard.period }
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
    private let soundtrackRepository: any SoundtrackRepository
    private let calendar: Calendar

    public init(
        contentRepository: any ContentRepository,
        profileRepository: any ProfileRepository,
        progressRepository: any ProgressRepository,
        outfitRepository: any OutfitRepository,
        soundtrackRepository: any SoundtrackRepository,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.contentRepository = contentRepository
        self.profileRepository = profileRepository
        self.progressRepository = progressRepository
        self.outfitRepository = outfitRepository
        self.soundtrackRepository = soundtrackRepository
        self.calendar = calendar
    }

    public func execute(childID: UUID?, period: SagaPeriod?, on date: Date) async throws -> SagaFilm? {
        async let pendingCatalog = contentRepository.fetchCatalog()
        async let pendingEvents = progressRepository.fetchEvents()
        async let pendingOutfit = outfitRepository.fetchOutfit()
        async let pendingSoundtracks = soundtrackRepository.fetchSoundtracks()
        guard let profile = try await profileRepository.fetchProfile(),
              let child = profile.child(childID)
        else { return nil }
        guard let soundtrack = try await pendingSoundtracks.first else { throw SagaFilmError.noSoundtrack }
        let catalog = try await pendingCatalog
        let events = try await pendingEvents

        let chosen = period
            ?? SagaOccasions.latest(for: child, events: events, catalog: catalog, on: date, calendar: calendar)?.period
            ?? .everything
        let storyboard = [chosen, .everything].lazy.compactMap {
            SagaStoryboard.make(
                events: events, child: child, period: $0, catalog: catalog, now: date, calendar: calendar
            )
        }.first
        guard let storyboard else { preconditionFailure("Everything always has an interval") }
        let progress = DadProgress(events: events.filter { $0.date < storyboard.asOf }, catalog: catalog)
        let firsts = progress.capturedFirstIDs(for: child.id)
        return SagaFilm(
            profile: profile,
            child: child,
            catalog: catalog,
            storyboard: storyboard,
            availablePeriods: SagaPeriod.available(
                for: child, events: events, catalog: catalog, now: date, calendar: calendar
            ),
            medalCount: progress.allDefeatedBossIDs.count,
            childFirsts: catalog.firsts.filter { firsts.contains($0.id) },
            equippedGear: GearRules.equipped(catalog.gear, skillXP: progress.skillXP, outfit: try await pendingOutfit),
            soundtrack: soundtrack
        )
    }
}
