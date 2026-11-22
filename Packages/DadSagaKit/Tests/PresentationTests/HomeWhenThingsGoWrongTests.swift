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

    @Test("Given a link to another child's quest, when a second load overlaps it and ends last, then the quest still opens")
    func linkSurvivesAnOverlappingLoad() async throws {
        let sut = await makeSUT(profile: HeroStub.family)
        await progress.holdOverviews()

        let opening = Task { await sut.open(.quest(id: "q1", childID: HeroStub.eleni.id)) }
        await progress.waitUntilHeld(1)
        let reloading = Task { await sut.reload() }
        await progress.waitUntilHeld(2)
        await progress.releaseOldestOverview()
        await opening.value
        await progress.releaseAllOverviews()
        await reloading.value

        #expect(sut.selectedChildID == HeroStub.eleni.id)
        #expect(sut.selectedQuest?.id == "q1")
    }

    @Test("Given home still loading, when the dad comes back to the app, then no second load starts")
    func returningDuringALoadStartsNoOther() async throws {
        let sut = await makeSUT()
        await progress.holdOverviews()
        let reloading = Task { await sut.reload() }
        await progress.waitUntilHeld(1)

        await sut.appBecameActive()

        #expect(await progress.heldOverviewCount == 1)
        await progress.releaseAllOverviews()
        await reloading.value
    }

    @Test("Given a quest sheet opened after recording another, when undoing fails, then the sheet shows no error and stays")
    func failedUndoLeavesAnOpenSheetAlone() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        sut.select(cardID: "q1")
        await progress.failNext()

        await sut.undoLastRecord()

        #expect(sut.selectedQuest?.id == "q1")
        #expect(sut.errorMessage == nil)
        #expect(sut.undoOffer?.didFail == true)
    }

    @Test("Given a moment sheet opened after recording a quest, when undoing works, then the moment sheet stays open")
    func undoKeepsAnOpenMomentSheet() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        sut.startCapture()
        let capture = try #require(sut.momentCapture?.id)

        await sut.undoLastRecord()

        #expect(sut.momentCapture?.id == capture)
        #expect(await progress.eventCount == 0)
    }

    @Test("Given a quest whose save failed, when the dad tries again, then the old error goes while it saves")
    func retryClearsTheError() async throws {
        let sut = await makeSUT()
        await progress.failNext()
        sut.select(cardID: "q1")
        await progress.slowNext()
        let failing = Task { await sut.completeSelectedQuest() }
        while !sut.isCompleting { await Task.yield() }
        await progress.finishSlowSave()
        await failing.value
        #expect(sut.errorMessage != nil)

        await progress.slowNext()
        let retrying = Task { await sut.completeSelectedQuest() }
        while !sut.isCompleting { await Task.yield() }

        #expect(sut.errorMessage == nil)
        await progress.finishSlowSave()
        await retrying.value
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
        #expect(content.dadTitle == "Νέος στο ταξίδι")
    }
}
