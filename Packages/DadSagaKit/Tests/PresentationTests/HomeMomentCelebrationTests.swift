import Application
import Domain
import Foundation
import Presentation
import Testing

/// A new first's celebration waits for its sheet to close, and plays on home (ADR-0042 §5).
@MainActor
@Suite("HomeViewModel, a new first's celebration")
struct HomeMomentCelebrationTests {
    let progress = FakeProgress()

    func makeSUT() async -> HomeViewModel {
        let sut = makeHomeViewModel(profile: HeroStub.profile, progress: progress)
        await sut.onAppear()
        return sut
    }

    @Test("Given step 1, when it records a first, then undo is in the sheet and the celebration waits for it to close")
    func celebratesOnceTheSheetCloses() async throws {
        let sut = await makeSUT()
        sut.startCapture()

        await sut.captureMoment(firstID: "f1", date: HeroStub.today)

        let details = try #require(sut.momentCapture?.details)
        #expect(details.undoOffer != nil)
        #expect(sut.celebration == nil)
        #expect(sut.undoOffer == nil)

        sut.dismissSelection()
        #expect(sut.celebration == nil)
        sut.sheetDismissed()

        let celebration = try #require(sut.celebration)
        #expect(celebration.momentText == "👣 Βήματα")
        #expect(celebration.skillText == nil)
        #expect(celebration.highlight == .moment)
        #expect(celebration.id == details.undoOffer?.id)
        sut.sheetDismissed()
        sut.celebrationFinished(id: celebration.id)
        #expect(sut.celebration == nil)
        // A first grows no skill, so no mark bounces (ADR-0059 §2).
        #expect(sut.skillBounces.isEmpty)
    }

    @Test("Given a moment's celebration waiting, when another sheet is open as the moment's closes, then it keeps waiting")
    func waitsWhileAnotherSheetIsOpen() async throws {
        let sut = await makeSUT()
        sut.startCapture()
        await sut.captureMoment(firstID: "f1", date: HeroStub.today)
        sut.dismissSelection()

        // A link opened a quest in the moment's place before its sheet had finished closing.
        sut.select(cardID: "q1")
        sut.sheetDismissed()
        #expect(sut.celebration == nil)

        sut.dismissSelection()
        sut.sheetDismissed()
        #expect(sut.celebration?.highlight == .moment)
    }

    @Test("Given a moment's celebration waiting, when a quest is done meanwhile, then the quest's celebration stays")
    func questCelebrationIsNotReplaced() async throws {
        let sut = await makeSUT()
        sut.startCapture()
        await sut.captureMoment(firstID: "f1", date: HeroStub.today)
        sut.dismissSelection()
        sut.select(cardID: "q1")

        await sut.completeSelectedQuest()
        sut.sheetDismissed()

        #expect(sut.celebration?.highlight == .quest)
    }

    @Test("Given step 2, when saving it, then home celebrates once the sheet has closed")
    func celebratesAfterSaving() async throws {
        let sut = await makeSUT()
        sut.startCapture()
        await sut.captureMoment(firstID: "f1", date: HeroStub.today)

        await sut.saveMomentDetails(date: HeroStub.today, note: "!", photos: PhotoDrafts())
        sut.sheetDismissed()

        #expect(sut.celebration?.momentText == "👣 Βήματα")
    }

    @Test("Given step 2 of a new moment, when undoing it, then nothing celebrates when the sheet closes")
    func undoneMomentDoesNotCelebrate() async throws {
        let sut = await makeSUT()
        sut.startCapture()
        await sut.captureMoment(firstID: "f1", date: HeroStub.today)

        await sut.deleteMoment()
        sut.sheetDismissed()

        #expect(sut.celebration == nil)
    }
}
