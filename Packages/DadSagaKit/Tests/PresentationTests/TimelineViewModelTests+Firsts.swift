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
        #expect(details.earliestDate <= february)
        await sut.saveMoment(date: january.addingTimeInterval(3_600), note: "πρώτα", photos: PhotoDrafts(storedIDs: ["p1"]))

        #expect(sut.editor == nil)
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
}
