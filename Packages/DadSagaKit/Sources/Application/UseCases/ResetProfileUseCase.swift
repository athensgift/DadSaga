/// Deletes the stored profile, progress, photos, reminder settings and pending notifications so the app starts again
/// from onboarding. Used by the developer menu.
public protocol ResetProfileUseCase: Sendable {
    func execute() async throws
}

public struct DefaultResetProfileUseCase: ResetProfileUseCase {
    private let profileRepository: any ProfileRepository
    private let progressRepository: any ProgressRepository
    private let photoStore: any PhotoStore
    private let outfitRepository: any OutfitRepository
    private let reminderSettings: any ReminderSettingsRepository
    private let notificationScheduler: any NotificationScheduler

    public init(
        profileRepository: any ProfileRepository,
        progressRepository: any ProgressRepository,
        photoStore: any PhotoStore,
        outfitRepository: any OutfitRepository,
        reminderSettings: any ReminderSettingsRepository,
        notificationScheduler: any NotificationScheduler
    ) {
        self.profileRepository = profileRepository
        self.progressRepository = progressRepository
        self.photoStore = photoStore
        self.outfitRepository = outfitRepository
        self.reminderSettings = reminderSettings
        self.notificationScheduler = notificationScheduler
    }

    public func execute() async throws {
        try await profileRepository.deleteProfile()
        try await progressRepository.deleteAll()
        try await outfitRepository.deleteAll()
        await photoStore.deleteAll()
        await reminderSettings.deleteAll()
        await notificationScheduler.replacePending(with: [])
    }
}
