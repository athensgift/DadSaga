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
    /// Writes and reads exported sagas, in a temporary folder of its own (ADR-0057 §3). One for the whole app, so the
    /// launch clean-up and every Settings page share that folder.
    private lazy var sagaCopyFiles: any SagaCopyFiles = AppleArchiveSagaCopyFiles(app: "\(appInfo.version) (\(appInfo.build))")
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
                    wholeSaga: store.wholeSaga,
                    photoStore: photoStore,
                    reminderSettings: reminderSettings,
                    sagaOffers: sagaOffers,
                    schedule: scheduleWeeklyReminders,
                    notificationScheduler: notificationScheduler
                ),
                getHeroChoice: getHeroChoice
            ),
            preferences: preferences,
            appInfo: appInfo,
            actions: actions
        )
    }

    /// "Your hero"'s query, also drawing the hero above Settings' form (ADR-0061 §4).
    private var getHeroChoice: any GetHeroChoiceUseCase {
        DefaultGetHeroChoiceUseCase(contentRepository: contentRepository, profileRepository: store.profiles)
    }

    var settingsPages: SettingsPages {
        SettingsPages(
            makeHero: { [unowned self] in makeHeroSettingsViewModel() },
            makeWardrobe: { [unowned self] in makeWardrobeViewModel() },
            makeFamily: { [unowned self] in makeFamilyViewModel(onSaved: $0) },
            makeReminder: { [unowned self] in makeReminderSettingsViewModel() },
            makeDataExport: { [unowned self] in makeDataExportViewModel(onImported: $0) },
            discardExports: { [unowned self] in discardLeftoverExports() }
        )
    }

    func makeHeroSettingsViewModel() -> HeroSettingsViewModel {
        HeroSettingsViewModel(
            getHeroChoice: getHeroChoice,
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
                    profileRepository: store.profiles,
                    photoStore: photoStore
                ),
                defeatBoss: DefaultDefeatBossUseCase(
                    contentRepository: contentRepository,
                    progressRepository: store.progress,
                    profileRepository: store.profiles,
                    photoStore: photoStore
                ),
                deleteEvent: DefaultDeleteEventUseCase(
                    contentRepository: contentRepository, profileRepository: store.profiles,
                    progressRepository: store.progress, standingRepository: store.standing, photoStore: photoStore
                ),
                undoRecord: DefaultUndoRecordUseCase(
                    contentRepository: contentRepository, profileRepository: store.profiles,
                    progressRepository: store.progress, standingRepository: store.standing, photoStore: photoStore
                ),
                moments: HomeViewModel.MomentUseCases(
                    capture: DefaultCaptureMomentUseCase(
                        contentRepository: contentRepository,
                        progressRepository: store.progress,
                        profileRepository: store.profiles,
                        photoStore: photoStore
                    ),
                    update: DefaultUpdateMomentUseCase(
                        profileRepository: store.profiles, progressRepository: store.progress, photoStore: photoStore
                    ),
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
            bringBack: DefaultBringBackChildUseCase(profileRepository: store.profiles),
            deleteForGood: DefaultDeleteChildForGoodUseCase(
                contentRepository: contentRepository, profileRepository: store.profiles,
                progressRepository: store.progress, standingRepository: store.standing, photoStore: photoStore
            ),
            onSaved: onSaved
        )
    }

    func makeWardrobeViewModel() -> WardrobeViewModel {
        WardrobeViewModel(
            useCases: WardrobeViewModel.UseCases(
                getWardrobe: getWardrobeUseCase,
                setChoice: DefaultSetOutfitChoiceUseCase(
                    contentRepository: contentRepository, profileRepository: store.profiles,
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
            getTimeline: DefaultGetTimelineUseCase(contentRepository: contentRepository, wholeSaga: store.wholeSaga),
            getPhoto: DefaultGetPhotoUseCase(photoStore: photoStore),
            deleteEvent: DefaultDeleteEventUseCase(
                contentRepository: contentRepository, profileRepository: store.profiles,
                progressRepository: store.progress,
                standingRepository: store.standing,
                photoStore: photoStore
            ),
            updateJournal: DefaultUpdateJournalUseCase(
                profileRepository: store.profiles, progressRepository: store.progress, photoStore: photoStore
            )
        )
    }
}

// MARK: - Exporting and importing the saga (ADR-0057)

extension AppContainer {
    private var makeSagaCopyUseCase: any MakeSagaCopyUseCase {
        DefaultMakeSagaCopyUseCase(
            wholeSaga: store.wholeSaga, sagaOffers: sagaOffers, photoStore: photoStore, files: sagaCopyFiles
        )
    }

    func makeDataExportViewModel(onImported: @escaping @MainActor () -> Void) -> DataExportViewModel {
        DataExportViewModel(
            makeCopy: makeSagaCopyUseCase,
            backgroundTime: UIKitBackgroundTime(),
            importer: makeDataImportViewModel(replacesSaga: true, onImported: onImported)
        )
    }

    /// - Parameter replacesSaga: `false` on onboarding, where there is no saga yet.
    func makeDataImportViewModel(replacesSaga: Bool, onImported: @escaping @MainActor () -> Void) -> DataImportViewModel {
        DataImportViewModel(
            restore: DefaultRestoreSagaUseCase(
                wholeSaga: store.wholeSaga,
                progressRepository: store.progress,
                photoStore: photoStore,
                sagaOffers: sagaOffers,
                files: sagaCopyFiles,
                schedule: scheduleWeeklyReminders,
                notificationScheduler: notificationScheduler
            ),
            backgroundTime: UIKitBackgroundTime(),
            replacesSaga: replacesSaga,
            onImported: onImported
        )
    }

    /// Deletes exported files: once Settings closes, and at launch for what a crash or a kill left (ADR-0057 §6).
    func discardLeftoverExports() {
        let makeCopy = makeSagaCopyUseCase
        Task { await makeCopy.discardCopies() }
    }
}
