import Domain
import Foundation

/// Records that the dad got through a boss fight in real life with one of his children. Each boss gives its badge and
/// XP once per child; confirming an already defeated boss changes nothing.
public protocol DefeatBossUseCase: Sendable {
    func execute(bossID: String, childID: UUID, on date: Date, journal: JournalInput) async throws -> ProgressChange
}

public struct DefaultDefeatBossUseCase: DefeatBossUseCase {
    private let contentRepository: any ContentRepository
    private let progressRepository: any ProgressRepository
    private let recorder: EventRecorder

    public init(
        contentRepository: any ContentRepository,
        progressRepository: any ProgressRepository,
        photoStore: any PhotoStore
    ) {
        self.contentRepository = contentRepository
        self.progressRepository = progressRepository
        recorder = EventRecorder(progressRepository: progressRepository, photoStore: photoStore)
    }

    public func execute(bossID: String, childID: UUID, on date: Date, journal: JournalInput) async throws -> ProgressChange {
        let catalog = try await contentRepository.fetchCatalog()
        guard catalog.bosses.contains(where: { $0.id == bossID }) else {
            throw ProgressError.unknownBoss(bossID)
        }
        let events = try await progressRepository.fetchEvents()
        let before = DadProgress(events: events, catalog: catalog)
        guard !before.defeatedBossIDs(for: childID).contains(bossID) else {
            return ProgressChange(before: before, after: before, eventID: nil)
        }
        let event = try await recorder.record(.boss(id: bossID), childID: childID, date: date, journal: journal)
        return ProgressChange(
            before: before,
            after: DadProgress(events: events + [event], catalog: catalog),
            eventID: event.id
        )
    }
}
