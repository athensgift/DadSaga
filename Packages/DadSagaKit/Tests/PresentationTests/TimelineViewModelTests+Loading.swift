import Foundation
import Presentation
import Testing

/// When the timeline can't be read.
extension TimelineViewModelTests {
    @Test("Given a loaded timeline, when loading it again fails, then it stays as it was")
    func failedReloadKeepsTheTimeline() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await sut.onAppear()
        await log(familyEvents).failReadsFromNowOn()

        await sut.onAppear()

        #expect(loadedContent(sut)?.sections.flatMap(\.items).count == 3)
    }

    @Test("Given an entry deleted or edited, when the timeline can't be read again, then it says so, not the old entry")
    func failedReloadAfterAChange() async throws {
        let failure = TimelineViewState.failed(LoadFailure(message: "Το χρονολόγιο δεν φόρτωσε.", retryTitle: "Δοκίμασε ξανά"))
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await sut.onAppear()
        let quest = try #require(loadedContent(sut)?.sections.last?.items.first)
        sut.edit(id: quest.id)
        await log(familyEvents).failReadsFromNowOn()

        await sut.saveJournal(note: "γέλασε πολύ", photos: PhotoDrafts())
        #expect(sut.editor == nil)
        #expect(sut.state == failure)

        await log(familyEvents).readAgain()
        await sut.retry()
        #expect(loadedContent(sut)?.sections.last?.items.first?.subtitle.hasSuffix(" · γέλασε πολύ") == true)

        await log(familyEvents).failReadsFromNowOn()
        await sut.confirmDeletion(id: quest.id)
        #expect(sut.errorMessage == nil)
        #expect(sut.state == failure)
    }

    @Test("Given the timeline never loaded, when trying again works, then it shows")
    func tryAgain() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await log(familyEvents).failReadsFromNowOn()
        await sut.onAppear()
        #expect(sut.state == .failed(LoadFailure(message: "Το χρονολόγιο δεν φόρτωσε.", retryTitle: "Δοκίμασε ξανά")))

        await log(familyEvents).readAgain()
        await sut.retry()

        #expect(loadedContent(sut)?.sections.flatMap(\.items).count == 3)
    }
}
