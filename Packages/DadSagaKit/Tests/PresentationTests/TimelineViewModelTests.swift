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

    /// One log per test, shared by reading and deleting.
    let logs = TimelineLogs()

    func log(_ events: [ProgressEvent]) -> FakeTimelineLog {
        logs.log(for: events)
    }

    func makeSUT(profile: PlayerProfile?, events: [ProgressEvent]) -> TimelineViewModel {
        TimelineViewModel(
            getProfile: StubGetProfile(profile: profile),
            getTimeline: log(events),
            getPhoto: StubGetPhoto(),
            deleteEvent: log(events),
            updateJournal: log(events),
            locale: Locale(identifier: "el_GR"),
            calendar: calendar
        )
    }

    var familyEvents: [ProgressEvent] {
        [
            ProgressEvent(kind: .quest(id: "q1"), childID: HeroStub.niko.id, date: january),
            ProgressEvent(kind: .boss(id: "b1"), childID: HeroStub.niko.id, date: february.addingTimeInterval(-86_400)),
            ProgressEvent(kind: .first(id: "f1"), childID: HeroStub.eleni.id, date: february, note: "πρώτα", photoIDs: ["p1"])
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
        #expect(february.items.first?.photoIDs == ["p1"])
        #expect(february.items.first?.photoCount == "1 φωτογραφία")
        #expect(february.items.first?.subtitle.hasPrefix("Ελένη · ") == true)
        #expect(february.items.first?.subtitle.hasSuffix(" · πρώτα") == true)
        #expect(february.items.last?.subtitle.hasSuffix(" · β") == true)
        #expect(content.sections.last?.items.map(\.kind) == [.quest])
    }

    @Test("Given no entries, when the timeline opens, then there is no film to make")
    func noFilmForAnEmptyTimeline() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: [])
        await sut.onAppear()
        #expect(try #require(loadedContent(sut)).filmTitle == nil)
    }

    @Test("Given the timeline of everyone, when making a film, then it is the first child's; filtered, that child's")
    func filmOfTheFilteredChild() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await sut.onAppear()
        #expect(try #require(loadedContent(sut)).filmTitle == "Φτιάξε ταινία")
        #expect(sut.filmRequest == SagaFilmRequest())

        sut.select(filter: HeroStub.eleni.id)

        #expect(sut.filmRequest == SagaFilmRequest(childID: HeroStub.eleni.id))
        #expect(try #require(loadedContent(sut)).filmTitle == "Φτιάξε ταινία")
    }

    @Test("Given a child with no entry, when the timeline is filtered to them, then there is no film to make")
    func noFilmForAnEmptyFilter() async throws {
        let onlyNiko = familyEvents.filter { $0.childID == HeroStub.niko.id }
        let sut = makeSUT(profile: HeroStub.family, events: onlyNiko)
        await sut.onAppear()

        sut.select(filter: HeroStub.eleni.id)

        #expect(try #require(loadedContent(sut)).filmTitle == nil)
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

    @Test("Given a moment with a photo and a note, when asking to delete it, then the prompt warns they go too")
    func warnsAboutPhoto() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await sut.onAppear()
        let moment = try #require(loadedContent(sut)?.sections.first?.items.first)

        sut.requestDeletion(id: moment.id)

        let prompt = try #require(sut.deletion)
        #expect(prompt.title == "Διαγραφή από το χρονολόγιο;")
        #expect(prompt.message.hasPrefix("Οι φωτογραφίες και η σημείωσή σου θα σβηστούν μαζί του, χωρίς επιστροφή."))
        #expect(prompt.message.hasSuffix(" Θα αφαιρεθούν τα 30 XP."))
    }

    @Test("Given a quest with photos and a boss with a note, when asking to delete them, then both warn, in English too")
    func warnsAboutAnyJournal() async throws {
        let quest = ProgressEvent(kind: .quest(id: "q1"), childID: HeroStub.niko.id, date: january, photoIDs: ["a", "b"])
        let boss = ProgressEvent(kind: .boss(id: "b1"), childID: HeroStub.niko.id, date: january, note: "δύσκολη νύχτα")
        let sut = TimelineViewModel(
            getProfile: StubGetProfile(profile: HeroStub.profile),
            getTimeline: log([quest, boss]),
            getPhoto: StubGetPhoto(),
            deleteEvent: log([quest, boss]),
            updateJournal: log([quest, boss]),
            locale: Locale(identifier: "en_US"),
            calendar: calendar
        )
        await sut.onAppear()

        sut.requestDeletion(id: quest.id)
        #expect(sut.deletion?.message == "Your photos and note will be deleted with it, for good. Its 20 XP will be removed.")
        sut.requestDeletion(id: boss.id)
        #expect(
            sut.deletion?.message
                == "Your photos and note will be deleted with it, for good. The badge and its 100 XP will be removed."
        )
    }

    @Test("Given a quest entry, when deleting it and confirming, then it leaves the timeline")
    func deletes() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await sut.onAppear()
        let quest = try #require(loadedContent(sut)?.sections.last?.items.first)

        sut.requestDeletion(id: quest.id)
        #expect(sut.deletion?.message == "Θα αφαιρεθούν τα 20 XP.")
        let prompt = try #require(sut.deletion)
        sut.cancelDeletion() // what the dialog does to its binding before the button's action runs
        await sut.confirmDeletion(id: prompt.id)

        #expect(sut.deletion == nil)
        #expect(loadedContent(sut)?.sections.flatMap(\.items).map(\.kind) == [.moment, .boss])
    }

    @Test("Given a quest entry, when adding a note from the timeline, then the row shows it")
    func editsJournal() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await sut.onAppear()
        let quest = try #require(loadedContent(sut)?.sections.last?.items.first)

        sut.editJournal(id: quest.id)
        #expect(sut.journalEditor?.title == "Αποστολή")
        #expect(sut.journalEditor?.note == "")
        await sut.saveJournal(note: "γέλασε πολύ", photos: PhotoDrafts())

        #expect(sut.journalEditor == nil)
        #expect(loadedContent(sut)?.sections.last?.items.first?.subtitle.hasSuffix(" · γέλασε πολύ") == true)
    }

    @Test("Given an entry with two photos, when adding one and making it the cover, then it is saved first")
    func savesArrangedPhotos() async throws {
        let quest = ProgressEvent(kind: .quest(id: "q1"), childID: HeroStub.niko.id, date: january, photoIDs: ["a", "b"])
        let sut = makeSUT(profile: HeroStub.profile, events: [quest])
        await sut.onAppear()
        #expect(loadedContent(sut)?.sections.first?.items.first?.photoIDs == ["a", "b"])

        sut.editJournal(id: quest.id)
        var photos = PhotoDrafts(storedIDs: try #require(sut.journalEditor?.photoIDs))
        photos.append([Data([1])])
        photos.makeCover(id: try #require(photos.items.last?.id))
        photos.remove(id: "b")
        await sut.saveJournal(note: "", photos: photos)

        sut.editJournal(id: quest.id)
        #expect(sut.journalEditor?.photoIDs == ["new-photo-0", "a"])
        #expect(loadedContent(sut)?.sections.first?.items.first?.photoCount == "2 φωτογραφίες")
    }

    @Test("Given a boss entry with a note, when appearing, then the badge and the note are both in the subtitle")
    func bossNote() async throws {
        let events = [ProgressEvent(kind: .boss(id: "b1"), childID: HeroStub.niko.id, date: january, note: "δύσκολη νύχτα")]
        let sut = makeSUT(profile: HeroStub.profile, events: events)
        await sut.onAppear()

        #expect(loadedContent(sut)?.sections.first?.items.first?.subtitle.hasSuffix(" · β · δύσκολη νύχτα") == true)
    }

    @Test("Given a delete prompt, when cancelling, then nothing is deleted")
    func cancels() async throws {
        let sut = makeSUT(profile: HeroStub.family, events: familyEvents)
        await sut.onAppear()
        let quest = try #require(loadedContent(sut)?.sections.last?.items.first)

        sut.requestDeletion(id: quest.id)
        sut.cancelDeletion()
        await sut.onAppear()

        #expect(sut.deletion == nil)
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
        let root = RootViewModel(
            getProfile: StubGetProfile(profile: nil),
            getPreferences: StubGetPreferences(),
            locale: Locale(identifier: "el_GR")
        )
        #expect(root.tabs.adventure == "Περιπέτεια")
        #expect(root.tabs.timeline == "Χρονολόγιο")
    }
}

@MainActor
final class TimelineLogs {
    private var current: FakeTimelineLog?

    func log(for events: [ProgressEvent]) -> FakeTimelineLog {
        if let current { return current }
        let log = FakeTimelineLog(events: events)
        current = log
        return log
    }
}

actor FakeTimelineLog: GetTimelineUseCase, DeleteEventUseCase, UpdateJournalUseCase {
    private var events: [ProgressEvent]

    init(events: [ProgressEvent]) {
        self.events = events
    }

    func execute() async throws -> [TimelineEntry] {
        Timeline.entries(from: events, catalog: HeroStub.catalog)
    }

    func execute(eventID: UUID) async throws {
        events.removeAll { $0.id == eventID }
    }

    func execute(eventID: UUID, note: String?, photos: [EntryPhoto]) async throws {
        guard let index = events.firstIndex(where: { $0.id == eventID }) else { return }
        let old = events[index]
        let photoIDs = photos.enumerated().map { index, photo in
            switch photo {
            case .kept(let id): id
            case .added: "new-photo-\(index)"
            }
        }
        events[index] = ProgressEvent(
            id: old.id, kind: old.kind, childID: old.childID, date: old.date, note: note, photoIDs: photoIDs
        )
    }
}

struct StubGetTimeline: GetTimelineUseCase {
    let entries: [TimelineEntry]

    func execute() async throws -> [TimelineEntry] {
        entries
    }
}

struct StubGetPhoto: GetPhotoUseCase {
    func execute(id: String, maxPixelSize: Int) async -> Data? {
        nil
    }
}
