/// Deletes the stored profile and progress so the app starts again from onboarding. Used by the developer menu.
public protocol ResetProfileUseCase: Sendable {
    func execute() async throws
}

public struct DefaultResetProfileUseCase: ResetProfileUseCase {
    private let profileRepository: any ProfileRepository
    private let progressRepository: any ProgressRepository

    public init(profileRepository: any ProfileRepository, progressRepository: any ProgressRepository) {
        self.profileRepository = profileRepository
        self.progressRepository = progressRepository
    }

    public func execute() async throws {
        try await profileRepository.deleteProfile()
        try await progressRepository.deleteAll()
    }
}
