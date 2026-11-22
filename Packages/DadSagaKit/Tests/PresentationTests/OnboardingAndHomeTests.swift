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
        let sut = RootViewModel(getProfile: StubGetProfile(profile: nil), getPreferences: StubGetPreferences())
        #expect(sut.state == .loading)

        await sut.onAppear()
        #expect(sut.state == .onboarding)

        sut.onboardingFinished()
        #expect(sut.state == .home)
    }

    @Test("Given a stored profile, when appearing, then home is shown")
    func returningPlayer() async {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: HeroStub.profile), getPreferences: StubGetPreferences())
        await sut.onAppear()
        #expect(sut.state == .home)
    }

    @Test("Given dark appearance and haptics off are stored, when appearing, then every screen gets them")
    func appliesStoredPreferences() async {
        let sut = RootViewModel(
            getProfile: StubGetProfile(profile: HeroStub.profile),
            getPreferences: StubGetPreferences(Preferences(appearance: .dark, hapticsEnabled: false))
        )

        await sut.onAppear()

        #expect(sut.preferences == PreferencesChoice(appearance: .dark, isHapticsEnabled: false))
    }

    @Test("Given home, when Settings stores light appearance, then the root switches to it at once")
    func followsSettings() async {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: HeroStub.profile), getPreferences: StubGetPreferences())
        await sut.onAppear()

        sut.preferencesChanged(PreferencesChoice(appearance: .light, isHapticsEnabled: true))

        #expect(sut.preferences.appearance == .light)
    }

    @Test("Given home on the timeline with a link waiting, when the saga was erased, then onboarding opens clean")
    func startedOver() async throws {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: HeroStub.profile), getPreferences: StubGetPreferences())
        await sut.onAppear()
        sut.selectedTab = .timeline
        sut.open(url: try #require(URL(string: "dadsaga://quest/q1")))

        sut.startedOver()

        #expect(sut.state == .onboarding)
        #expect(sut.selectedTab == .adventure)
        #expect(sut.pendingLink == nil)
    }
}

struct StubGetPreferences: GetPreferencesUseCase {
    var preferences = Preferences.default

    init(_ preferences: Preferences = .default) {
        self.preferences = preferences
    }

    func execute() async -> Preferences { preferences }
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
        #expect(content.hero.heroes.map(\.title) == ["Σούπερ Μπαμπάς", "Cool Μπαμπάς"])
        #expect(content.hero.heroes.map(\.look) == [.hero, .cool])
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
        #expect(saved?.dadAppearance == .standard(for: .medium))
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

enum HeroStub {
    /// The stub catalog's world with everything available. A child named "Ελένη" is older than every world.
    @Sendable
    static func adventure(for child: Child) -> Adventure {
        if child.name == "Ελένη" {
            return Adventure(
                age: .months(60), family: .everyone, currentWorld: nil, reachedWorlds: catalog.worlds,
                isBeyondContent: true
            )
        }
        return Adventure(
            age: .months(10),
            family: .everyone,
            currentWorld: catalog.worlds.first,
            reachedWorlds: catalog.worlds
        )
    }

    static let today = Date(timeIntervalSince1970: 1_000_000)
    static let text = LocalizedText(el: "x", en: "x")
    static let niko = Child(name: "Νίκος", birthDay: CalendarDay(today, in: .gmt))
    static let eleni = Child(name: "Ελένη", birthDay: CalendarDay(today, in: .gmt), gender: .girl)
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
            HeroClass(
                id: "h-cool", order: 2, title: LocalizedText(el: "Cool Μπαμπάς", en: "Cool Dad"),
                tagline: text, look: "cool"
            ),
            HeroClass(
                id: "h-super", order: 1, title: LocalizedText(el: "Σούπερ Μπαμπάς", en: "Super Dad"),
                tagline: text, look: "hero"
            )
        ],
        gear: [
            GearItem(
                id: "g1", skill: .care, skillXPBeforeTitles: 50, look: "burpCloth",
                title: LocalizedText(el: "Πανάκι", en: "Burp cloth"), formerIDs: ["g1-before"]
            ),
            GearItem(id: "g2", skill: .care, skillXPBeforeTitles: 200, look: "unknownLook", title: text)
        ],
        titles: [
            DadTitle(id: "t0", order: 0, minCards: 0, minXP: 0, name: LocalizedText(el: "Σε αναμονή", en: "In waiting")),
            DadTitle(
                id: "t1", order: 1, minCards: 1, minXP: 20, gearIDs: ["g1"],
                name: LocalizedText(el: "Νέος στο ταξίδι", en: "New to the journey")
            ),
            DadTitle(
                id: "t2", order: 2, minCards: 5, minXP: 500, gearIDs: ["g2"],
                name: LocalizedText(el: "Σίγουρα χέρια", en: "Steady hands")
            )
        ],
        skillCurves: Skill.allCases.map { SkillCurve(skill: $0, halfGrownXP: 80) }
    )
}
