import Domain

/// Port for the player profile (the dad and his children) stored on the device. Implemented in the Data layer.
public protocol ProfileRepository: Sendable {
    /// `nil` until onboarding has been completed.
    func fetchProfile() async throws -> PlayerProfile?
    func save(_ profile: PlayerProfile) async throws
    func deleteProfile() async throws
}
