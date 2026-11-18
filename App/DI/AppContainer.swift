import Application
import Data
import Presentation

/// Composition root: the only place that knows concrete types from every layer and wires them together.
@MainActor
final class AppContainer {
    // MARK: Data
    private lazy var contentRepository: any ContentRepository = BundledContentRepository()
    /// In the folder the app shares with the widget (ADR-0023). Opened on first use; if it cannot be opened, the app
    /// says so and waits (ADR-0026).
    private let store = LocalStore.live(in: SharedContainer.directory())

    /// Photos of legendary moments, kept on the device, next to the store.
    private lazy var photoStore: any PhotoStore = FilePhotoStore.moments(in: SharedContainer.directory())

    /// The weekly reminder (ADR-0024): its settings stay in the app's own defaults, the notifications are local.
    private let reminderSettings: any ReminderSettingsRepository = UserDefaultsReminderSettingsRepository()
    private let notificationScheduler: any NotificationScheduler = UserNotificationScheduler()

    // MARK: Use cases
    private var loadContentCatalogUseCase: any LoadContentCatalogUseCase {
        DefaultLoadContentCatalogUseCase(repository: contentRepository)
    }

    private var getProfileUseCase: any GetProfileUseCase {
        DefaultGetProfileUseCase(repository: store.profiles)
    }

    private var saveProfileUseCase: any SaveProfileUseCase {
        DefaultSaveProfileUseCase(contentRepository: contentRepository, profileRepository: store.profiles)
    }

    /// Reschedules the next weekly notifications; the app runs it whenever it leaves the foreground.
    /// One instance, so every reschedule (leaving the app, a settings change) waits for the one before it.
    lazy var scheduleWeeklyReminders: any ScheduleWeeklyRemindersUseCase = DefaultScheduleWeeklyRemindersUseCase(
        settings: reminderSettings,
        scheduler: notificationScheduler,
        profileRepository: store.profiles,
        highlights: DefaultGetWeeklyHighlightsUseCase(
            contentRepository: contentRepository,
            profileRepository: store.profiles,
            progressRepository: store.progress,
            photoStore: photoStore
        ),
        text: WeeklyReminderText()
    )

    /// One instance for home's offer and the settings screen, so every change waits for the one before it.
    private lazy var reminderUseCases = ReminderUseCases(
        get: DefaultGetWeeklyReminderUseCase(settings: reminderSettings, scheduler: notificationScheduler),
        update: DefaultUpdateWeeklyReminderUseCase(
            settings: reminderSettings,
            scheduler: notificationScheduler,
            schedule: scheduleWeeklyReminders
        )
    )

    // MARK: Presentation
    func makeRootViewModel() -> RootViewModel {
        #if DEBUG
        let reset = DefaultResetProfileUseCase(
            profileRepository: store.profiles,
            progressRepository: store.progress,
            photoStore: photoStore,
            outfitRepository: store.outfit,
            reminderSettings: reminderSettings,
            notificationScheduler: notificationScheduler
        )
        return RootViewModel(getProfile: getProfileUseCase, resetProfile: reset)
        #else
        return RootViewModel(getProfile: getProfileUseCase)
        #endif
    }

    func makeOnboardingViewModel(onFinished: @escaping @MainActor () -> Void) -> OnboardingViewModel {
        OnboardingViewModel(loadCatalog: loadContentCatalogUseCase, saveProfile: saveProfileUseCase, onFinished: onFinished)
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            useCases: HomeViewModel.UseCases(
                getProfile: getProfileUseCase,
                loadCatalog: loadContentCatalogUseCase,
                getAdventure: DefaultGetAdventureUseCase(repository: contentRepository),
                getProgress: DefaultGetProgressUseCase(contentRepository: contentRepository, progressRepository: store.progress),
                completeQuest: DefaultCompleteQuestUseCase(
                    contentRepository: contentRepository,
                    progressRepository: store.progress,
                    photoStore: photoStore
                ),
                defeatBoss: DefaultDefeatBossUseCase(
                    contentRepository: contentRepository,
                    progressRepository: store.progress,
                    photoStore: photoStore
                ),
                deleteEvent: DefaultDeleteEventUseCase(progressRepository: store.progress, photoStore: photoStore),
                moments: HomeViewModel.MomentUseCases(
                    capture: DefaultCaptureMomentUseCase(
                        contentRepository: contentRepository,
                        progressRepository: store.progress,
                        photoStore: photoStore
                    ),
                    update: DefaultUpdateMomentUseCase(progressRepository: store.progress, photoStore: photoStore),
                    getPhoto: DefaultGetPhotoUseCase(photoStore: photoStore)
                ),
                getOutfit: DefaultGetOutfitUseCase(repository: store.outfit),
                reminder: reminderUseCases
            )
        )
    }

    func makeReminderSettingsViewModel() -> ReminderSettingsViewModel {
        ReminderSettingsViewModel(useCases: reminderUseCases)
    }

    func makeFamilyViewModel(onSaved: @escaping @MainActor () -> Void) -> FamilyViewModel {
        FamilyViewModel(getProfile: getProfileUseCase, saveProfile: saveProfileUseCase, onSaved: onSaved)
    }

    func makeWardrobeViewModel() -> WardrobeViewModel {
        WardrobeViewModel(
            useCases: WardrobeViewModel.UseCases(
                getProfile: getProfileUseCase,
                loadCatalog: loadContentCatalogUseCase,
                getProgress: DefaultGetProgressUseCase(contentRepository: contentRepository, progressRepository: store.progress),
                getOutfit: DefaultGetOutfitUseCase(repository: store.outfit),
                setChoice: DefaultSetOutfitChoiceUseCase(repository: store.outfit)
            )
        )
    }

    func makeTimelineViewModel() -> TimelineViewModel {
        TimelineViewModel(
            getProfile: getProfileUseCase,
            getTimeline: DefaultGetTimelineUseCase(contentRepository: contentRepository, progressRepository: store.progress),
            getPhoto: DefaultGetPhotoUseCase(photoStore: photoStore),
            deleteEvent: DefaultDeleteEventUseCase(progressRepository: store.progress, photoStore: photoStore),
            updateJournal: DefaultUpdateJournalUseCase(progressRepository: store.progress, photoStore: photoStore)
        )
    }
}
