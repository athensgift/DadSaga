import Domain
import Foundation

/// Everything the family has done, newest first.
public protocol GetTimelineUseCase: Sendable {
    func execute() async throws -> [TimelineEntry]
}

/// Lists only the entries of children in the family: a child removed from it takes their entries off the timeline,
/// though they still count for their author (ADR-0012, ADR-0065 §5). No profile, no entries.
public struct DefaultGetTimelineUseCase: GetTimelineUseCase {
    private let contentRepository: any ContentRepository
    private let progressRepository: any ProgressRepository
    private let profileRepository: any ProfileRepository

    public init(
        contentRepository: any ContentRepository,
        progressRepository: any ProgressRepository,
        profileRepository: any ProfileRepository
    ) {
        self.contentRepository = contentRepository
        self.progressRepository = progressRepository
        self.profileRepository = profileRepository
    }

    public func execute() async throws -> [TimelineEntry] {
        async let profile = profileRepository.fetchProfile()
        let catalog = try await contentRepository.fetchCatalog()
        let entries = Timeline.entries(from: try await progressRepository.fetchEvents(), catalog: catalog)
        let family = Set(try await profile?.children.map(\.id) ?? [])
        return entries.filter { family.contains($0.childID) }
    }
}
