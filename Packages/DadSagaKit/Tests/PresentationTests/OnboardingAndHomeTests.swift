import Application
import Domain
import Foundation
import Presentation
import Testing

@MainActor
@Suite("RootViewModel")
struct RootViewModelTests {
    @Test("Given no stored profile, when appearing, then onboarding is shown, and home after it finishes")
    func newPlayer() async {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: nil))
        #expect(sut.state == .loading)

        await sut.onAppear()
        #expect(sut.state == .onboarding)

        sut.onboardingFinished()
        #expect(sut.state == .home)
    }

    @Test("Given a stored profile, when appearing, then home is shown")
    func returningPlayer() async {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: HeroStub.profile))
        await sut.onAppear()
        #expect(sut.state == .home)
        #expect(!sut.hasDeveloperMenu)
    }

    @Test("Given a development build, when restarting from the developer menu, then the profile is reset and onboarding shows")
    func developerRestart() async {
        let reset = SpyResetProfile()
        let sut = RootViewModel(getProfile: StubGetProfile(profile: HeroStub.profile), resetProfile: reset)
        await sut.onAppear()
        #expect(sut.hasDeveloperMenu)

        await sut.restartFromOnboarding()

        #expect(sut.state == .onboarding)
        #expect(await reset.callCount == 1)
    }
}

actor SpyResetProfile: ResetProfileUseCase {
    private(set) var callCount = 0

    func execute() async throws {
        callCount += 1
    }
}

@MainActor
@Suite("OnboardingViewModel")
struct OnboardingViewModelTests {
    let save = SpySaveProfile()

    func makeSUT(onFinished: @escaping @MainActor () -> Void = {}) -> OnboardingViewModel {
        OnboardingViewModel(
            loadCatalog: StubLoadCatalog(result: .success(HeroStub.catalog)),
            saveProfile: save,
            locale: Locale(identifier: "el_GR"),
            now: HeroStub.today,
            onFinished: onFinished
        )
    }

    @Test("Given hero classes in the content, when appearing, then they are offered in Greek with their look")
    func loadsHeroes() async {
        let sut = makeSUT()
        await sut.onAppear()

        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.heroes.map(\.title) == ["Σούπερ Μπαμπάς", "Cool Μπαμπάς"])
        #expect(content.heroes.map(\.look) == [.hero, .cool])
    }

    @Test("Given a blank name, when continuing, then the step does not change")
    func blankNameBlocksContinue() {
        let sut = makeSUT()
        sut.childName = "  "
        sut.continueToHero()
        #expect(!sut.canContinue)
        #expect(sut.step == .child)
    }

    @Test("Given a name and a chosen hero, when finishing, then the profile is saved and onFinished is called")
    func finishSaves() async {
        var finished = false
        let sut = makeSUT { finished = true }
        sut.childName = "Νίκος"
        sut.continueToHero()
        #expect(sut.step == .hero)
        #expect(!sut.canFinish)

        sut.selectHero(id: "h-cool")
        await sut.finish()

        #expect(finished)
        #expect(await save.saved?.heroClassID == "h-cool")
        #expect(await save.saved?.child.name == "Νίκος")
    }

    @Test("Given saving fails, when finishing, then an error is shown and onFinished is not called")
    func finishFailure() async {
        var finished = false
        let sut = makeSUT { finished = true }
        await save.failNext()
        sut.childName = "Νίκος"
        sut.selectHero(id: "h-cool")

        await sut.finish()

        #expect(!finished)
        #expect(sut.errorMessage == "Δεν αποθηκεύτηκε. Δοκίμασε ξανά.")
    }
}

@MainActor
@Suite("HomeViewModel")
struct HomeViewModelTests {
    let progress = FakeProgress()

