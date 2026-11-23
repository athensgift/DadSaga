import Domain
import Foundation

/// Finds one of the player's own entries, to edit or to remove with its photos: what deleting, undoing and editing
/// share. Each parent edits and removes only what they recorded (ADR-0065 §3.4).
struct OwnEntries {
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
