import Application
import Data
import Presentation
import UIKit

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
    /// Light/dark and haptics (ADR-0030), in the app's own defaults: they belong to the phone, not to the saga.
    private let preferencesRepository: any PreferencesRepository = UserDefaultsPreferencesRepository()

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

    private var getWardrobeUseCase: any GetWardrobeUseCase {
        DefaultGetWardrobeUseCase(
            contentRepository: contentRepository,
            profileRepository: store.profiles,
            progressRepository: store.progress,
            outfitRepository: store.outfit
        )
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
        RootViewModel(
            getProfile: getProfileUseCase,
            getPreferences: DefaultGetPreferencesUseCase(repository: preferencesRepository)
        )
    }

    func makeSettingsViewModel(preferences: PreferencesChoice, actions: SettingsActions) -> SettingsViewModel {
        SettingsViewModel(
            useCases: SettingsViewModel.UseCases(
                savePreferences: DefaultSavePreferencesUseCase(repository: preferencesRepository),
                startOver: DefaultStartOverUseCase(
                    eraser: store.eraser,
                    photoStore: photoStore,
                    reminderSettings: reminderSettings,
                    schedule: scheduleWeeklyReminders,
                    notificationScheduler: notificationScheduler
                )
            ),
            preferences: preferences,
            appInfo: appInfo,
            actions: actions
        )
    }

    var settingsPages: SettingsPages {
        SettingsPages(
            makeHero: { [unowned self] in makeHeroSettingsViewModel(onSaved: $0) },
            makeFamily: { [unowned self] in makeFamilyViewModel(onSaved: $0) },
            makeReminder: { [unowned self] in makeReminderSettingsViewModel() }
        )
    }

    func makeHeroSettingsViewModel(onSaved: @escaping @MainActor () -> Void) -> HeroSettingsViewModel {
        HeroSettingsViewModel(
            getHeroChoice: DefaultGetHeroChoiceUseCase(
                contentRepository: contentRepository,
                profileRepository: store.profiles
            ),
            updateHero: DefaultUpdateHeroUseCase(contentRepository: contentRepository, profileRepository: store.profiles),
            onSaved: onSaved
        )
    }

    /// The version, and the three `DadSaga…` keys from `project.yml`; an empty key hides its row.
    private var appInfo: AppInfo {
        AppInfo(infoDictionary: Bundle.main.infoDictionary ?? [:], systemVersion: UIDevice.current.systemVersion)
    }

    func makeOnboardingViewModel(onFinished: @escaping @MainActor () -> Void) -> OnboardingViewModel {
        OnboardingViewModel(loadCatalog: loadContentCatalogUseCase, saveProfile: saveProfileUseCase, onFinished: onFinished)
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            useCases: HomeViewModel.UseCases(
                getOverview: DefaultGetHomeOverviewUseCase(
                    contentRepository: contentRepository,
                    profileRepository: store.profiles,
                    progressRepository: store.progress,
                    outfitRepository: store.outfit
                ),
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
                reminder: reminderUseCases
            )
        )
    }

    func makeReminderSettingsViewModel() -> ReminderSettingsViewModel {
        ReminderSettingsViewModel(useCases: reminderUseCases)
    }

    func makeFamilyViewModel(onSaved: @escaping @MainActor () -> Void) -> FamilyViewModel {
        FamilyViewModel(
            getProfile: getProfileUseCase,
            updateFamily: DefaultUpdateFamilyUseCase(contentRepository: contentRepository, profileRepository: store.profiles),
            onSaved: onSaved
        )
    }

    func makeWardrobeViewModel() -> WardrobeViewModel {
        WardrobeViewModel(
            useCases: WardrobeViewModel.UseCases(
                getWardrobe: getWardrobeUseCase,
                setChoice: DefaultSetOutfitChoiceUseCase(
                    contentRepository: contentRepository,
                    progressRepository: store.progress,
                    outfitRepository: store.outfit
                )
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
