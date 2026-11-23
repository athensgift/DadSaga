import Domain
import Foundation

/// Finds one of the dad's entries and removes it with its photos: what deleting and undoing share. Only the player's
/// own entries: each parent removes only what they recorded (ADR-0065 §3.4).
struct EntryRemover {
    let profileRepository: any ProfileRepository
    let progressRepository: any ProgressRepository
    let photoStore: any PhotoStore

    /// An entry of the player's, found among every entry.
    struct Found {
        let player: PlayerProfile
        let entry: ProgressEvent
        let all: [ProgressEvent]
    }

    /// The player, the entry and every entry, read once. Throws `ProgressError.unknownEvent` when the entry isn't
    /// there, `ProgressError.notYourEntry` when another parent recorded it, and `ProgressError.noProfile` before
    /// onboarding.
    func find(_ eventID: UUID) async throws -> Found {
        guard let player = try await profileRepository.fetchProfile() else { throw ProgressError.noProfile }
        let events = try await progressRepository.fetchEvents()
        guard let event = events.first(where: { $0.id == eventID }) else { throw ProgressError.unknownEvent }
        guard event.authorID == player.id else { throw ProgressError.notYourEntry }
        return Found(player: player, entry: event, all: events)
    }

    func remove(_ event: ProgressEvent) async throws {
        try await progressRepository.delete(id: event.id)
        for photoID in event.photoIDs {
            await photoStore.delete(id: photoID)
        }
    }
}
