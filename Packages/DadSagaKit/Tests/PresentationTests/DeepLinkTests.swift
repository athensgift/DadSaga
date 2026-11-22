import Application
import Domain
import Foundation
@testable import Presentation
import Testing

/// Links from the home-screen widget (ADR-0023): they open a screen and never record anything.
@MainActor
@Suite("Links from the widget")
struct DeepLinkTests {
    let progress = FakeProgress()

    func makeSUT(profile: PlayerProfile = HeroStub.family) async -> HomeViewModel {
        let sut = makeHomeViewModel(profile: profile, progress: progress)
        await sut.onAppear()
        return sut
    }

    /// Eleni is past every world, so home lists no quests for her: the link still opens the one it names.
    @Test("Given a quest link for the second child, when opening it, then that child is selected and the quest is open")
    func questForSecondChild() async throws {
        let sut = await makeSUT()

        await sut.open(.quest(id: "q1", childID: HeroStub.eleni.id))

        #expect(sut.selectedChildID == HeroStub.eleni.id)
        #expect(sut.selectedQuest?.id == "q1")
        #expect(await progress.current.totalXP == 0)
    }

    @Test("Given a quest that no longer exists, when opening it, then no sheet opens")
    func questNotAvailable() async {
        let sut = await makeSUT()

        await sut.open(.quest(id: "removed", childID: HeroStub.eleni.id))
        #expect(sut.selectedQuest == nil)
        #expect(sut.selectedChildID == HeroStub.eleni.id)
    }

    @Test("Given a widget link with a quest's id from before a rename, when opening it, then that quest opens")
    func linkWithAFormerQuestIDOpensTheQuest() async {
        let sut = await makeSUT()

        await sut.open(.quest(id: "q1-before", childID: HeroStub.niko.id))

        #expect(sut.selectedQuest?.id == "q1")
    }

    @Test("Given a link for a child no longer in the family, when opening it, then home shows the first child")
    func unknownChild() async {
        let sut = await makeSUT()
        await sut.selectChild(id: HeroStub.eleni.id)

        await sut.open(.quest(id: "q1", childID: UUID()))

        #expect(sut.selectedChildID == HeroStub.niko.id)
        #expect(sut.selectedQuest == nil)
    }

    @Test("Given a moment link, when opening it, then that moment opens; once deleted, the link opens only home")
    func momentLink() async throws {
        let sut = await makeSUT(profile: HeroStub.profile)
        sut.startCapture()
        await sut.captureMoment(firstID: "f1", date: HeroStub.today)
        await sut.saveMomentDetails(date: HeroStub.today, note: "Τρία βήματα!", photos: PhotoDrafts())
        guard case .loaded(let content) = sut.state else { throw StubLinkError.notLoaded }
        let card = try #require(content.moments.cards.first)
        sut.dismissSelection()

        await sut.open(.moment(eventID: card.id, childID: HeroStub.niko.id))
        #expect(sut.momentCapture?.details?.note == "Τρία βήματα!")

        await sut.open(.moment(eventID: UUID(), childID: HeroStub.niko.id))
        #expect(sut.momentCapture == nil)
        #expect(sut.selectedChildID == HeroStub.niko.id)
    }

    @Test("Given an open sheet, when a child link arrives, then it closes and that child shows, on home and the map")
    func childLinkClosesSheets() async {
        let sut = await makeSUT()
        sut.select(cardID: "q1")

        await sut.open(.child(HeroStub.eleni.id))

        #expect(sut.selectedQuest == nil)
        #expect(sut.selectedChildID == HeroStub.eleni.id)
        #expect(sut.worldMap?.subtitle.hasPrefix(HeroStub.eleni.name) == true)
    }
}

