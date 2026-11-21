import Application
import Domain
import Foundation
import Testing

/// Start over against the real weekly reminder, so its notifications go through the one reschedule queue.
extension WeeklyReminderUseCaseTests {
    func startOver(
        eraser: SpySagaEraser,
        photos: SpyPhotoStore,
        schedule: any ScheduleWeeklyRemindersUseCase,
        scheduler: any NotificationScheduler,
        offers: FakeSagaOffers = FakeSagaOffers()
    ) -> DefaultStartOverUseCase {
        DefaultStartOverUseCase(
            eraser: eraser, photoStore: photos, reminderSettings: settings, sagaOffers: offers, schedule: schedule,
            notificationScheduler: scheduler
        )
    }

    @Test("Given film offers the dad answered, when starting over, then none is remembered")
    func startOverForgetsFilmOffers() async throws {
        try await onboard([lena])
        let scheduler = FakeNotificationScheduler(status: .allowed)
        let offers = FakeSagaOffers()
        let answer = DefaultAnswerSagaOfferUseCase(repository: offers)
        await answer.execute(occasionID: "lena/birthday/1")
        await answer.execute(occasionID: "lena/world/w1")

        try await startOver(
            eraser: SpySagaEraser(), photos: SpyPhotoStore(), schedule: schedule(scheduler), scheduler: scheduler,
            offers: offers
        ).execute(on: today)

        #expect(await offers.answeredOccasionIDs().isEmpty)
    }

    @Test("Given the store cannot be erased, when starting over, then the answered film offers stay answered")
    func failedEraseKeepsFilmOffers() async throws {
        try await onboard([lena])
        let scheduler = FakeNotificationScheduler(status: .allowed)
        let offers = FakeSagaOffers()
        await DefaultAnswerSagaOfferUseCase(repository: offers).execute(occasionID: "lena/birthday/1")

        await #expect(throws: SpySagaEraser.Failure.self) {
            try await startOver(
                eraser: SpySagaEraser(fails: true), photos: SpyPhotoStore(), schedule: schedule(scheduler),
                scheduler: scheduler, offers: offers
            ).execute(on: today)
        }

        #expect(await offers.answeredOccasionIDs() == ["lena/birthday/1"])
    }

    @Test("Given photos, a reminder, waiting notes and one already shown, when starting over, then all of it is gone")
    func startOverErasesEverything() async throws {
        try await onboard([lena])
        await enable()
        let scheduler = FakeNotificationScheduler(status: .allowed)
        let schedule = schedule(scheduler)
        await schedule.execute(on: today)
        await scheduler.deliverNext()
        let photos = SpyPhotoStore()
        _ = try await photos.save(Data([1]))
        let eraser = SpySagaEraser()

        try await startOver(eraser: eraser, photos: photos, schedule: schedule, scheduler: scheduler).execute(on: today)

        #expect(await eraser.callCount == 1)
        #expect(await photos.stored.isEmpty)
        #expect(await settings.fetch() == .default)
        #expect(await scheduler.pending.isEmpty)
        #expect(await scheduler.delivered.isEmpty)
    }

    @Test("Given the store cannot be erased, when starting over, then it throws and photos, reminder and notes stay")
    func failedEraseKeepsTheRest() async throws {
        try await onboard([lena])
        await enable()
        let scheduler = FakeNotificationScheduler(status: .allowed)
        let schedule = schedule(scheduler)
        await schedule.execute(on: today)
        let photos = SpyPhotoStore()
        _ = try await photos.save(Data([1]))
        let reminder = await settings.fetch()

        await #expect(throws: SpySagaEraser.Failure.self) {
            try await startOver(eraser: SpySagaEraser(fails: true), photos: photos, schedule: schedule, scheduler: scheduler)
                .execute(on: today)
        }

        #expect(await photos.stored.count == 1)
        #expect(await settings.fetch() == reminder)
        #expect(await scheduler.pending.count == 4)
    }

    @Test("Given a slow reschedule already under way, when starting over, then nothing is left waiting once both end")
    func startOverWaitsForReschedule() async throws {
        try await onboard([lena])
        await enable()
        let scheduler = SlowFirstScheduler()
        let schedule = DefaultScheduleWeeklyRemindersUseCase(
            settings: settings,
            scheduler: scheduler,
            profileRepository: profiles,
            highlights: DefaultGetWeeklyHighlightsUseCase(
                contentRepository: StubContentRepository(result: .success(Self.catalog)),
                profileRepository: profiles,
                progressRepository: progress,
                photoStore: SpyPhotoStore(),
                calendar: Fixture.calendar
            ),
            text: EchoReminderText(),
            calendar: Fixture.calendar
        )

        let leaving = Task { await schedule.execute(on: today) }
        while await scheduler.calls == 0 { await Task.yield() }
        try await startOver(eraser: SpySagaEraser(), photos: SpyPhotoStore(), schedule: schedule, scheduler: scheduler)
            .execute(on: today)
        await leaving.value

        #expect(await scheduler.pending.isEmpty)
    }
}