    func makeSUT(profile: PlayerProfile?, locale: String = "el_GR") -> HomeViewModel {
        HomeViewModel(
            useCases: HomeViewModel.UseCases(
                getProfile: StubGetProfile(profile: profile),
                loadCatalog: StubLoadCatalog(result: .success(HeroStub.catalog)),
                getAdventure: StubGetAdventure(),
                getProgress: progress,
                completeQuest: progress,
                defeatBoss: progress
            ),
            locale: Locale(identifier: locale),
            now: { HeroStub.today }
        )
    }

    @Test("Given a quest card, when selecting and confirming it, then XP is gained, the card shows it and the hero celebrates")
    func completesQuest() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.select(cardID: "q1")
        #expect(sut.selectedQuest?.title == "Αποστολή")
        #expect(sut.selectedQuest?.reward == "+20 XP · Φροντίδα")
        await sut.completeSelectedQuest()

        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(sut.selectedQuest == nil)
        #expect(content.xpLine == "20 / 100 XP")
        #expect(content.cards.last?.footnote == "Το έκανες 1 φορά")
        #expect(sut.celebration?.id == 1)
        #expect(sut.celebration?.xpText == "+20 XP")
        #expect(sut.celebration?.levelUpText == nil)

        sut.celebrationFinished()
        #expect(sut.celebration == nil)
    }

    @Test("Given 80 XP, when completing a quest, then the celebration announces the new level")
    func levelUpCelebration() async {
        await progress.seed(times: 4)
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        #expect(sut.celebration?.levelUpText == "Επίπεδο 2!")
    }

    @Test("Given a boss card, when selecting it, then its intro, guide and reward are shown")
    func bossDetail() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.select(cardID: "b1")

        #expect(sut.selectedQuest == nil)
        #expect(sut.selectedBoss?.title == "Αφεντικό")
        #expect(sut.selectedBoss?.intro == "ι")
        #expect(sut.selectedBoss?.guide == ["βήμα"])
        #expect(sut.selectedBoss?.reward == "+100 XP · β")
        #expect(sut.selectedBoss?.isDefeated == false)
    }

    @Test("Given a boss, when defeating it, then XP, badge and level-up are celebrated and the card shows the badge")
    func defeatsBoss() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.select(cardID: "b1")
        await sut.defeatSelectedBoss()

        #expect(sut.selectedBoss == nil)
        #expect(sut.celebration?.xpText == "+100 XP")
        #expect(sut.celebration?.badgeText == "β")
        #expect(sut.celebration?.levelUpText == "Επίπεδο 2!")
        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.cards.first?.footnote == "Νικήθηκε · β")

        sut.select(cardID: "b1")
        #expect(sut.selectedBoss?.isDefeated == true)
    }

    @Test("Given saving fails, when confirming a quest, then the sheet stays open with an error")
    func completionFailure() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        await progress.failNext()

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        #expect(sut.selectedQuest != nil)
        #expect(sut.errorMessage == "Δεν αποθηκεύτηκε. Δοκίμασε ξανά.")
        #expect(sut.celebration == nil)
    }

    @Test("Given a cool dad with a 10-month-old, when appearing, then hero, companion and current-world cards are shown")
    func loaded() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.heroTitle == "Cool Μπαμπάς")
        #expect(content.heroLook == .cool)
        #expect(content.companionLine == "Νίκος · 10 μηνών")
        #expect(content.level == 1)
        #expect(content.levelTitle == "Επίπεδο 1")
        #expect(content.xpLine == "0 / 100 XP")
        #expect(content.worldTitle == "Κόσμος")
        #expect(content.cards.map(\.id) == ["b1", "q1"])
        #expect(content.cards.map(\.symbol) == ["flame.fill", "heart.fill"])
        #expect(content.cards.last?.badge == "+20 XP")
    }

    @Test("Given an English locale, when appearing, then the companion line is English")
    func english() async {
        let sut = makeSUT(profile: HeroStub.profile, locale: "en_US")
        await sut.onAppear()

        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.heroTitle == "Cool Dad")
        #expect(content.companionLine == "Νίκος · 10 months old")
    }

    @Test("Given no profile, when appearing, then state is failed")
    func noProfile() async {
        let sut = makeSUT(profile: nil)
        await sut.onAppear()
        #expect(sut.state == .failed(message: "Δεν βρέθηκε προφίλ."))
    }
}

