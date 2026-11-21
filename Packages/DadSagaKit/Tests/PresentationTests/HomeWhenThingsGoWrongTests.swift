import Application
import Domain
import Foundation
import Presentation
import Testing

/// Home when two things happen close together, or something fails: what the dad sees stays true.
@MainActor
@Suite("HomeViewModel, when things go wrong")
struct HomeWhenThingsGoWrongTests {
    let progress = FakeProgress()

    func makeSUT(profile: PlayerProfile = HeroStub.profile) async -> HomeViewModel {
        let sut = makeHomeViewModel(profile: profile, progress: progress)
        await sut.onAppear()
        return sut
    }

    @Test("Given two quests done within seconds, when the first celebration's time ends, then the second still shows")
    func secondCelebrationOutlivesTheFirst() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        let first = try #require(sut.celebration)
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        let second = try #require(sut.celebration)

        sut.celebrationFinished(id: first.id)
        #expect(sut.celebration == second)

        sut.celebrationFinished(id: second.id)
        #expect(sut.celebration == nil)
    }

    @Test("Given a quest just done, when undoing it fails, then the entry stays and the bar says so and offers undo again")
    func failedUndoSaysSoAndOffersItAgain() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        let offer = try #require(sut.undoOffer)
        await progress.failNext()

        await sut.undoLastRecord()

        #expect(await progress.eventCount == 1)
        let again = try #require(sut.undoOffer)
        #expect(again.id == offer.id)
        #expect(again.message == "Δεν αναιρέθηκε. Δοκίμασε ξανά.")
        #expect(again.didFail)
    }

    @Test("Given a quest saving slowly, when a widget link opens another child's quest meanwhile, then that sheet stays open")
    func linkDuringASaveKeepsItsSheet() async throws {
        let sut = await makeSUT(profile: HeroStub.family)
        sut.select(cardID: "q1")
        await progress.slowNext()

        let saving = Task { await sut.completeSelectedQuest() }
        try await Task.sleep(for: .milliseconds(50))
        await sut.open(.quest(id: "q1", childID: HeroStub.eleni.id))
        await saving.value

        #expect(sut.selectedChildID == HeroStub.eleni.id)
        #expect(sut.selectedQuest?.id == "q1")
        #expect(await progress.recordedChildIDs == [HeroStub.niko.id])
    }

    @Test("Given a quest saving slowly, when a link opens another sheet and the save then fails, then that sheet shows no error")
    func failedSaveStaysWithItsOwnSheet() async throws {
        let sut = await makeSUT(profile: HeroStub.family)
        sut.select(cardID: "q1")
        await progress.slowNext()
        await progress.failNext()

        let saving = Task { await sut.completeSelectedQuest() }
        try await Task.sleep(for: .milliseconds(50))
        await sut.open(.quest(id: "q1", childID: HeroStub.eleni.id))
        await saving.value

        #expect(sut.selectedQuest?.id == "q1")
        #expect(sut.errorMessage == nil)
    }

    @Test("Given home showing the saga, when reloading it fails, then home keeps what it showed")
    func failedReloadKeepsHome() async throws {
        let sut = await makeSUT()
        guard case .loaded(let before) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        await progress.failOverview()

        await sut.reload()

        #expect(sut.state == .loaded(before))
    }

    @Test("Given home never loaded, when loading fails, then it shows the error")
    func firstLoadFailureShowsTheError() async {
        await progress.failOverview()

        let sut = await makeSUT()

        #expect(sut.state == .failed(message: "Το περιεχόμενο δεν φόρτωσε."))
    }

    @Test("Given home loaded yesterday, when the dad comes back to the app, then home shows what is true now")
    func returningToTheAppReloads() async throws {
        let sut = await makeSUT()
        await progress.seed(times: 1)

        await sut.appBecameActive()

        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.xpLine == "20 / 100 XP")
    }
}
