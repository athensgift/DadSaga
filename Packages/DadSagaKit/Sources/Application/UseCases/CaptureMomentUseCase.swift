import Domain
import Foundation

public enum MomentError: Error, Equatable {
    case unknownFirst(String)
    case alreadyCaptured(String)
    case dateInFuture
}

/// Records a legendary moment (a first) for one child. Each first counts once per child and gives its XP then.
/// The date is when it happened, so a dad can catch up on firsts from before he had the app.
public protocol CaptureMomentUseCase: Sendable {
    func execute(firstID: String, childID: UUID, happenedOn date: Date, note: String?, now: Date) async throws -> ProgressChange
}

public struct DefaultCaptureMomentUseCase: CaptureMomentUseCase {
    private let contentRepository: any ContentRepository
    private let progressRepository: any ProgressRepository

    public init(contentRepository: any ContentRepository, progressRepository: any ProgressRepository) {
        self.contentRepository = contentRepository
        self.progressRepository = progressRepository
    }

    public func execute(
        firstID: String,
        childID: UUID,
        happenedOn date: Date,
        note: String?,
        now: Date
    ) async throws -> ProgressChange {
        let catalog = try await contentRepository.fetchCatalog()
        guard catalog.firsts.contains(where: { $0.id == firstID }) else { throw MomentError.unknownFirst(firstID) }
        guard date <= now else { throw MomentError.dateInFuture }
        let events = try await progressRepository.fetchEvents()
        let before = DadProgress(events: events, catalog: catalog)
        guard !before.capturedFirstIDs(for: childID).contains(firstID) else { throw MomentError.alreadyCaptured(firstID) }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = ProgressEvent(
            kind: .first(id: firstID),
            childID: childID,
            date: date,
            note: trimmed?.isEmpty == false ? trimmed : nil
        )
        try await progressRepository.add(event)
        return ProgressChange(before: before, after: DadProgress(events: events + [event], catalog: catalog))
    }
}
