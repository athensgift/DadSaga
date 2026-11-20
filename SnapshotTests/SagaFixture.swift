import Application
import Data
import Domain
import Foundation
import Presentation
import SagaMusic
import UIKit

/// One dad's saga, the same on every run: a fixed day, a four-month-old, three quests and two firsts, in a
/// store in memory, with the app's real content. The screens are built the way `AppContainer` builds them, with the
/// locale and the clock passed in instead of read from the phone. `birthday()` and `filmed()` are other sagas, for
/// the film offer and the film's cards.
@MainActor
struct SagaFixture {
    /// 15 June 2026, noon, UTC. The `DadSagaSnapshots` scheme runs in UTC, so days and ages never move.
    nonisolated static let today = Date(timeIntervalSince1970: 1_781_524_800)
    static let child = Child(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
        name: "Alex",
        birthDate: today.addingTimeInterval(-122 * 86_400),
        gender: .boy,
        skinTone: .medium
    )

    let locale: Locale
    private let content: any ContentRepository = BundledContentRepository()
    private let store = LocalStore.inMemory()
    private let photos = FilePhotoStore(
        directory: FileManager.default.temporaryDirectory.appending(path: "snapshots-" + UUID().uuidString)
    )
    private let reminderSettings: any ReminderSettingsRepository
    private let preferences: any PreferencesRepository
    private let sagaOffers: any SagaOfferRepository
    private let scheduler = SilentScheduler()

    init(locale: Locale) {
        self.locale = locale
        let defaults = UserDefaults(suiteName: "dadsaga.snapshots." + UUID().uuidString) ?? .standard
        reminderSettings = UserDefaultsReminderSettingsRepository(defaults: defaults)
        preferences = UserDefaultsPreferencesRepository(defaults: defaults)
        sagaOffers = UserDefaultsSagaOfferRepository(defaults: defaults)
    }

    private var reminder: ReminderUseCases {
        ReminderUseCases(
            get: DefaultGetWeeklyReminderUseCase(settings: reminderSettings, scheduler: scheduler),
            update: DefaultUpdateWeeklyReminderUseCase(settings: reminderSettings, scheduler: scheduler, schedule: NoSchedule())
        )
    }

    /// The saga after a few weeks of play.
    func played() async throws -> SagaFixture {
        let profile = PlayerProfile(children: [Self.child], heroClassID: "h-super", dadSkinTone: .mediumLight)
        try await DefaultSaveProfileUseCase(contentRepository: content, profileRepository: store.profiles)
            .execute(profile, on: Self.today.addingTimeInterval(-30 * 86_400))
        let quest = DefaultCompleteQuestUseCase(
            contentRepository: content, progressRepository: store.progress, photoStore: photos
        )
        let quests = [("q-w1-skin-to-skin", 28.0), ("q-w1-bath-master", 20), ("q-w1-lullaby", 9)]
        for (id, daysAgo) in quests {
            let note = id == "q-w1-lullaby" ? "He fell asleep on song two" : nil
            _ = try await quest.execute(
                questID: id, childID: Self.child.id, on: Self.day(daysAgo), journal: JournalInput(note: note)
            )
        }
        let moment = DefaultCaptureMomentUseCase(
            contentRepository: content, progressRepository: store.progress, photoStore: photos
        )
        _ = try await moment.execute(
            CaptureMomentRequest(firstID: "f-first-hold", childID: Self.child.id, date: Self.day(30)), now: Self.today
        )
        _ = try await moment.execute(
            CaptureMomentRequest(firstID: "f-smile", childID: Self.child.id, date: Self.day(3), note: "At 6 a.m., for me"),
            now: Self.today
        )
        return self
    }

    /// The saga of `played()`, with more for a film to show: a first with a photo and a boss beaten.
    func filmed() async throws -> SagaFixture {
        _ = try await played()
        let moment = DefaultCaptureMomentUseCase(
            contentRepository: content, progressRepository: store.progress, photoStore: photos
        )
        _ = try await moment.execute(
            CaptureMomentRequest(firstID: "f-laugh", childID: Self.child.id, date: Self.day(12), photo: Self.photo()),
            now: Self.today
        )
        let boss = DefaultDefeatBossUseCase(
            contentRepository: content, progressRepository: store.progress, photoStore: photos
        )
        _ = try await boss.execute(
            bossID: "b-w1-first-fever", childID: Self.child.id, on: Self.day(15), journal: JournalInput()
        )
        return self
    }