@Suite("Editing the profile")
struct EditProfileUseCaseTests {
    let today = Date(timeIntervalSince1970: 1_000_000)
    let anna = Child(name: "Άννα", birthDay: CalendarDay(Date(timeIntervalSince1970: 500_000), in: .gmt))
    let nikos = Child(name: "Νίκος", birthDay: CalendarDay(Date(timeIntervalSince1970: 600_000), in: .gmt))
    static let text = Stub.text
    let content = StubContentRepository(result: .success(ContentCatalog(
        worlds: [],
        quests: [Quest(id: "q1", worldID: "w1", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0)],
        bosses: [],
        firsts: [],
        heroClasses: [
            HeroClass(id: "h1", order: 1, title: text, tagline: text, look: "hero"),
            HeroClass(id: "h2", order: 2, title: text, tagline: text, look: "chef")
        ],
        gear: [GearItem(id: "cloth", skill: .care, minXP: 20, look: "burpCloth", title: text)],
        appearanceOptions: [DadAppearanceOption(part: .beard, id: "none", title: text)]
    )))
    let shavedNoBeard = DadAppearance(hair: .shaved, hairColor: .grey, beard: .none, glasses: .round)

    func stored(_ profiles: SpyProfileRepository) async throws -> PlayerProfile {
        let profile = PlayerProfile(children: [anna, nikos], heroClassID: "h1", dadSkinTone: .light)
        try await profiles.save(profile)
        return profile
    }

    @Test("Given a family of two, when changing the hero, tone and look, then all three are stored and the children stay")
    func changesHero() async throws {
        let profiles = SpyProfileRepository()
        _ = try await stored(profiles)

        try await DefaultUpdateHeroUseCase(contentRepository: content, profileRepository: profiles)
            .execute(heroClassID: "h2", skinTone: .dark, appearance: shavedNoBeard, on: today)

        let profile = try #require(try await profiles.fetchProfile())
        #expect(profile.heroClassID == "h2")
        #expect(profile.dadSkinTone == .dark)
        #expect(profile.dadAppearance == shavedNoBeard)
        #expect(profile.children.map(\.id) == [anna.id, nikos.id])
    }

