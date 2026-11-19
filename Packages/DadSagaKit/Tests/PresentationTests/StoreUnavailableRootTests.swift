import Application
import Domain
import Foundation
import Presentation
import Testing

/// Reads the profile, failing until told otherwise, like a store that cannot be opened yet.
actor FlakyGetProfile: GetProfileUseCase {
    struct Failure: Error {}
    private var fails = true

    func recover() { fails = false }

    func execute() async throws -> PlayerProfile? {
        if fails { throw Failure() }
        return HeroStub.profile
    }
}

@MainActor
@Suite("Root when the saga cannot be read")
struct StoreUnavailableRootTests {
    let profiles = FlakyGetProfile()

    @Test("Given the saga cannot be read, when the app starts, then it shows the can't-open screen and not onboarding")
    func showsUnavailable() async {
        let sut = RootViewModel(getProfile: profiles, getPreferences: StubGetPreferences())

        await sut.onAppear()

        #expect(sut.state == .unavailable)
    }

    @Test("Given the can't-open screen, when trying again works, then home opens; while it fails, the screen stays")
    func retry() async {
        let sut = RootViewModel(getProfile: profiles, getPreferences: StubGetPreferences())
        await sut.onAppear()

        await sut.retry()
        #expect(sut.state == .unavailable)

        await profiles.recover()
        await sut.retry()
        #expect(sut.state == .home)
    }

    @Test("Given a widget link while the saga cannot be read, when trying again opens home, then the link still waits")
    func linkWaits() async throws {
        let sut = RootViewModel(getProfile: profiles, getPreferences: StubGetPreferences())
        await sut.onAppear()
        let link = AppLink.quest(id: "q1", childID: HeroStub.niko.id)

        sut.open(url: link.url)
        await profiles.recover()
        await sut.retry()

        #expect(sut.pendingLink == PendingLink(link))
    }

    @Test("Given the can't-open screen, then it reads in Greek and in English, and says nothing was changed")
    func copy() {
        let greek = RootViewModel(
            getProfile: profiles, getPreferences: StubGetPreferences(), locale: Locale(identifier: "el_GR")
        ).unavailable
        let english = RootViewModel(
            getProfile: profiles, getPreferences: StubGetPreferences(), locale: Locale(identifier: "en_US")
        ).unavailable

        #expect(greek.title == "Δεν μπορέσαμε να ανοίξουμε την ιστορία σου")
        #expect(greek.retryTitle == "Δοκίμασε ξανά")
        #expect(greek.message.contains("δεν αλλάξαμε τίποτα"))
        #expect(english.title == "We couldn't open your saga")
        #expect(english.retryTitle == "Try again")
        #expect(english.message.contains("nothing was changed"))
    }
}
