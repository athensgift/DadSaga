import Domain
import Foundation

/// Port for the player profile (the dad and his children) stored on the device. Implemented in the Data layer. An edit
/// says what changed, never the whole profile, so a field it doesn't name keeps what is stored (ADR-0065 §1, §4).
public protocol ProfileRepository: Sendable {
    /// `nil` until onboarding has been completed. The family in order, and the children removed from it
    /// (`removedChildren`).
    func fetchProfile() async throws -> PlayerProfile?
    /// Onboarding: the one player and their children, in order. Throws `ProfileEditError.profileExists` when a player
    /// is stored: one per iPhone (ADR-0065 §5); a restore goes through `WholeSagaRepository`.
    func create(_ profile: PlayerProfile) async throws
    /// What "My family" changed (ADR-0065 §4): a child or field the edit doesn't name stays as stored; a removed id
    /// marks that child removed, their row and entries kept; a removed child is never changed or added again, and an id
    /// the edit both adds and removes is not added; an added child goes after every stored one. Throws
    /// `ProfileEditError.noProfile` before onboarding, and `ProfileValidationError.noChildren`, writing nothing, when
    /// the edit would leave no child.
    func save(_ edit: FamilyEdit) async throws
    /// Sets only the hero fields `edit` names. Throws `ProfileEditError.noProfile` before onboarding.
    func save(_ edit: HeroEdit) async throws
    /// Brings a removed child back into the family, in their place, with every entry (ADR-0065 §4). Throws
    /// `ProfileEditError.notRemoved`, writing nothing, when no removed child has this id.
    func bringBack(childID: UUID) async throws
    /// Deletes a removed child for good, with every entry with them, whoever recorded it, in one write (ADR-0065 §4).
    /// Returns those entries' photo ids, unknown kinds included, for the caller to delete the files. Throws
    /// `ProfileEditError.notRemoved`, writing nothing, when no removed child has this id: a child in the family is never
    /// deleted this way.
    func deleteForGood(childID: UUID) async throws -> [String]
}
