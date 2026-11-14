import Domain
import Foundation

/// Records that the dad got through a boss fight in real life with one of his children. Each boss gives its badge and
/// XP once per child; confirming an already defeated boss changes nothing.
public protocol DefeatBossUseCase: Sendable {
    func execute(bossID: String, childID: UUID, on date: Date) async throws -> ProgressChange
}

public struct DefaultDefeatBossUseCase: DefeatBossUseCase {
    private let contentRepository: any ContentRepository
    private let progressRepository: any ProgressRepository

    public init(contentRepository: any ContentRepository, progressRepository: any ProgressRepository) {
        self.contentRepository = contentRepository
        self.progressRepository = progressRepository
    }

    public func execute(bossID: String, childID: UUID, on date: Date) async throws -> ProgressChange {
        let catalog = try await contentRepository.fetchCatalog()
        guard catalog.bosses.contains(where: { $0.id == bossID }) else {
            throw ProgressError.unknownBoss(bossID)
        }
        let events = try await progressRepository.fetchEvents()
        let before = DadProgress(events: events, catalog: catalog)
        guard !before.defeatedBossIDs(for: childID).contains(bossID) else {
            return ProgressChange(before: before, after: before)
        }
        let event = ProgressEvent(kind: .boss(id: bossID), childID: childID, date: date)
        try await progressRepository.add(event)
        return ProgressChange(before: before, after: DadProgress(events: events + [event], catalog: catalog))
    }
}
