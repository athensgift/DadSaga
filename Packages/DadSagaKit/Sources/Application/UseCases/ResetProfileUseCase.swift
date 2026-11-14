/// Deletes the stored profile, progress and photos so the app starts again from onboarding. Used by the developer menu.
public protocol ResetProfileUseCase: Sendable {
    func execute() async throws
}

public struct DefaultResetProfileUseCase: ResetProfileUseCase {
    private let profileRepository: any ProfileRepository
    private let progressRepository: any ProgressRepository
    private let photoStore: (any PhotoStore)?
    private let outfitRepository: (any OutfitRepository)?

    public init(
        profileRepository: any ProfileRepository,
        progressRepository: any ProgressRepository,
        photoStore: (any PhotoStore)? = nil,
        outfitRepository: (any OutfitRepository)? = nil
    ) {
        self.profileRepository = profileRepository
        self.progressRepository = progressRepository
        self.photoStore = photoStore
        self.outfitRepository = outfitRepository
    }

    public func execute() async throws {
        try await profileRepository.deleteProfile()
        try await progressRepository.deleteAll()
        try await outfitRepository?.deleteAll()
        await photoStore?.deleteAll()
    }
}