    @Test("Given an unknown hero class, when changing the hero, then it throws and the profile is unchanged")
    func rejectsUnknownHero() async throws {
        let profiles = SpyProfileRepository()
        let before = try await stored(profiles)

        await #expect(throws: ProfileValidationError.unknownHeroClass("nope")) {
            try await DefaultUpdateHeroUseCase(contentRepository: content, profileRepository: profiles)
                .execute(heroClassID: "nope", skinTone: .dark, appearance: shavedNoBeard, on: today)
        }
        #expect(try await profiles.fetchProfile() == before)
    }

    @Test("Given the hero h1 with a light tone and a look, when updating the children, then hero, tone and look are kept")
    func changesFamily() async throws {
        let profiles = SpyProfileRepository()
        _ = try await stored(profiles)
        try await DefaultUpdateHeroUseCase(contentRepository: content, profileRepository: profiles)
            .execute(heroClassID: "h1", skinTone: .light, appearance: shavedNoBeard, on: today)

        try await DefaultUpdateFamilyUseCase(profileRepository: profiles)
            .execute(children: [anna], hasPartner: true, on: today)

        let profile = try #require(try await profiles.fetchProfile())
        #expect(profile == PlayerProfile(
            children: [anna], heroClassID: "h1", dadSkinTone: .light, dadAppearance: shavedNoBeard
        ))
    }

    @Test("Given no profile, when editing either part, then it throws noProfile")
    func noProfile() async {
        let profiles = SpyProfileRepository()
        await #expect(throws: ProfileEditError.noProfile) {
            try await DefaultUpdateHeroUseCase(contentRepository: content, profileRepository: profiles)
                .execute(heroClassID: "h1", skinTone: .dark, appearance: shavedNoBeard, on: today)
        }
        await #expect(throws: ProfileEditError.noProfile) {
            try await DefaultUpdateFamilyUseCase(profileRepository: profiles)
                .execute(children: [anna], hasPartner: true, on: today)
        }
    }

    @Test("Given earned gear and a chosen outfit, when changing the hero and look, then the wardrobe and XP stay the same")
    func heroChangeKeepsWardrobe() async throws {
        let profiles = SpyProfileRepository()
        _ = try await stored(profiles)
        let progress = SpyProgressRepository()
        try await progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: anna.id, date: today))
        let outfit = SpyOutfitRepository()
        _ = try await outfit.setChoice(.item("cloth"), for: .care)
        let wardrobe = DefaultGetWardrobeUseCase(
            contentRepository: content, profileRepository: profiles, progressRepository: progress, outfitRepository: outfit
        )
        let before = try await wardrobe.execute()

        try await DefaultUpdateHeroUseCase(contentRepository: content, profileRepository: profiles)
            .execute(heroClassID: "h2", skinTone: .dark, appearance: shavedNoBeard, on: today)

        let after = try await wardrobe.execute()
        #expect(after.outfit == before.outfit)
        #expect(after.equipped.map(\.id) == ["cloth"])
        #expect(after.equipped == before.equipped)
        #expect(try await progress.fetchEvents().count == 1)
    }

    @Test("Given a stored hero the content no longer has, when the family is saved, then it saves and keeps that hero")
    func familySavesWithAnUnknownHero() async throws {
        let profiles = SpyProfileRepository()
        try await profiles.save(PlayerProfile(children: [anna, nikos], heroClassID: "gone", dadSkinTone: .light))

        try await DefaultUpdateFamilyUseCase(profileRepository: profiles)
            .execute(children: [anna], hasPartner: true, on: today)

        let profile = try #require(try await profiles.fetchProfile())
        #expect(profile.children.map(\.id) == [anna.id])
        #expect(profile.heroClassID == "gone")
    }

    @Test("Given a stored hero the content lacks, when the hero page opens and the look changes, then the first hero is saved")
    func heroPageWithAnUnknownHeroSavesTheLook() async throws {
        let profiles = SpyProfileRepository()
        try await profiles.save(PlayerProfile(children: [anna], heroClassID: "gone", dadSkinTone: .light))

        let choice = try #require(
            try await DefaultGetHeroChoiceUseCase(contentRepository: content, profileRepository: profiles).execute()
        )
        #expect(choice.heroClassID == "h1")
        try await DefaultUpdateHeroUseCase(contentRepository: content, profileRepository: profiles)
            .execute(heroClassID: choice.heroClassID, skinTone: .light, appearance: shavedNoBeard, on: today)

        let profile = try #require(try await profiles.fetchProfile())
        #expect(profile.heroClassID == "h1")
        #expect(profile.dadAppearance == shavedNoBeard)
    }

    @Test("Given a hero stored before it was renamed, when the hero page opens, then the renamed hero is selected")
    func heroPageShowsTheRenamedHero() async throws {
        let text = Self.text
        let renamed = StubContentRepository(result: .success(ContentCatalog(
            worlds: [], quests: [], bosses: [], firsts: [],
            heroClasses: [
                HeroClass(id: "h1", order: 1, title: text, tagline: text, look: "hero"),
                HeroClass(id: "h2", order: 2, title: text, tagline: text, look: "chef", formerIDs: ["h-old"])
            ]
        )))
        let profiles = SpyProfileRepository()
        try await profiles.save(PlayerProfile(children: [anna], heroClassID: "h-old"))

        let choice = try #require(
            try await DefaultGetHeroChoiceUseCase(contentRepository: renamed, profileRepository: profiles).execute()
        )

        #expect(choice.heroClassID == "h2")
    }

    @Test("Given a stored profile, when reading the hero choice, then it has the classes, the id, the tone and the look")
    func heroChoice() async throws {
        let profiles = SpyProfileRepository()
        _ = try await stored(profiles)
        let sut = DefaultGetHeroChoiceUseCase(contentRepository: content, profileRepository: profiles)

        let choice = try #require(try await sut.execute())
        #expect(choice.heroClasses.map(\.id) == ["h1", "h2"])
        #expect(choice.heroClassID == "h1")
        #expect(choice.skinTone == .light)
        #expect(choice.appearance == .standard(for: .light))
        #expect(choice.appearanceOptions.map(\.id) == ["none"])
        #expect(try await DefaultGetHeroChoiceUseCase(
            contentRepository: content, profileRepository: SpyProfileRepository()
        ).execute() == nil)
    }
}

@Suite("Preferences use cases")
struct PreferencesUseCaseTests {
    @Test("Given nothing saved, when reading, then System with haptics on; after saving Dark, Dark")
    func roundTrip() async {
        let repository = InMemoryPreferences()
        #expect(await DefaultGetPreferencesUseCase(repository: repository).execute() == .default)

        await DefaultSavePreferencesUseCase(repository: repository)
            .execute(Preferences(appearance: .dark, hapticsEnabled: false))

        #expect(await DefaultGetPreferencesUseCase(repository: repository).execute()
            == Preferences(appearance: .dark, hapticsEnabled: false))
    }
}

actor InMemoryPreferences: PreferencesRepository {
    private var stored = Preferences.default
    func fetch() async -> Preferences { stored }
    func save(_ preferences: Preferences) async { stored = preferences }
}

actor SpySagaEraser: SagaEraser {
    struct Failure: Error {}
    private(set) var callCount = 0
    private let fails: Bool

    init(fails: Bool = false) {
        self.fails = fails
    }

    func eraseAll() async throws {
        if fails { throw Failure() }
        callCount += 1
    }
}
