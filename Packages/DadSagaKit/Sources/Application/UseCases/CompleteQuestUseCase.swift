import Domain
import Foundation

/// Records that the dad did a quest in real life, with one of his children, and anything he wrote or photographed.
/// Quests are repeatable and always give their XP.
public protocol CompleteQuestUseCase: Sendable {
    func execute(questID: String, childID: UUID, on date: Date, journal: JournalInput) async throws -> ProgressChange
}

public struct DefaultCompleteQuestUseCase: CompleteQuestUseCase {
    private let recorder: ProgressRecorder

    public init(
        contentRepository: any ContentRepository,
        progressRepository: any ProgressRepository,
        photoStore: any PhotoStore
    ) {
        recorder = ProgressRecorder(
            contentRepository: contentRepository, progressRepository: progressRepository, photoStore: photoStore
        )
    }

    public func execute(questID: String, childID: UUID, on date: Date, journal: JournalInput) async throws -> ProgressChange {
        try await recorder.record(
            .quest(id: questID), childID: childID, date: date, journal: journal, unknown: ProgressError.unknownQuest(questID)
        )
    }
}
