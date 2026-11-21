import Application
import Data
import Presentation
import SagaMusic
import UIKit

/// Composition root: the only place that knows concrete types from every layer and wires them together.
@MainActor
final class AppContainer {
    // MARK: Data
    private lazy var contentRepository: any ContentRepository = BundledContentRepository()
    /// The saga's store, opened on first use; if it cannot be opened, the app says so and waits (ADR-0026).
    private let store: LocalStore
    /// Photos of legendary moments, kept on the device, next to the store.
    private let photoStore: any PhotoStore
    /// The weekly reminder (ADR-0024): its settings stay in the app's own defaults, the notifications are local.
    private let reminderSettings: any ReminderSettingsRepository
    private let notificationScheduler: any NotificationScheduler
    /// Light/dark and haptics (ADR-0030), in the app's own defaults: they belong to the phone, not to the saga.
    private let preferencesRepository: any PreferencesRepository
    /// The dad's answers to home's film offers (ADR-0037 §5), in the app's own defaults. Starting over clears them.
    private let sagaOffers: any SagaOfferRepository
    /// What the film sheet remembers: the dates switch and the music (ADR-0041 §5, ADR-0046 §4). Starting over keeps it.
    private let sagaFilmChoices: any SagaFilmChoicesRepository
    /// The saga film's music, from the bundle only the app carries (ADR-0036 §8).
    private lazy var soundtrackRepository: any SoundtrackRepository = BundledSoundtrackRepository(bundle: SagaMusic.bundle)
    /// Draws and writes the films, into a temporary folder it empties itself (ADR-0036 §6). One for the whole app,
    /// so every sheet and the launch clean-up share that folder.
    private lazy var sagaFilmRenderer: any SagaFilmRendering = SagaFilmRenderer(
        getPhoto: DefaultGetPhotoUseCase(photoStore: photoStore),
        findSubject: DefaultFindPhotoSubjectUseCase(analyzer: photoAnalyzer)
    )
    /// Looks at the film's photos with Vision, on the device, while a film is made; keeps nothing (ADR-0047).
    private let photoAnalyzer: any PhotoAnalyzer = VisionPhotoAnalyzer()