    /// Another family: Alex turned one five days ago and has a baby sister. Something was done in his first year, so
    /// home offers its film (ADR-0037 §5).
    func birthday() async throws -> SagaFixture {
        let alex = Child(
            id: Self.child.id, name: "Alex", birthDate: Self.day(370), gender: .boy, skinTone: .medium
        )
        let maya = Child(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
            name: "Maya",
            birthDate: Self.day(60),
            gender: .girl,
            skinTone: .mediumDark
        )
        let profile = PlayerProfile(children: [alex, maya], heroClassID: "h-super", dadSkinTone: .mediumLight)
        try await DefaultSaveProfileUseCase(contentRepository: content, profileRepository: store.profiles)
            .execute(profile, on: Self.day(30))
        _ = try await DefaultCompleteQuestUseCase(
            contentRepository: content, progressRepository: store.progress, photoStore: photos
        ).execute(
            questID: "q-w2-book-hero", childID: alex.id, on: Self.day(20), journal: JournalInput(note: "The bear book, twice")
        )
        _ = try await DefaultCaptureMomentUseCase(
            contentRepository: content, progressRepository: store.progress, photoStore: photos
        ).execute(CaptureMomentRequest(firstID: "f-first-word", childID: alex.id, date: Self.day(45)), now: Self.today)
        return self
    }

    static func day(_ daysAgo: Double) -> Date { today.addingTimeInterval(-daysAgo * 86_400) }