@MainActor
@Suite("RootViewModel, links")
struct RootLinkTests {
    @Test("Given a family, when a link arrives on the timeline tab, then Adventure shows and the link waits for home")
    func keepsLinkForHome() async {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: HeroStub.profile), getPreferences: StubGetPreferences())
        await sut.onAppear()
        sut.selectedTab = .timeline
        let link = AppLink.quest(id: "q1", childID: HeroStub.niko.id)

        sut.open(url: link.url)

        #expect(sut.selectedTab == .adventure)
        #expect(sut.pendingLink == PendingLink(link))
        sut.linkHandled(PendingLink(link))
        #expect(sut.pendingLink == nil)
    }

    @Test("Given a note with unsaved words on the timeline, when a link arrives, then it waits there, and goes on after")
    func linkWaitsWhereTheDadIs() async {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: HeroStub.profile), getPreferences: StubGetPreferences())
        await sut.onAppear()
        sut.selectedTab = .timeline
        let note = UUID()
        sut.unsavedWork.set(note, in: UnsavedScope.timelineJournal, hasUnsavedChanges: true)
        let older = AppLink.child(HeroStub.niko.id)
        let newer = AppLink.quest(id: "q1", childID: HeroStub.niko.id)

        sut.open(url: older.url)
        sut.open(url: newer.url)
        #expect(sut.selectedTab == .timeline)
        #expect(sut.pendingLink == nil)

        sut.unsavedWork.end(scope: UnsavedScope.timelineJournal)
        #expect(sut.selectedTab == .adventure)
        #expect(sut.pendingLink == PendingLink(newer))
    }

    @Test("Given a link waiting for an editor, when the dad starts over, then it never opens")
    func startOverDropsAWaitingLink() async {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: HeroStub.profile), getPreferences: StubGetPreferences())
        await sut.onAppear()
        let editor = UUID()
        sut.unsavedWork.set(editor, in: UnsavedScope.settings, hasUnsavedChanges: true)
        sut.open(url: AppLink.child(HeroStub.niko.id).url)

        sut.startedOver()
        sut.unsavedWork.closed(editor)

        #expect(sut.pendingLink == nil)
    }

    @Test("Given \"My family\" holding changes on Settings, when a link arrives, then it waits there, and goes on after")
    func linkWaitsForMyFamily() async {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: HeroStub.profile), getPreferences: StubGetPreferences())
        await sut.onAppear()
        sut.selectedTab = .settings
        let family = UUID()
        sut.unsavedWork.set(family, in: UnsavedScope.settings, hasUnsavedChanges: true)
        let link = AppLink.child(HeroStub.niko.id)

        sut.open(url: link.url)
        #expect(sut.selectedTab == .settings)
        #expect(sut.pendingLink == nil)

        sut.unsavedWork.set(family, in: UnsavedScope.settings, hasUnsavedChanges: false)
        #expect(sut.selectedTab == .adventure)
        #expect(sut.pendingLink == PendingLink(link))
    }

    @Test("Given Adventure, when the dad goes to any other tab, then home is told once each time he leaves it")
    func leavingAdventureIsTold() async {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: HeroStub.profile), getPreferences: StubGetPreferences())
        await sut.onAppear()
        var departures = 0
        sut.onLeftAdventure = { departures += 1 }

        for tab in [RootTab.map, .timeline, .settings] {
            sut.selectedTab = .adventure
            sut.selectedTab = tab
        }
        sut.selectedTab = .timeline

        #expect(departures == 3)
    }

    @Test("Given Settings, when a link opens home, then nothing is told: the dad wasn't on Adventure")
    func comingBackToAdventureIsNotALeave() async {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: HeroStub.profile), getPreferences: StubGetPreferences())
        await sut.onAppear()
        sut.selectedTab = .settings
        var departures = 0
        sut.onLeftAdventure = { departures += 1 }

        sut.open(url: AppLink.child(HeroStub.niko.id).url)

        #expect(sut.selectedTab == .adventure)
        #expect(departures == 0)
    }

    @Test("Given editors holding changes, when the dad starts over, then nothing is held and Adventure is selected")
    func startOverEndsEveryHold() async {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: HeroStub.profile), getPreferences: StubGetPreferences())
        await sut.onAppear()
        sut.selectedTab = .settings
        sut.unsavedWork.set(UUID(), in: UnsavedScope.settings, hasUnsavedChanges: true)

        sut.startedOver()

        #expect(!sut.unsavedWork.isHeld)
        #expect(sut.selectedTab == .adventure)
        #expect(sut.state == .onboarding)
    }

    @Test("Given the map tab, when a world is chosen, then Adventure shows")
    func choosingAWorldShowsAdventure() async {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: HeroStub.profile), getPreferences: StubGetPreferences())
        await sut.onAppear()
        sut.selectedTab = .map

        sut.worldChosen()

        #expect(sut.selectedTab == .adventure)
    }

    @Test("Given the root in Greek, when naming the tabs, then they are the four single words")
    func fourTabs() {
        let sut = RootViewModel(
            getProfile: StubGetProfile(profile: HeroStub.profile), getPreferences: StubGetPreferences(),
            locale: Locale(identifier: "el_GR")
        )
        #expect(sut.tabs == RootTabs(adventure: "Περιπέτεια", map: "Χάρτης", timeline: "Χρονολόγιο", settings: "Ρυθμίσεις"))
    }

    @Test("Given a link while the app is still loading, when there turns out to be no family, then it is dropped")
    func dropsLinkForOnboarding() async {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: nil), getPreferences: StubGetPreferences())
        sut.open(url: AppLink.child(UUID()).url)
        #expect(sut.pendingLink != nil)

        await sut.onAppear()

        #expect(sut.pendingLink == nil)
        sut.open(url: AppLink.child(UUID()).url)
        #expect(sut.pendingLink == nil)
    }

    @Test("Given a URL that is not a DadSaga link, when opening it, then nothing happens")
    func ignoresOtherURLs() async throws {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: HeroStub.profile), getPreferences: StubGetPreferences())
        await sut.onAppear()
        sut.selectedTab = .timeline

        sut.open(url: try #require(URL(string: "https://example.com/quest/q1")))

        #expect(sut.pendingLink == nil)
        #expect(sut.selectedTab == .timeline)
    }
}

enum StubLinkError: Error { case notLoaded }
