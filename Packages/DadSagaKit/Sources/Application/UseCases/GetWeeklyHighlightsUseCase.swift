import Domain
import Foundation

/// What a glance outside the app shows for one child this week: the weekly quest and the latest legendary moment
/// (ADR-0023). Not tied to the widget, so the weekly notification can suggest the same quest.
public struct WeeklyHighlights: Hashable, Sendable {
    public enum QuestSlot: Hashable, Sendable {
        /// The quest of the week, and whether the dad already did it with this child this week.
        case suggested(Quest, isDone: Bool)
        /// No quest fits this age (the child is older than every world): adventures for it are coming.
        case comingSoon
    }

    public let child: Child
    /// Children in the family; a name only matters when there is more than one.
    public let childCount: Int
    public let quest: QuestSlot
    public let latestMoment: CapturedMoment?
    /// A small copy of the moment's cover photo, only when one was asked for and exists.
    public let momentPhoto: Data?
    /// The start of the next week, when the quest changes.
    public let validUntil: Date

    public init(
        child: Child,
        childCount: Int,
        quest: QuestSlot,
        latestMoment: CapturedMoment?,
        momentPhoto: Data?,
        validUntil: Date
    ) {
        self.child = child
        self.childCount = childCount
        self.quest = quest
        self.latestMoment = latestMoment
        self.momentPhoto = momentPhoto
        self.validUntil = validUntil
    }
}

public protocol GetWeeklyHighlightsUseCase: Sendable {
    /// `childID` falls back to the first child when it is `nil` or no longer in the family. `nil` before onboarding.
    /// Pass `photoMaxPixelSize` to get a thumbnail of the moment's photo; `nil` loads no photo.
    func execute(childID: UUID?, on date: Date, photoMaxPixelSize: Int?) async throws -> WeeklyHighlights?
}

public struct DefaultGetWeeklyHighlightsUseCase: GetWeeklyHighlightsUseCase {
    private let contentRepository: any ContentRepository
    private let profileRepository: any ProfileRepository
    private let progressRepository: any ProgressRepository
    private let photoStore: any PhotoStore
    private let calendar: Calendar

    public init(
        contentRepository: any ContentRepository,
        profileRepository: any ProfileRepository,
        progressRepository: any ProgressRepository,
        photoStore: any PhotoStore,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.contentRepository = contentRepository
        self.profileRepository = profileRepository
        self.progressRepository = progressRepository
        self.photoStore = photoStore
        self.calendar = calendar
    }

    public func execute(childID: UUID?, on date: Date, photoMaxPixelSize: Int?) async throws -> WeeklyHighlights? {
        guard let profile = try await profileRepository.fetchProfile(),
              let child = profile.children.first(where: { $0.id == childID }) ?? profile.children.first
        else { return nil }
        let catalog = try await contentRepository.fetchCatalog()
        let events = try await progressRepository.fetchEvents()
        let week = WeeklyQuest.week(containing: date, calendar: calendar)
        let moment = DadProgress(events: events, catalog: catalog).moments(for: child.id).first
        var photo: Data?
        if let maxPixelSize = photoMaxPixelSize, let photoID = moment?.coverPhotoID {
            photo = await photoStore.thumbnail(id: photoID, maxPixelSize: maxPixelSize)
        }
        return WeeklyHighlights(
            child: child,
            childCount: profile.children.count,
            quest: questSlot(for: child, week: week, catalog: catalog, events: events),
            latestMoment: moment,
            momentPhoto: photo,
            validUntil: week.end
        )
    }

    /// The age is taken at the start of the week, so a birthday mid-week does not swap the card.
    private func questSlot(
        for child: Child,
        week: DateInterval,
        catalog: ContentCatalog,
        events: [ProgressEvent]
    ) -> WeeklyHighlights.QuestSlot {
        let age = child.ageInMonths(at: week.start, calendar: calendar)
        guard !UnlockRules.isBeyondContent(catalog, ageInMonths: age),
              let world = UnlockRules.currentWorld(in: catalog, ageInMonths: age),
              let quest = WeeklyQuest.pick(
                  from: UnlockRules.quests(for: world, in: catalog, ageInMonths: age),
                  childID: child.id,
                  week: week,
                  calendar: calendar
              )
        else { return .comingSoon }
        return .suggested(quest, isDone: WeeklyQuest.isDone(quest, childID: child.id, week: week, events: events))
    }
}