    init(data: DeviceData = .forLaunch()) {
        store = data.store
        photoStore = data.photos
        reminderSettings = UserDefaultsReminderSettingsRepository(defaults: data.defaults)
        notificationScheduler = data.notificationScheduler
        preferencesRepository = UserDefaultsPreferencesRepository(defaults: data.defaults)
        sagaOffers = UserDefaultsSagaOfferRepository(defaults: data.defaults)
        sagaFilmChoices = UserDefaultsSagaFilmChoicesRepository(defaults: data.defaults)
    }

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
            outfitRepository: store.outfit,
            standingRepository: store.standing
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
                    sagaOffers: sagaOffers,
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
            makeHero: { [unowned self] in makeHeroSettingsViewModel() },
            makeWardrobe: { [unowned self] in makeWardrobeViewModel() },
            makeFamily: { [unowned self] in makeFamilyViewModel(onSaved: $0) },
            makeReminder: { [unowned self] in makeReminderSettingsViewModel() }
        )
    }

    func makeHeroSettingsViewModel() -> HeroSettingsViewModel {
        HeroSettingsViewModel(
            getHeroChoice: DefaultGetHeroChoiceUseCase(
                contentRepository: contentRepository,
                profileRepository: store.profiles
            ),
            updateHero: DefaultUpdateHeroUseCase(contentRepository: contentRepository, profileRepository: store.profiles)
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
                    outfitRepository: store.outfit,
                    standingRepository: store.standing,
                    sagaOfferRepository: sagaOffers
                ),
                completeQuest: DefaultCompleteQuestUseCase(
                    contentRepository: contentRepository,
                    progressRepository: store.progress,
                    standingRepository: store.standing,
                    photoStore: photoStore
                ),
                defeatBoss: DefaultDefeatBossUseCase(
                    contentRepository: contentRepository,
                    progressRepository: store.progress,
                    standingRepository: store.standing,
                    photoStore: photoStore
                ),
                deleteEvent: DefaultDeleteEventUseCase(
                    contentRepository: contentRepository,
                    progressRepository: store.progress,
                    standingRepository: store.standing,
                    photoStore: photoStore
                ),
                moments: HomeViewModel.MomentUseCases(
                    capture: DefaultCaptureMomentUseCase(
                        contentRepository: contentRepository,
                        progressRepository: store.progress,
                        standingRepository: store.standing,
                        photoStore: photoStore
                    ),
                    update: DefaultUpdateMomentUseCase(progressRepository: store.progress, photoStore: photoStore),
                    getPhoto: DefaultGetPhotoUseCase(photoStore: photoStore)
                ),
                reminder: reminderUseCases,
                answerSagaOffer: DefaultAnswerSagaOfferUseCase(repository: sagaOffers),
                markTitleSeen: DefaultMarkTitleSeenUseCase(standingRepository: store.standing)
            )
        )
    }

    func makeSagaFilmViewModel(request: SagaFilmRequest) -> SagaFilmViewModel {
        SagaFilmViewModel(
            request: request,
            useCases: SagaFilmViewModel.UseCases(
                getFilm: DefaultGetSagaFilmUseCase(
                    contentRepository: contentRepository,
                    profileRepository: store.profiles,
                    progressRepository: store.progress,
                    outfitRepository: store.outfit,
                    standingRepository: store.standing,
                    soundtrackRepository: soundtrackRepository,
                    choicesRepository: sagaFilmChoices
                ),
                setDates: DefaultSetSagaFilmDatesUseCase(repository: sagaFilmChoices),
                setMusic: DefaultSetSagaFilmMusicUseCase(repository: sagaFilmChoices),
                choosePhotos: DefaultChooseSagaFilmPhotosUseCase(photoStore: photoStore, analyzer: photoAnalyzer)
            ),
            renderer: sagaFilmRenderer,
            previewer: SagaMusicPreviewer()
        )
    }

    /// Deletes the films a crash or a kill left in the temporary folder (ADR-0037 §4). Run once, at launch.
    func discardLeftoverFilms() {
        let renderer = sagaFilmRenderer
        Task { await renderer.discardFilms() }
    }

    /// Deletes photo files no entry points to, left when the app stopped between two writes (ADR-0048 §6). Run once,
    /// at launch, at low priority; it deletes nothing when the saga can't be read.
    func sweepOrphanPhotos() {
        let sweep = DefaultSweepOrphanPhotosUseCase(
            profileRepository: store.profiles, progressRepository: store.progress, photoStore: photoStore
        )
        Task(priority: .utility) { try? await sweep.execute(now: .now) }
    }

    func makeReminderSettingsViewModel() -> ReminderSettingsViewModel {
        ReminderSettingsViewModel(useCases: reminderUseCases)
    }

    func makeFamilyViewModel(onSaved: @escaping @MainActor () -> Void) -> FamilyViewModel {
        FamilyViewModel(
            getProfile: getProfileUseCase,
            updateFamily: DefaultUpdateFamilyUseCase(profileRepository: store.profiles),
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
                    outfitRepository: store.outfit,
                    standingRepository: store.standing
                )
            )
        )
    }

    func makeTimelineViewModel() -> TimelineViewModel {
        TimelineViewModel(
            getProfile: getProfileUseCase,
            getTimeline: DefaultGetTimelineUseCase(contentRepository: contentRepository, progressRepository: store.progress),
            getPhoto: DefaultGetPhotoUseCase(photoStore: photoStore),
            deleteEvent: DefaultDeleteEventUseCase(
                contentRepository: contentRepository,
                progressRepository: store.progress,
                standingRepository: store.standing,
                photoStore: photoStore
            ),
            updateJournal: DefaultUpdateJournalUseCase(progressRepository: store.progress, photoStore: photoStore)
        )
    }
}
