import Domain
import Foundation

/// Brings a removed child back into the family, in their place, with every entry (ADR-0065 §4). Bringing back is
/// adding: refused with `ProfileValidationError.tooManyChildren` while the family holds `PlayerProfile.maxChildren` or
/// more, and with `ProfileEditError.notRemoved` for a child who isn't removed. The store refuses both, in its own
/// write, against the family as it is then (ADR-0068 §3). It changes no one's standing: their entries counted for
/// their author all along (ADR-0006 §2).
public protocol BringBackChildUseCase: Sendable {
    func execute(childID: UUID) async throws
}

public struct DefaultBringBackChildUseCase: BringBackChildUseCase {
    private let profileRepository: any ProfileRepository

    public init(profileRepository: any ProfileRepository) {
        self.profileRepository = profileRepository
    }

    public func execute(childID: UUID) async throws {
        guard try await profileRepository.fetchProfile() != nil else { throw ProfileEditError.noProfile }
        try await profileRepository.bringBack(childID: childID)
    }
}

/// Deletes a removed child for good: the child, every entry with them, whoever recorded it, and their photos
/// (ADR-0065 §4), and no note names them. The one way a child and their entries go. Those entries' XP and skill marks
/// go, as a deletion's do; the player's title is kept first (ADR-0055 §3), so if keeping it fails nothing is deleted.
/// Only this iPhone's player's title is kept here; a partner's iPhone keeps theirs when the deletion reaches it (PR 4).
public protocol DeleteChildForGoodUseCase: Sendable {
    func execute(childID: UUID, on date: Date) async throws
}

public struct DefaultDeleteChildForGoodUseCase: DeleteChildForGoodUseCase {
    private let contentRepository: any ContentRepository
    private let profileRepository: any ProfileRepository
    private let progressRepository: any ProgressRepository
    private let standingRepository: any StandingRepository
    private let photoStore: any PhotoStore
    private let renewReminders: any RenewWeeklyRemindersUseCase

    public init(
        contentRepository: any ContentRepository,
        profileRepository: any ProfileRepository,
        progressRepository: any ProgressRepository,
        standingRepository: any StandingRepository,
        photoStore: any PhotoStore,
        renewReminders: any RenewWeeklyRemindersUseCase
    ) {
        self.contentRepository = contentRepository
        self.profileRepository = profileRepository
        self.progressRepository = progressRepository
        self.standingRepository = standingRepository
        self.photoStore = photoStore
        self.renewReminders = renewReminders
    }

    public func execute(childID: UUID, on date: Date) async throws {
        guard let player = try await profileRepository.fetchProfile() else { throw ProfileEditError.noProfile }
        // Checked before anything is kept, so a refusal writes nothing; Data checks again in its own turn.
        guard player.removedChildren.contains(where: { $0.id == childID }) else { throw ProfileEditError.notRemoved }
        let events = try await progressRepository.fetchEvents()
        try await TitleKeeper(contentRepository: contentRepository, standingRepository: standingRepository)
            .keepHeldTitle(of: player, events: events)
        let photoIDs = try await profileRepository.deleteForGood(childID: childID)
        await renewReminders.execute(on: date)
        // After the rows: a kill in between leaves files the orphan sweep removes (ADR-0048 §6).
        for id in photoIDs { await photoStore.delete(id: id) }
    }
}
