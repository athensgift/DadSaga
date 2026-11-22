import Domain
import Foundation
import Presentation
import Testing

/// The two Undo offers, on home's bar and in a new moment's sheet, and what ends them (ADR-0021, ADR-0055 §3).
@MainActor
@Suite("HomeViewModel, undo offers")
struct HomeUndoTests {
    let progress = FakeProgress()

    func makeSUT() async -> HomeViewModel {
        let sut = makeHomeViewModel(profile: HeroStub.profile, progress: progress)
        await sut.onAppear()
        return sut
    }

    /// A quest whose Undo is on the bar, then a first whose Undo is in its sheet, open over home.
    func questThenMoment(_ sut: HomeViewModel) async {
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        sut.startCapture()
        await sut.captureMoment(firstID: "f1", date: HeroStub.today)
    }

    @Test(
        "Given a quest's Undo on home and a moment's in its sheet, when both are undone, then nothing is left of either",
        arguments: [true, false]
    )
    func twoUndosInEitherOrder(sheetFirst: Bool) async throws {
        let sut = await makeSUT()
        await questThenMoment(sut)
        #expect(sut.titleCard != nil)

        // The sheet covers the bar, so on screen the sheet's Undo goes first; the other order gives the same.
        if sheetFirst {
            await sut.deleteMoment()
            await sut.undoLastRecord()
        } else {
            await sut.undoLastRecord()
            await sut.deleteMoment()
        }

        #expect(await progress.eventCount == 0)
        #expect(await progress.kept == .fresh)
        guard case .loaded(let content) = sut.state else { throw StubError.boom }
        #expect(content.dadTitle?.text == "Επίπεδο 0 · Σε αναμονή")
        #expect(content.heroGear.isEmpty)
        #expect(sut.titleCard == nil)
        #expect(sut.momentCapture == nil)
    }

    @Test("Given a quest's Undo on home, when its time runs out while a moment's Undo is saving, then only the moment goes")
    func offerExpiresWhileAnUndoSaves() async throws {
        let sut = await makeSUT()
        await questThenMoment(sut)
        let bar = try #require(sut.undoOffer)
        await progress.slowNext()
        let undoing = Task { await sut.deleteMoment() }
        while !sut.isCompleting { await Task.yield() }

        sut.undoOfferExpired(id: bar.id)
        await progress.finishSlowSave()
        await undoing.value

        #expect(await progress.eventCount == 1)
        #expect(sut.momentCapture == nil)
        #expect(sut.errorMessage == nil)
        #expect(sut.undoOffer == nil)
        guard case .loaded(let content) = sut.state else { throw StubError.boom }
        #expect(content.dadTitle?.text == "Επίπεδο 1 · Νέος στο ταξίδι")
    }

    @Test("Given a moment's Undo whose time ran out, when the quest before it is undone, then the moment and its title stay")
    func undoTheQuestKeepsALaterMoment() async throws {
        let sut = await makeSUT()
        await questThenMoment(sut)
        sut.momentUndoExpired(id: try #require(sut.momentCapture?.details?.undoOffer).id)
        sut.dismissSelection()

        await sut.undoLastRecord()

        #expect(await progress.eventCount == 1)
        guard case .loaded(let content) = sut.state else { throw StubError.boom }
        #expect(content.dadTitle?.text == "Επίπεδο 1 · Νέος στο ταξίδι")
        #expect(content.moments.cards.count == 1)
    }

    @Test("Given a quest's Undo on home, when the dad leaves for the timeline, then the offer is over when he is back")
    func leavingForTheTimelineEndsTheBar() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        #expect(sut.undoOffer != nil)

        sut.leftForAnotherTab()
        await sut.onAppear()

        #expect(sut.undoOffer == nil)
        await sut.undoLastRecord()
        #expect(await progress.eventCount == 1)
        // The celebration is not the Undo's: it stays.
        #expect(sut.celebration != nil)
    }

    @Test("Given a quest's Undo on home, when the dad deletes a moment he opened to edit, then the Undo is over")
    func deletingAMomentEndsTheBar() async throws {
        await progress.seedMoment(photos: [])
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        guard case .loaded(let before) = sut.state else { throw StubError.boom }
        sut.editMoment(id: try #require(before.moments.cards.first).id)
        #expect(sut.momentCapture?.details?.undoOffer == nil)

        await sut.deleteMoment()

        #expect(sut.undoOffer == nil)
        await sut.undoLastRecord()
        #expect(await progress.eventCount == 1)
        // The deletion kept the title he held, and nothing can lower it now.
        #expect(await progress.kept.titleID == "t1")
        guard case .loaded(let content) = sut.state else { throw StubError.boom }
        #expect(content.dadTitle?.text == "Επίπεδο 1 · Νέος στο ταξίδι")
    }

    @Test("Given a title card just closed, when a load from before its card finishes late, then the card stays closed")
    func staleLoadKeepsAClosedCardClosed() async throws {
        let sut = await makeSUT()
        // A slow load reads home while there is no entry yet.
        await progress.holdOverviews(afterReading: true)
        let slow = Task { await sut.reload() }
        await progress.waitUntilHeld(1)
        sut.select(cardID: "q1")
        let recording = Task { await sut.completeSelectedQuest() }
        await progress.waitUntilHeld(2)
        await progress.releaseNewestOverview()
        await recording.value
        #expect(sut.titleCard != nil)
        // The store can't save the close: only home remembers it, for this session.
        await progress.failMarkingSeen()
        await sut.closeTitleCard()

        await progress.releaseAllOverviews()
        await slow.value
        await sut.reload()

        #expect(sut.titleCard == nil)
    }
}
