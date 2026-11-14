import Application
import Domain
import Foundation
import Presentation
import Testing

@MainActor
@Suite("TimelineViewModel")
struct TimelineViewModelTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// 12 January and 14–15 February 1970.
    let january = Date(timeIntervalSince1970: 1_000_000)
    var february: Date { january.addingTimeInterval(34 * 86_400) }

    func makeSUT(profile: PlayerProfile?, events: [ProgressEvent]) -> TimelineViewModel {
        TimelineViewModel(
            getProfile: StubGetProfile(profile: profile),
            getTimeline: StubGetTimeline(entries: Timeline.entries(from: events, catalog: HeroStub.catalog)),
            getPhoto: StubGetPhoto(),
            locale: Locale(identifier: "el_GR"),
            calendar: calendar
        )
    }

    var familyEvents: [ProgressEvent] {
        [
            ProgressEvent(kind: .quest(id: "q1"), childID: HeroStub.niko.id, date: january),
            ProgressEvent(kind: .boss(id: "b1"), childID: HeroStub.niko.id, date: february.addingTimeInterval(-86_400)),
            ProgressEvent(kind: .first(id: "f1"), childID: HeroStub.eleni.id, date: february, note: "πρώτα", photoID: "p1")
        ]
    }

    func loadedContent(_ sut: TimelineViewModel) -> TimelineContent? {
        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return nil
        }
        return content
    }

    @Test("Given two children's events, when appearing, then months are sections, newest first, with child names")
    func groupsByMonth() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await sut.onAppear()
        let content = try #require(loadedContent(sut))

        #expect(content.title == "Χρονολόγιο")
        #expect(content.filters.map(\.title) == ["Όλοι", "Νίκος", "Ελένη"])
        #expect(content.sections.map(\.title) == ["Φεβρουάριος 1970", "Ιανουάριος 1970"])
        let february = try #require(content.sections.first)
        #expect(february.items.map(\.title) == ["👣 Βήματα", "Αφεντικό"])
        #expect(february.items.map(\.kind) == [.moment, .boss])
        #expect(february.items.map(\.badge) == ["+30 XP", "+100 XP"])
        #expect(february.items.first?.photoID == "p1")
        #expect(february.items.first?.subtitle.hasPrefix("Ελένη · ") == true)
        #expect(february.items.first?.subtitle.hasSuffix(" · πρώτα") == true)
        #expect(february.items.last?.subtitle.hasSuffix(" · β") == true)
        #expect(content.sections.last?.items.map(\.kind) == [.quest])
    }

    @Test("Given two children, when filtering by one, then only their events show, without their name")
    func filters() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await sut.onAppear()

        sut.select(filter: HeroStub.eleni.id)

        let content = try #require(loadedContent(sut))
        #expect(content.selectedFilter == HeroStub.eleni.id)
        #expect(content.sections.flatMap(\.items).map(\.kind) == [.moment])
        #expect(content.sections.first?.items.first?.subtitle.hasPrefix("Ελένη") == false)

        sut.select(filter: nil)
        #expect(loadedContent(sut)?.sections.flatMap(\.items).count == 3)
    }

    @Test("Given one child, when appearing, then there are no filters and no child names")
    func oneChild() async throws {
        let events = [ProgressEvent(kind: .quest(id: "q1"), childID: HeroStub.niko.id, date: january)]
        let sut = makeSUT(profile: HeroStub.profile, events: events)
        await sut.onAppear()
        let content = try #require(loadedContent(sut))
        #expect(content.filters.isEmpty)
        #expect(content.sections.first?.items.first?.subtitle.hasPrefix("Νίκος") == false)
    }

    @Test("Given nothing done yet, when appearing, then there are no sections and the empty text is in Greek")
    func empty() async throws {
        let sut = makeSUT(profile: HeroStub.profile, events: [])
        await sut.onAppear()
        let content = try #require(loadedContent(sut))
        #expect(content.sections.isEmpty)
        #expect(content.emptyTitle == "Καμία ανάμνηση ακόμα")
    }

    @Test("Given the root presenter, when reading tab titles, then they are in the user's language")
    func tabTitles() {
        let root = RootViewModel(getProfile: StubGetProfile(profile: nil), locale: Locale(identifier: "el_GR"))
        #expect(root.tabs.adventure == "Περιπέτεια")
        #expect(root.tabs.timeline == "Χρονολόγιο")
    }
}

struct StubGetTimeline: GetTimelineUseCase {
    let entries: [TimelineEntry]

    func execute() async throws -> [TimelineEntry] {
        entries
    }
}

struct StubGetPhoto: GetPhotoUseCase {
    func execute(id: String) async -> Data? {
        nil
    }
}
