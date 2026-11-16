import Domain
import Foundation

/// What completing something did to the dad's progress.
public struct ProgressChange: Hashable, Sendable {
    public let before: DadProgress
    public let after: DadProgress
    /// The event that was recorded, so the dad can undo it. `nil` when nothing was recorded.
    public let eventID: UUID?

    public var gainedXP: Int { after.totalXP - before.totalXP }
    public var leveledUp: Bool { after.level.level > before.level.level }

    public init(before: DadProgress, after: DadProgress, eventID: UUID?) {
        self.before = before
        self.after = after
        self.eventID = eventID
    }
}

public enum ProgressError: Error, Equatable {
    case unknownQuest(String)
    case unknownBoss(String)
    case unknownEvent
}

/// Records that the dad did a quest in real life, with one of his children. Quests are repeatable and always give
/// their XP.
public protocol CompleteQuestUseCase: Sendable {
    func execute(questID: String, childID: UUID, on date: Date) async throws -> ProgressChange
}

public struct DefaultCompleteQuestUseCase: CompleteQuestUseCase {
    private let contentRepository: any ContentRepository
    private let progressRepository: any ProgressRepository

    public init(contentRepository: any ContentRepository, progressRepository: any ProgressRepository) {
        self.contentRepository = contentRepository
        self.progressRepository = progressRepository
    }

    public func execute(questID: String, childID: UUID, on date: Date) async throws -> ProgressChange {
        let catalog = try await contentRepository.fetchCatalog()
        guard catalog.quests.contains(where: { $0.id == questID }) else {
            throw ProgressError.unknownQuest(questID)
        }
        let events = try await progressRepository.fetchEvents()
        let event = ProgressEvent(kind: .quest(id: questID), childID: childID, date: date)
        try await progressRepository.add(event)
        return ProgressChange(
            before: DadProgress(events: events, catalog: catalog),
            after: DadProgress(events: events + [event], catalog: catalog),
            eventID: event.id
        )
    }
}
