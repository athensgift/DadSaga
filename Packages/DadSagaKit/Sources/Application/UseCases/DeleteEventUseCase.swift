import Domain
import Foundation

/// Removes something the dad recorded (a quest, a boss or a moment), with its photos and the XP it gave.
/// Used for undoing a tap made by mistake and for deleting an entry from the timeline. This is the dad correcting his
/// own log, not the game taking something away (ADR-0006, ADR-0021): levels, gear and badges follow from the events,
/// so they go back to what they would be without this one.
public protocol DeleteEventUseCase: Sendable {
    func execute(eventID: UUID) async throws
}

public struct DefaultDeleteEventUseCase: DeleteEventUseCase {
    private let progressRepository: any ProgressRepository
    private let photoStore: any PhotoStore

    public init(progressRepository: any ProgressRepository, photoStore: any PhotoStore) {
        self.progressRepository = progressRepository
        self.photoStore = photoStore
    }

    public func execute(eventID: UUID) async throws {
        guard let event = try await progressRepository.fetchEvents().first(where: { $0.id == eventID }) else {
            throw ProgressError.unknownEvent
        }
        try await progressRepository.delete(id: eventID)
        for photoID in event.photoIDs {
            await photoStore.delete(id: photoID)
        }
    }
}
