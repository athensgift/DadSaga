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
        sut.family.children[0].name = "  "
        sut.continueToHero()
        #expect(!sut.canContinue)
        #expect(sut.step == .child)
    }

    @Test("Given a name and a chosen hero, when finishing, then the profile is saved and onFinished is called")
    func finishSaves() async {
        var finished = false
        let sut = makeSUT { finished = true }
        sut.family.children[0].name = "Νίκος"
        sut.family.children[0].gender = .girl
        sut.family.children[0].skinTone = .dark
        sut.continueToHero()
        #expect(sut.step == .hero)
        #expect(!sut.canFinish)

        sut.family.dadSkinTone = .medium
        sut.selectHero(id: "h-cool")
        await sut.finish()

        #expect(finished)
        let saved = await save.saved
        #expect(saved?.heroClassID == "h-cool")
        #expect(saved?.dadSkinTone == .medium)
        #expect(saved?.children.map(\.name) == ["Νίκος"])
        #expect(saved?.children.first?.gender == .girl)
        #expect(saved?.children.first?.skinTone == .dark)
    }

    @Test("Given one child, when adding children, then up to four can be added, each needs a name, and one can be removed")
    func severalChildren() async {
        let sut = makeSUT()
        sut.family.children[0].name = "Νίκος"
        #expect(!sut.family.canRemoveChild)

        sut.addChild()
        #expect(!sut.canContinue)
        sut.family.children[1].name = "Άννα"
        #expect(sut.canContinue)
        #expect(sut.family.children[1].skinTone == sut.family.children[0].skinTone)

        sut.addChild()
        sut.addChild()
        sut.addChild()
        #expect(sut.family.children.count == 4)
        #expect(!sut.family.canAddChild)

        sut.removeChild(id: sut.family.children[3].id)
        sut.removeChild(id: sut.family.children[2].id)
        #expect(sut.family.children.map(\.name) == ["Νίκος", "Άννα"])

        sut.continueToHero()
        sut.selectHero(id: "h-super")
        await sut.finish()
        #expect(await save.saved?.children.map(\.name) == ["Νίκος", "Άννα"])
    }

    @Test("Given saving fails, when finishing, then an error is shown and onFinished is not called")
    func finishFailure() async {
        var finished = false
        let sut = makeSUT { finished = true }
        await save.failNext()
        sut.family.children[0].name = "Νίκος"
        sut.selectHero(id: "h-cool")

        await sut.finish()

        #expect(!finished)
        #expect(sut.errorMessage == "Δεν αποθηκεύτηκε. Δοκίμασε ξανά.")
    }
}

/// An in-memory stand-in for both progress use cases, backed by the stub catalog.
actor FakeProgress: GetProgressUseCase, CompleteQuestUseCase, DefeatBossUseCase, CaptureMomentUseCase {
    private var events: [ProgressEvent] = []
    private var shouldFail = false

    func seed(times: Int) {
        events = (0..<times).map { _ in
            ProgressEvent(kind: .quest(id: "q1"), childID: HeroStub.niko.id, date: HeroStub.today)
        }
    }

    func failNext() {
        shouldFail = true
    }

    func execute() async throws -> DadProgress {
        DadProgress(events: events, catalog: HeroStub.catalog)
    }

    func execute(questID: String, childID: UUID, on date: Date) async throws -> ProgressChange {
        try record(.quest(id: questID), childID: childID, on: date)
    }

    func execute(bossID: String, childID: UUID, on date: Date) async throws -> ProgressChange {
        try record(.boss(id: bossID), childID: childID, on: date)
    }

    func execute(firstID: String, childID: UUID, happenedOn date: Date, note: String?, now: Date) async throws -> ProgressChange {
        if shouldFail { throw StubError.boom }
        let before = DadProgress(events: events, catalog: HeroStub.catalog)
        events.append(ProgressEvent(kind: .first(id: firstID), childID: childID, date: date, note: note))
        return ProgressChange(before: before, after: DadProgress(events: events, catalog: HeroStub.catalog))
    }

    var recordedChildIDs: [UUID?] { events.map(\.childID) }

    private func record(_ kind: ProgressEvent.Kind, childID: UUID, on date: Date) throws -> ProgressChange {
        if shouldFail { throw StubError.boom }
        let before = DadProgress(events: events, catalog: HeroStub.catalog)
        events.append(ProgressEvent(kind: kind, childID: childID, date: date))
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
/// A child named "Ελένη" is treated as older than every world.
struct StubGetAdventure: GetAdventureUseCase {
    func execute(for child: Child, on date: Date) async throws -> Adventure {
        let catalog = HeroStub.catalog
        if child.name == "Ελένη" {
            return Adventure(
                ageInMonths: 60, currentWorld: nil, unlockedWorlds: catalog.worlds,
                availableQuests: [], availableBosses: [], isBeyondContent: true
            )
        }
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
    static let niko = Child(name: "Νίκος", birthDate: today)
    static let eleni = Child(name: "Ελένη", birthDate: today, gender: .girl)
    static let profile = PlayerProfile(children: [niko], heroClassID: "h-cool", dadSkinTone: .mediumDark)
    static let family = PlayerProfile(children: [niko, eleni], heroClassID: "h-cool")
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
        ],
        gear: [
            GearItem(id: "g1", skill: .care, minXP: 50, look: "burpCloth", title: LocalizedText(el: "Πανάκι", en: "Burp cloth")),
            GearItem(id: "g2", skill: .care, minXP: 200, look: "unknownLook", title: text)
        ]
    )
}
