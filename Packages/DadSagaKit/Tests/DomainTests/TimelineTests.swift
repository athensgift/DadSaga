import Domain
import Foundation
import Testing

@Suite("Timeline")
struct TimelineTests {
    let anna = UUID()
    let niko = UUID()

    func event(
        _ kind: ProgressEvent.Kind, child: UUID, at seconds: TimeInterval, note: String? = nil, photos: [String] = []
    ) -> ProgressEvent {
        ProgressEvent(kind: kind, childID: child, date: Date(timeIntervalSince1970: seconds), note: note, photoIDs: photos)
    }

    @Test("Given quests, bosses and firsts, when building, then they come newest first with their details")
    func newestFirst() {
        let events = [
            event(.quest(id: "q1"), child: anna, at: 1),
            event(.first(id: "f1"), child: niko, at: 3, note: "χαμόγελο", photos: ["p1", "p2"]),
            event(.boss(id: "b1"), child: anna, at: 2)
        ]

        let entries = Timeline.entries(from: events, catalog: Fixtures.catalog)

        #expect(entries.map(\.id) == [events[1].id, events[2].id, events[0].id])
        #expect(entries.map(\.xp) == [30, 100, 20])
        #expect(entries.first?.childID == niko)
        #expect(entries.first?.note == "χαμόγελο")
        #expect(entries.first?.photoIDs == ["p1", "p2"])
        #expect(entries.first?.coverPhotoID == "p1")
    }

    @Test("Given a boss twice for one child and once for another, when building, then it shows once per child")
    func bossOncePerChild() {
        let events = [
            event(.boss(id: "b1"), child: anna, at: 1),
            event(.boss(id: "b1"), child: anna, at: 2),
            event(.boss(id: "b1"), child: niko, at: 3)
        ]
        let entries = Timeline.entries(from: events, catalog: Fixtures.catalog)
        #expect(entries.map(\.childID) == [niko, anna])
        #expect(entries.last?.date == Date(timeIntervalSince1970: 1))
    }

    @Test("Given a boss and a first with the same id for one child, when building, then both count")
    func onceIsPerKind() {
        let text = LocalizedText(el: "x", en: "x")
        let catalog = ContentCatalog(
            worlds: Fixtures.catalog.worlds,
            quests: [],
            bosses: [BossFight(id: "same", worldID: "w1", title: text, intro: text, guide: [], badge: text,
                               skill: .care, xp: 100, minAgeMonths: 0)],
            firsts: [FirstMoment(id: "same", order: 1, emoji: "😊", title: text, xp: 30, companionTrait: "smile")]
        )
        let events = [event(.boss(id: "same"), child: anna, at: 1), event(.first(id: "same"), child: anna, at: 2)]

        let entries = Timeline.entries(from: events, catalog: catalog)

        #expect(entries.map(\.xp) == [30, 100])
        #expect(DadProgress(events: events, catalog: catalog).totalXP == 130)
    }

    @Test("Given an event for content that no longer exists, when building, then it is skipped")
    func unknownContent() {
        let entries = Timeline.entries(from: [event(.quest(id: "gone"), child: anna, at: 1)], catalog: Fixtures.catalog)
        #expect(entries.isEmpty)
    }
}
