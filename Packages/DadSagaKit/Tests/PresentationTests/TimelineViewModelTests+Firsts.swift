import Foundation
import Presentation
import Testing

/// A first opens from the timeline in its own page, the same as home's step 2, with its date (ADR-0042 §5).
extension TimelineViewModelTests {
    /// The moment's own page, open on a first.
    func moment(_ sut: TimelineViewModel) -> MomentDetails? {
        if case .moment(let details) = sut.editor { details } else { nil }
    }

    @Test("Given a first, when opening it from the timeline, then its page has its date, and a changed date is saved")
    func editsFirstsDate() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await sut.onAppear()
        let first = try #require(loadedContent(sut)?.sections.first?.items.first)

        sut.edit(id: first.id)
        let details = try #require(moment(sut))
        #expect(details.date == february)
        #expect(details.note == "πρώτα")
        #expect(details.photoIDs == ["p1"])
        #expect(!details.isNew)
        #expect(details.latestDate == Date(timeIntervalSince1970: 10_000_000))
        // From the start of the child's birth day, 12 January 1970.
        #expect(details.earliestDate == Date(timeIntervalSince1970: 950_400))
        await sut.saveMoment(date: january.addingTimeInterval(3_600), note: "πρώτα", photos: PhotoDrafts(storedIDs: ["p1"]))

        #expect(sut.editor == nil)
        #expect(await log(familyEvents).lastMomentNow == Date(timeIntervalSince1970: 10_000_000))
        let oldest = try #require(loadedContent(sut)?.sections.last)
        #expect(oldest.items.map(\.kind) == [.moment, .quest])
    }

    @Test("Given a first opened from the timeline, when deleting it there, then it leaves the timeline")
    func deletesFirstFromItsPage() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await sut.onAppear()
        let first = try #require(loadedContent(sut)?.sections.first?.items.first)

        sut.edit(id: first.id)
        await sut.deleteMoment()

        #expect(sut.editor == nil)
        #expect(loadedContent(sut)?.sections.flatMap(\.items).map(\.kind) == [.boss, .quest])
    }

    @Test("Given a first's page, when saving or deleting fails, then the page stays open and says so")
    func keepsFirstsPageOnFailure() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await sut.onAppear()
        let first = try #require(loadedContent(sut)?.sections.first?.items.first)
        sut.edit(id: first.id)
        await log(familyEvents).failFromNowOn()

        await sut.saveMoment(date: january, note: "", photos: PhotoDrafts())
        #expect(moment(sut) != nil)
        #expect(!sut.isSaving)
        #expect(sut.errorMessage == "Δεν αποθηκεύτηκε. Δοκίμασε ξανά.")

        await sut.deleteMoment()
        #expect(moment(sut) != nil)
        #expect(sut.errorMessage == "Δεν διαγράφηκε. Δοκίμασε ξανά.")
        #expect(loadedContent(sut)?.sections.flatMap(\.items).count == 3)
    }

    @Test("Given a first's page open, when a link is about to open home, then it closes only if that loses nothing")
    func linkClosesOnlyAClearFirstsPage() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await sut.onAppear()
        sut.edit(id: try #require(loadedContent(sut)?.sections.first?.items.first).id)

        sut.linkWillOpen(editorHoldsChanges: true)
        #expect(moment(sut) != nil)

        sut.linkWillOpen(editorHoldsChanges: false)
        #expect(sut.editor == nil)
    }

    @Test("Given a first's page, when asking to delete it there, then the question is the timeline's own")
    func firstsPageAsksAsTheRowDoes() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await sut.onAppear()
        let first = try #require(loadedContent(sut)?.sections.first?.items.first)

        sut.edit(id: first.id)
        sut.requestDeletion(id: first.id)

        #expect(try #require(moment(sut)).labels.deletion == sut.deletion)
    }

    @Test("Given a failed deletion's alert, when a link is about to open home, then it closes")
    func linkClosesTheFailureAlert() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await sut.onAppear()
        let first = try #require(loadedContent(sut)?.sections.first?.items.first)
        await log(familyEvents).failFromNowOn()
        await sut.confirmDeletion(id: first.id)
        #expect(sut.errorMessage != nil)

        sut.linkWillOpen(editorHoldsChanges: false)

        #expect(sut.errorMessage == nil)
    }

    @Test("Given an editor that stays for its unsaved changes, when a link is about to open home, then its error stays too")
    func stayingEditorKeepsItsError() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await sut.onAppear()
        sut.edit(id: try #require(loadedContent(sut)?.sections.first?.items.first).id)
        await log(familyEvents).failFromNowOn()
        await sut.deleteMoment()

        sut.linkWillOpen(editorHoldsChanges: true)

        #expect(sut.errorMessage == "Δεν διαγράφηκε. Δοκίμασε ξανά.")
    }
}