/// An in-memory stand-in for both progress use cases, backed by the stub catalog.
actor FakeProgress: GetProgressUseCase, CompleteQuestUseCase, DefeatBossUseCase {
    private var events: [ProgressEvent] = []
    private var shouldFail = false

    func seed(times: Int) {
        events = (0..<times).map { _ in ProgressEvent(kind: .quest(id: "q1"), date: HeroStub.today) }
    }

    func failNext() {
        shouldFail = true
    }

    func execute() async throws -> DadProgress {
        DadProgress(events: events, catalog: HeroStub.catalog)
    }

    func execute(questID: String, on date: Date) async throws -> ProgressChange {
        try record(.quest(id: questID), on: date)
    }

    func execute(bossID: String, on date: Date) async throws -> ProgressChange {
        try record(.boss(id: bossID), on: date)
    }

    private func record(_ kind: ProgressEvent.Kind, on date: Date) throws -> ProgressChange {
        if shouldFail { throw StubError.boom }
        let before = DadProgress(events: events, catalog: HeroStub.catalog)
        events.append(ProgressEvent(kind: kind, date: date))
        return ProgressChange(before: before, after: DadProgress(events: events, catalog: HeroStub.catalog))
    }
}

struct StubGetProfile: GetProfileUseCase {
    let profile: PlayerProfile?

    func execute() async throws -> PlayerProfile? {
        profile
    }
}

actor SpySaveProfile: SaveProfileUseCase {
    private(set) var saved: PlayerProfile?
    private var shouldFail = false

    func failNext() {
        shouldFail = true
    }

    func execute(_ profile: PlayerProfile, on date: Date) async throws {
        if shouldFail { throw StubError.boom }
        saved = profile
    }
}

/// Returns the stub catalog's world with everything available, plus one quest from another world.
struct StubGetAdventure: GetAdventureUseCase {
    func execute(for child: Child, on date: Date) async throws -> Adventure {
        let catalog = HeroStub.catalog
        let other = Quest(id: "q-other", worldID: "w0", title: HeroStub.text, description: HeroStub.text,
                          skill: .play, xp: 10, minAgeMonths: 0)
        return Adventure(
            ageInMonths: 10,
            currentWorld: catalog.worlds.first,
            unlockedWorlds: catalog.worlds,
            availableQuests: catalog.quests + [other],
            availableBosses: catalog.bosses
        )
    }
}

enum HeroStub {
    static let today = Date(timeIntervalSince1970: 1_000_000)
    static let text = LocalizedText(el: "x", en: "x")
    static let profile = PlayerProfile(child: Child(name: "Νίκος", birthDate: today), heroClassID: "h-cool")
    static let catalog = ContentCatalog(
        worlds: Stub.catalog.worlds,
        quests: Stub.catalog.quests,
        bosses: [
            BossFight(id: "b1", worldID: "w1", title: LocalizedText(el: "Αφεντικό", en: "Boss"),
                      intro: LocalizedText(el: "ι", en: "i"), guide: [LocalizedText(el: "βήμα", en: "step")],
                      badge: LocalizedText(el: "β", en: "b"), skill: .care, xp: 100, minAgeMonths: 0)
        ],
        firsts: Stub.catalog.firsts,
        heroClasses: [
            HeroClass(id: "h-cool", order: 2, title: LocalizedText(el: "Cool Μπαμπάς", en: "Cool Dad"), tagline: text),
            HeroClass(id: "h-super", order: 1, title: LocalizedText(el: "Σούπερ Μπαμπάς", en: "Super Dad"), tagline: text)
        ]
    )
}
