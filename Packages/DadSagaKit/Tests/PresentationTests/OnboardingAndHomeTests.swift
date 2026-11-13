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
        #expect(content.heroes.map(\.title) == ["Ιππότης", "Μάγος"])
        #expect(content.heroes.map(\.look) == [.knight, .mage])
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

        sut.selectHero(id: "h-mage")
        await sut.finish()

        #expect(finished)
        #expect(await save.saved?.heroClassID == "h-mage")
        #expect(await save.saved?.child.name == "Νίκος")
    }

    @Test("Given saving fails, when finishing, then an error is shown and onFinished is not called")
    func finishFailure() async {
        var finished = false
        let sut = makeSUT { finished = true }
        await save.failNext()
        sut.childName = "Νίκος"
        sut.selectHero(id: "h-mage")

        await sut.finish()

        #expect(!finished)
        #expect(sut.errorMessage == "Δεν αποθηκεύτηκε. Δοκίμασε ξανά.")
    }
}

@MainActor
@Suite("HomeViewModel")
struct HomeViewModelTests {
    func makeSUT(profile: PlayerProfile?, locale: String = "el_GR") -> HomeViewModel {
        HomeViewModel(
            getProfile: StubGetProfile(profile: profile),
            loadCatalog: StubLoadCatalog(result: .success(HeroStub.catalog)),
            getAdventure: StubGetAdventure(),
            locale: Locale(identifier: locale),
            now: { HeroStub.today }
        )
    }

    @Test("Given a mage dad with a 10-month-old, when appearing, then hero, companion and current-world cards are shown")
    func loaded() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.heroTitle == "Μάγος")
        #expect(content.heroLook == .mage)
        #expect(content.companionLine == "Νίκος · 10 μηνών")
        #expect(content.level == 1)
        #expect(content.worldTitle == "Κόσμος")
        #expect(content.cards.map(\.id) == ["b1", "q1"])
    }

    @Test("Given an English locale, when appearing, then the companion line is English")
    func english() async {
        let sut = makeSUT(profile: HeroStub.profile, locale: "en_US")
        await sut.onAppear()

        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.heroTitle == "Mage")
        #expect(content.companionLine == "Νίκος · 10 months old")
    }

    @Test("Given no profile, when appearing, then state is failed")
    func noProfile() async {
        let sut = makeSUT(profile: nil)
        await sut.onAppear()
        #expect(sut.state == .failed(message: "Δεν βρέθηκε προφίλ."))
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
    static let profile = PlayerProfile(child: Child(name: "Νίκος", birthDate: today), heroClassID: "h-mage")
    static let catalog = ContentCatalog(
        worlds: Stub.catalog.worlds,
        quests: Stub.catalog.quests,
        bosses: Stub.catalog.bosses,
        firsts: Stub.catalog.firsts,
        heroClasses: [
            HeroClass(id: "h-mage", order: 2, title: LocalizedText(el: "Μάγος", en: "Mage"), tagline: text),
            HeroClass(id: "h-knight", order: 1, title: LocalizedText(el: "Ιππότης", en: "Knight"), tagline: text)
        ]
    )
}
