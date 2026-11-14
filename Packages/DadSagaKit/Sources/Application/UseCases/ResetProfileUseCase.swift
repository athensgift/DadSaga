/// Deletes the stored profile, progress and photos so the app starts again from onboarding. Used by the developer menu.
public protocol ResetProfileUseCase: Sendable {
    func execute() async throws
}

public struct DefaultResetProfileUseCase: ResetProfileUseCase {
    private let profileRepository: any ProfileRepository
    private let progressRepository: any ProgressRepository
    private let photoStore: (any PhotoStore)?

    public init(
        profileRepository: any ProfileRepository,
        progressRepository: any ProgressRepository,
        photoStore: (any PhotoStore)? = nil
    ) {
        self.profileRepository = profileRepository
        self.progressRepository = progressRepository
        self.photoStore = photoStore
    }

    public func execute() async throws {
        try await profileRepository.deleteProfile()
        try await progressRepository.deleteAll()
        await photoStore?.deleteAll()
    }
}