    /// A photo made here, so no real one is kept in the repository: a plain warm picture, taller than wide.
    private static func photo() -> Data? {
        let size = CGSize(width: 600, height: 800)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.93, green: 0.72, blue: 0.45, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.98, green: 0.9, blue: 0.7, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 150, y: 200, width: 300, height: 300))
        }.jpegData(compressionQuality: 0.8)
    }

    // MARK: Screens

    func onboarding() -> OnboardingViewModel {
        OnboardingViewModel(
            loadCatalog: DefaultLoadContentCatalogUseCase(repository: content),
            saveProfile: DefaultSaveProfileUseCase(contentRepository: content, profileRepository: store.profiles),
            locale: locale,
            now: Self.today,
            onFinished: {}
        )
    }

    func home() -> HomeViewModel {
        HomeViewModel(
            useCases: HomeViewModel.UseCases(
                getOverview: DefaultGetHomeOverviewUseCase(
                    contentRepository: content,
                    profileRepository: store.profiles,
                    progressRepository: store.progress,
                    outfitRepository: store.outfit,
                    sagaOfferRepository: sagaOffers
                ),
                completeQuest: DefaultCompleteQuestUseCase(
                    contentRepository: content, progressRepository: store.progress, photoStore: photos
                ),
                defeatBoss: DefaultDefeatBossUseCase(
                    contentRepository: content, progressRepository: store.progress, photoStore: photos
                ),
                deleteEvent: DefaultDeleteEventUseCase(progressRepository: store.progress, photoStore: photos),
                moments: HomeViewModel.MomentUseCases(
                    capture: DefaultCaptureMomentUseCase(
                        contentRepository: content, progressRepository: store.progress, photoStore: photos
                    ),
                    update: DefaultUpdateMomentUseCase(progressRepository: store.progress, photoStore: photos),
                    getPhoto: DefaultGetPhotoUseCase(photoStore: photos)
                ),
                reminder: reminder,
                answerSagaOffer: DefaultAnswerSagaOfferUseCase(repository: sagaOffers)
            ),
            locale: locale,
            now: { Self.today }
        )
    }

    /// The film sheet over `renderer`, which stands in for the real one: a snapshot needs no film written.
    func sagaFilm(
        request: SagaFilmRequest = SagaFilmRequest(), renderer: any SagaFilmRendering = NoFilmRenderer()
    ) -> SagaFilmViewModel {
        SagaFilmViewModel(
            request: request,
            getFilm: DefaultGetSagaFilmUseCase(
                contentRepository: content,
                profileRepository: store.profiles,
                progressRepository: store.progress,
                outfitRepository: store.outfit,
                soundtrackRepository: BundledSoundtrackRepository(bundle: SagaMusic.bundle)
            ),
            renderer: renderer,
            locale: locale,
            now: { Self.today }
        )
    }

    func settings() -> SettingsViewModel {
        SettingsViewModel(
            useCases: SettingsViewModel.UseCases(
                savePreferences: DefaultSavePreferencesUseCase(repository: preferences),
                startOver: DefaultStartOverUseCase(
                    eraser: store.eraser,
                    photoStore: photos,
                    reminderSettings: reminderSettings,
                    sagaOffers: sagaOffers,
                    schedule: NoSchedule(),
                    notificationScheduler: scheduler
                )
            ),
            preferences: PreferencesChoice(),
            appInfo: AppInfo(version: "1.0", build: "1", systemVersion: "27.2", feedbackAddress: "hello@dadsaga.app"),
            actions: SettingsActions(onPreferencesChanged: { _ in }, onStartedOver: {}),
            locale: locale,
            now: { Self.today }
        )
    }

    var settingsPages: SettingsPages {
        SettingsPages(
            makeHero: { onSaved in
                HeroSettingsViewModel(
                    getHeroChoice: DefaultGetHeroChoiceUseCase(contentRepository: content, profileRepository: store.profiles),
                    updateHero: DefaultUpdateHeroUseCase(contentRepository: content, profileRepository: store.profiles),
                    locale: locale,
                    onSaved: onSaved
                )
            },
            makeFamily: { onSaved in
                FamilyViewModel(
                    getProfile: DefaultGetProfileUseCase(repository: store.profiles),
                    updateFamily: DefaultUpdateFamilyUseCase(contentRepository: content, profileRepository: store.profiles),
                    locale: locale,
                    onSaved: onSaved
                )
            },
            makeReminder: { ReminderSettingsViewModel(useCases: reminder, locale: locale) }
        )
    }

    var settingsScreens: SettingsScreens {
        SettingsScreens(makeSettings: { settings() }, pages: settingsPages)
    }

    func wardrobe() -> WardrobeViewModel {
        WardrobeViewModel(
            useCases: WardrobeViewModel.UseCases(
                getWardrobe: DefaultGetWardrobeUseCase(
                    contentRepository: content,
                    profileRepository: store.profiles,
                    progressRepository: store.progress,
                    outfitRepository: store.outfit
                ),
                setChoice: DefaultSetOutfitChoiceUseCase(
                    contentRepository: content, progressRepository: store.progress, outfitRepository: store.outfit
                )
            ),
            locale: locale
        )
    }

    func timeline() -> TimelineViewModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.locale = locale
        return TimelineViewModel(
            getProfile: DefaultGetProfileUseCase(repository: store.profiles),
            getTimeline: DefaultGetTimelineUseCase(contentRepository: content, progressRepository: store.progress),
            getPhoto: DefaultGetPhotoUseCase(photoStore: photos),
            deleteEvent: DefaultDeleteEventUseCase(progressRepository: store.progress, photoStore: photos),
            updateJournal: DefaultUpdateJournalUseCase(progressRepository: store.progress, photoStore: photos),
            locale: locale,
            calendar: calendar
        )
    }
}

/// No notifications, and never the iOS prompt.
private struct SilentScheduler: NotificationScheduler {
    func authorization() async -> NotificationAuthorization { .notDetermined }
    func requestAuthorization() async -> Bool { false }
    func replacePending(with reminders: [PendingReminder]) async {}
    func removeDelivered() async {}
}

private struct NoSchedule: ScheduleWeeklyRemindersUseCase {
    func execute(on date: Date) async {}
}

/// Makes no film: the screens that only open the film sheet never ask for one.
struct NoFilmRenderer: SagaFilmRendering {
    func render(_ script: SagaFilmScript, progress: @escaping @MainActor @Sendable (Double) -> Void) async throws -> URL {
        throw CancellationError()
    }

    func discardFilms() async {}
}
