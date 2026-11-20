import Application
import Data
import Domain
import Foundation
import Presentation

/// One dad's saga, the same on every run: a fixed day, a four-month-old, three quests and two firsts, in a
/// store in memory, with the app's real content. The screens are built the way `AppContainer` builds them, with the
/// locale and the clock passed in instead of read from the phone.
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
    private let scheduler = SilentScheduler()

    init(locale: Locale) {
        self.locale = locale
        let defaults = UserDefaults(suiteName: "dadsaga.snapshots." + UUID().uuidString) ?? .standard
        reminderSettings = UserDefaultsReminderSettingsRepository(defaults: defaults)
        preferences = UserDefaultsPreferencesRepository(defaults: defaults)
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

    static func day(_ daysAgo: Double) -> Date { today.addingTimeInterval(-daysAgo * 86_400) }

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
                    outfitRepository: store.outfit
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
                reminder: reminder
            ),
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
                    now: Self.today,
                    onSaved: onSaved
                )
            },
            makeFamily: { onSaved in
                FamilyViewModel(
                    getProfile: DefaultGetProfileUseCase(repository: store.profiles),
                    updateFamily: DefaultUpdateFamilyUseCase(contentRepository: content, profileRepository: store.profiles),
                    locale: locale,
                    now: Self.today,
                    onSaved: onSaved
                )
            },
            makeReminder: { ReminderSettingsViewModel(useCases: reminder, locale: locale, now: { Self.today }) }
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
