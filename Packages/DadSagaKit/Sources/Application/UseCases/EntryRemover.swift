import Domain
import Foundation

/// Finds one of the dad's entries and removes it with its photos: what deleting and undoing share.
struct EntryRemover {
    let progressRepository: any ProgressRepository
    let photoStore: any PhotoStore

    /// The entry and every entry, read once. Throws `ProgressError.unknownEvent` when it isn't there.
    func find(_ eventID: UUID) async throws -> (entry: ProgressEvent, all: [ProgressEvent]) {
        let events = try await progressRepository.fetchEvents()
        guard let event = events.first(where: { $0.id == eventID }) else { throw ProgressError.unknownEvent }
        return (event, events)
    }

    func remove(_ event: ProgressEvent) async throws {
        try await progressRepository.delete(id: event.id)
        for photoID in event.photoIDs {
            await photoStore.delete(id: photoID)
        }
    }
}
