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

    @Test("Given an entry deleted, when loading the timeline again fails, then the entry is gone and the rest stays")
    func failedReloadAfterDeleting() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await sut.onAppear()
        let id = try #require(loadedContent(sut)?.sections.first?.items.first).id
        await log(familyEvents).failReadsFromNowOn()

        await sut.confirmDeletion(id: id)

        #expect(sut.errorMessage == nil)
        #expect(loadedContent(sut)?.sections.flatMap(\.items).map(\.kind) == [.boss, .quest])
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
