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
actor FakeProgress: CompleteQuestUseCase, DefeatBossUseCase, CaptureMomentUseCase,
    UpdateMomentUseCase, DeleteEventUseCase, GetPhotoUseCase {
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

    private var isSlow = false

    /// The next quest takes a while to save, like a slow disk.
    func slowNext() {
        isSlow = true
    }

    /// The log as the dad's progress, read against the hero stub catalog.
    var current: DadProgress {
        DadProgress(events: events, catalog: HeroStub.catalog)
    }

    func execute(questID: String, childID: UUID, on date: Date, journal: JournalInput) async throws -> ProgressChange {
        if isSlow {
            isSlow = false
            try? await Task.sleep(for: .milliseconds(200))
        }
        return try record(.quest(id: questID), childID: childID, on: date, note: journal.note)
    }

    func execute(bossID: String, childID: UUID, on date: Date, journal: JournalInput) async throws -> ProgressChange {
        try record(.boss(id: bossID), childID: childID, on: date, note: journal.note)
    }

    private var photos: [String: Data] = [:]

    func execute(_ request: CaptureMomentRequest, now: Date) async throws -> ProgressChange {
        if shouldFail { throw StubError.boom }
        let before = DadProgress(events: events, catalog: HeroStub.catalog)
        let event = ProgressEvent(
            kind: .first(id: request.firstID), childID: request.childID, date: request.date
        )
        events.append(event)
        return ProgressChange(
            before: before,
            after: DadProgress(events: events, catalog: HeroStub.catalog),
            eventID: event.id,
            gear: HeroStub.catalog.gear
        )
    }

    func execute(momentID: UUID, happenedOn date: Date, note: String?, photos: [EntryPhoto], now: Date) async throws {
        if shouldFail { throw StubError.boom }
        guard let index = events.firstIndex(where: { $0.id == momentID }) else { return }
        let old = events[index]
        let photoIDs = photos.map { photo in
            switch photo {
            case .kept(let id): id
            case .added(let data): store(data)
            }
        }
        events[index] = ProgressEvent(
            id: old.id, kind: old.kind, childID: old.childID, date: date, note: note, photoIDs: photoIDs
        )
    }

    /// A moment of the first `HeroStub.niko` can capture, already holding these photos.
    func seedMoment(photos: [Data]) {
        events.append(ProgressEvent(
            kind: .first(id: "f1"), childID: HeroStub.niko.id, date: HeroStub.today, photoIDs: photos.map(store)
        ))
    }

    private func store(_ data: Data) -> String {
        let id = "photo-\(self.photos.count + 1)"
        self.photos[id] = data
        return id
    }

    func execute(eventID: UUID) async throws {
        if shouldFail { throw StubError.boom }
        events.removeAll { $0.id == eventID }
    }

    func execute(id: String, maxPixelSize: Int) async -> Data? {
        photos[id]
    }

    var recordedChildIDs: [UUID] { events.map(\.childID) }
    var eventCount: Int { events.count }

    private func record(_ kind: ProgressEvent.Kind, childID: UUID, on date: Date, note: String?) throws -> ProgressChange {
        if shouldFail { throw StubError.boom }
        let before = DadProgress(events: events, catalog: HeroStub.catalog)
        let event = ProgressEvent(kind: kind, childID: childID, date: date, note: note)
        events.append(event)
        return ProgressChange(
            before: before,
            after: DadProgress(events: events, catalog: HeroStub.catalog),
            eventID: event.id,
            gear: HeroStub.catalog.gear
        )
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

/// Home's overview from stubs: the family, the fake log and wardrobe, and an adventure per child. Built with the real
/// `HomeOverview`, so which world, quests, bosses and gear show follows the same rules as the app.
struct FakeHomeOverview: GetHomeOverviewUseCase {
    let profile: PlayerProfile?
    var catalog = HeroStub.catalog
    let progress: FakeProgress
    var outfit = FakeOutfit()
    var adventure: @Sendable (Child) -> Adventure = HeroStub.adventure
    /// The film offer home finds, until the dad answers it.
    var film = FakeFilmOffers()

    func execute(childID: UUID?, worldID: String?, on date: Date) async throws -> HomeOverview? {
        guard let profile, let child = profile.child(childID) else { return nil }
        return HomeOverview(
            profile: profile,
            child: child,
            catalog: catalog,
            adventure: adventure(child),
            progress: await progress.current,
            outfit: await outfit.stored,
            worldID: worldID,
            sagaOffer: await film.pending
        )
    }
}

enum HeroStub {
    /// The stub catalog's world with everything available. A child named "Ελένη" is older than every world.
    @Sendable
    static func adventure(for child: Child) -> Adventure {
        if child.name == "Ελένη" {
            return Adventure(
                ageInMonths: 60, currentWorld: nil, unlockedWorlds: catalog.worlds,
                availableBosses: [], isBeyondContent: true
            )
        }
        return Adventure(
            ageInMonths: 10,
            currentWorld: catalog.worlds.first,
            unlockedWorlds: catalog.worlds,
            availableBosses: catalog.bosses
        )
    }

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
            GearItem(id: "g1", skill: .care, minXP: 50, look: "burpCloth", title: LocalizedText(el: "Πανάκι", en: "Burp cloth")),
            GearItem(id: "g2", skill: .care, minXP: 200, look: "unknownLook", title: text)
        ]
    )
}
