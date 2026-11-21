import Domain
import Foundation
import Testing

@Suite("SagaStoryboard")
struct SagaStoryboardTests {
    let saga = SagaFixtures()

    @Test("Given entries in two worlds, when making the film, then scenes run oldest first with a chapter per world")
    func oldestFirstWithChapters() throws {
        let questPhoto = saga.event(.quest(id: "q1"), months: 2, photos: "p1")
        let first = saga.event(.first(id: "f1"), months: 5)
        let boss = saga.event(.boss(id: "b1"), months: 10)
        let events = [boss, first, saga.event(.quest(id: "q1"), months: 3), questPhoto]

        let storyboard = try #require(saga.storyboard(events))

        #expect(storyboard.scenes.map(\.kind) == [
            .opening,
            .chapter(saga.catalog.worlds[0], number: 1),
            .entry(try entry(for: questPhoto, in: storyboard)),
            .entry(try entry(for: first, in: storyboard)),
            .chapter(saga.catalog.worlds[1], number: 2),
            .entry(try entry(for: boss, in: storyboard)),
            .credits(SagaCredits(questsDone: 2, bossesBeaten: 1))
        ])
        #expect(storyboard.scenes.map(\.seconds) == [3.5, 2.5, 2.5, 3, 2.5, 3.5, 6])
    }

    @Test("Given entries of another child, for removed content and outside the year, when making it, then they are left out")
    func onlyThisChildAndPeriod() throws {
        let kept = saga.event(.first(id: "f1"), months: 11, photos: "p")
        let events = [
            kept,
            saga.event(.first(id: "f2"), months: 4, child: saga.sibling),
            saga.event(.first(id: "gone"), months: 4),
            saga.event(.first(id: "f3"), months: 12),
            saga.event(.first(id: "f1"), months: 11, days: 3)
        ]

        let storyboard = try #require(saga.storyboard(events, period: .year(1)))

        #expect(storyboard.scenes.compactMap(Self.entryID) == [kept.id])
        #expect(storyboard.scenes.first { if case .entry = $0.kind { true } else { false } }?.seconds == 4.5)
    }

    @Test("Given 200 quest photos, when making the film, then it fits in 90 seconds and keeps the first and last")
    func questPhotosThinned() throws {
        let events = (0..<200).map { saga.event(.quest(id: "q1"), months: 0, days: $0, photos: "p\($0)") }

        let storyboard = try #require(saga.storyboard(events))
        let shown = storyboard.scenes.compactMap(Self.entryID)

        #expect(storyboard.seconds <= 90)
        #expect(shown.count > 1)
        #expect(shown.first == events.first?.id)
        #expect(shown.last == events.last?.id)
        #expect(storyboard.scenes.last?.kind == .credits(SagaCredits(questsDone: 200, bossesBeaten: 0)))
    }

    @Test("Given too many bosses without a photo, when making the film, then quest photos go first, then some bosses")
    func quietBossesThinnedAfterQuestPhotos() throws {
        let bosses = (1...30).map { saga.event(.boss(id: "b\($0)"), months: 1, days: $0) }
        let photoBoss = saga.event(.boss(id: "b40"), months: 3, photos: "p")
        let quest = saga.event(.quest(id: "q1"), months: 2, photos: "q")

        let storyboard = try #require(saga.storyboard(bosses + [photoBoss, quest]))
        let shown = storyboard.scenes.compactMap(Self.entryID)

        #expect(storyboard.seconds <= 90)
        #expect(!shown.contains(quest.id))
        #expect(shown.contains(photoBoss.id))
        #expect(shown.contains(try #require(bosses.first).id))
        #expect(shown.count < 31)
    }

    @Test("Given 24 firsts with photos, when making the film, then every one is kept, each at least 3 seconds")
    func everyFirstKept() throws {
        let firsts = (1...24).map { saga.event(.first(id: "f\($0)"), months: 0, days: $0 * 7, photos: "p\($0)") }
        let quest = saga.event(.quest(id: "q1"), months: 1, photos: "q")

        let storyboard = try #require(saga.storyboard(firsts + [quest]))
        let firstScenes = storyboard.scenes.filter { Self.entryID($0).map(Set(firsts.map(\.id)).contains) ?? false }

        #expect(firstScenes.count == 24)
        #expect(firstScenes.allSatisfy { $0.seconds >= 3 })
        #expect(storyboard.seconds <= 90)
        #expect(!storyboard.scenes.compactMap(Self.entryID).contains(quest.id))
    }

    @Test("Given more firsts than fit at 3 seconds, when making the film, then all stay at 3 seconds and it runs longer")
    func firstsNeverDropped() throws {
        let firsts = (1...30).map { saga.event(.first(id: "f\($0)"), months: 0, days: $0 * 7) }

        let storyboard = try #require(saga.storyboard(firsts))

        #expect(storyboard.scenes.compactMap(Self.entryID).count == 30)
        #expect(storyboard.seconds > 90)
    }

    @Test("Given many bosses with photos, when making the film, then some go before any first gets shorter")
    func photoBossesThinnedBeforeFirsts() throws {
        let bosses = (1...30).map { saga.event(.boss(id: "b\($0)"), months: 1, days: $0, photos: "b\($0)") }
        let first = saga.event(.first(id: "f1"), months: 3, photos: "f")

        let storyboard = try #require(saga.storyboard(bosses + [first]))
        let shown = storyboard.scenes.compactMap(Self.entryID)

        #expect(storyboard.seconds <= 90)
        #expect(shown.contains(first.id))
        #expect(storyboard.scenes.first { Self.entryID($0) == first.id }?.seconds == 4.5)
        #expect(shown.first == bosses.first?.id)
        #expect(shown.count < 31)
    }

    @Test("Given 100 quest photos, when they are thinned, then the ones kept are spread evenly")
    func thinnedEvenly() throws {
        let events = (0..<100).map { saga.event(.quest(id: "q1"), months: 0, days: $0, photos: "p\($0)") }
        let index = Dictionary(uniqueKeysWithValues: events.enumerated().map { ($1.id, $0) })

        let storyboard = try #require(saga.storyboard(events))
        let kept = storyboard.scenes.compactMap(Self.entryID).compactMap { index[$0] }
        let gaps = zip(kept.dropFirst(), kept).map { $0 - $1 }

        #expect(kept.count < 100)
        #expect((gaps.max() ?? 0) - (gaps.min() ?? 0) <= 1)
    }

    @Test("Given firsts with and without photos that don't fit, when making the film, then the time left is shared")
    func firstsShareTheTimeLeft() throws {
        let withPhoto = (1...14).map { saga.event(.first(id: "f\($0)"), months: 0, days: $0, photos: "p\($0)") }
        let without = (15...20).map { saga.event(.first(id: "f\($0)"), months: 0, days: $0) }

        let storyboard = try #require(saga.storyboard(withPhoto + without))
        let photoIDs = Set(withPhoto.map(\.id))
        let seconds = { (photo: Bool) in
            storyboard.scenes.filter { Self.entryID($0).map { photoIDs.contains($0) == photo } ?? false }.map(\.seconds)
        }

        #expect(seconds(false).allSatisfy { $0 == 3 })
        #expect(seconds(true).allSatisfy { $0 > 3 && $0 < 4.5 })
        #expect(abs(storyboard.seconds - 90) < 0.001)
    }

    @Test("Given 5,000 quest photos and 30 firsts, when making the film, then it is made in well under a second")
    func manyEntriesAreFast() throws {
        let quests = (0..<5_000).map { saga.event(.quest(id: "q1"), months: 0, days: $0 / 3, photos: "p\($0)") }
        let firsts = (1...30).map { saga.event(.first(id: "f\($0)"), months: 2, days: $0) }

        let clock = ContinuousClock()
        let elapsed = try clock.measure { _ = try #require(saga.storyboard(quests + firsts)) }

        #expect(elapsed < .seconds(1))
    }

    @Test("Given a film of one world, when making it, then it has no chapter card")
    func oneWorldNoChapter() throws {
        let storyboard = try #require(saga.storyboard([saga.event(.first(id: "f1"), months: 2)], period: .world(id: "w1")))
        #expect(!storyboard.scenes.contains { if case .chapter = $0.kind { true } else { false } })
    }

    @Test("Given the first year and everything, when making the films, then each tells the saga as of its end or now")
    func asOf() throws {
        #expect(try #require(saga.storyboard([], period: .year(1))).asOf == saga.date(months: 12))
        #expect(try #require(saga.storyboard([])).asOf == saga.date(months: 80))
        #expect(try #require(saga.storyboard([], period: .year(2))).period == .year(2))
    }

    @Test("Given the first year's film, born at midnight or in the afternoon, when drawn, then the child is 11 months")
    func childAgeAtTheLastMomentOfTheYear() throws {
        for hour in [0, 15] {
            let born = SagaFixtures(birth: DateComponents(year: 2024, month: 1, day: 15, hour: hour))
            let storyboard = try #require(SagaStoryboard.make(
                events: [], child: born.child, period: .year(1), catalog: born.catalog, now: born.date(months: 30),
                timeZone: born.timeZone
            ))
            #expect(storyboard.childAgeInMonths == 11)
        }
    }

    @Test("Given a year still going, when making its film, then the child is drawn at their age today")
    func childAgeToday() throws {
        let storyboard = try #require(SagaStoryboard.make(
            events: [], child: saga.child, period: .year(3), catalog: saga.catalog, now: saga.date(months: 26, days: 2),
            timeZone: saga.timeZone
        ))
        #expect(storyboard.childAgeInMonths == 26)
    }

    @Test("Given a finished year, when making its film, then it spans from the birthday to the last moment of the year")
    func spanOfAFinishedYear() throws {
        let storyboard = try #require(saga.storyboard([saga.event(.first(id: "f1"), months: 14)], period: .year(2)))
        #expect(storyboard.span == DateInterval(start: saga.date(months: 12), end: saga.date(months: 24) - 1))
    }

    @Test("Given a year still going, when making its film, then it spans up to now, never later")
    func spanOfTheCurrentYear() throws {
        let now = saga.date(months: 26, days: 2)
        let storyboard = try #require(SagaStoryboard.make(
            events: [], child: saga.child, period: .year(3), catalog: saga.catalog, now: now, timeZone: saga.timeZone
        ))
        #expect(storyboard.span == DateInterval(start: saga.date(months: 24), end: now))
    }

    @Test("Given a world left behind, when making its film, then it ends at the last moment of the world")
    func spanOfAWorldLeftBehind() throws {
        let storyboard = try #require(saga.storyboard([], period: .world(id: "w1")))
        #expect(storyboard.span.start == saga.date(months: 0))
        #expect(storyboard.span.end == storyboard.asOf - 1)
        #expect(storyboard.asOf < saga.date(months: 80))
    }

    @Test("Given the last world, which never ends, when making its film, then it runs from its first day to now")
    func spanOfTheLastWorld() throws {
        let open = SagaFixtures(worlds: [
            World(id: "w1", order: 1, title: Fixtures.text, tagline: Fixtures.text, minAgeMonths: 0, maxAgeMonths: 41),
            World(id: "w2", order: 2, title: Fixtures.text, tagline: Fixtures.text, minAgeMonths: 42, maxAgeMonths: nil)
        ])
        let storyboard = try #require(open.storyboard([], period: .world(id: "w2")))
        #expect(storyboard.span == DateInterval(start: open.date(months: 42), end: open.date(months: 80)))
    }

    @Test("Given the whole saga, when making its film, then it starts on the birth day and runs to now")
    func spanOfEverything() throws {
        let storyboard = try #require(saga.storyboard([saga.event(.first(id: "f1"), months: 3)]))
        #expect(storyboard.span == DateInterval(start: saga.date(months: 0), end: saga.date(months: 80)))
    }

    @Test("Given an entry dated before the birth day, when making the whole saga, then the film starts on that day")
    func spanOfEverythingWithAnEarlierEntry() throws {
        let early = saga.event(.first(id: "f1"), months: -1, days: 0)
        let storyboard = try #require(saga.storyboard([early]))
        #expect(storyboard.span.start == saga.date(months: -1))
    }

    @Test("Given no entries, when making the film, then it is the opening and the credits")
    func empty() throws {
        let storyboard = try #require(saga.storyboard([], period: .year(1)))
        #expect(storyboard.scenes.map(\.kind) == [.opening, .credits(SagaCredits(questsDone: 0, bossesBeaten: 0))])
    }

    @Test("Given a period that hasn't started, when making the film, then there is none")
    func notStarted() {
        #expect(saga.storyboard([], period: .year(9)) == nil)
    }

    @Test("Given a first with five photos, when making the film, then its card is followed by three more, in order")
    func furtherPhotosFollowTheEntry() throws {
        let first = saga.event(.first(id: "f1"), months: 2, photos: "p1", "p2", "p3", "p4", "p5")
        let quest = saga.event(.quest(id: "q1"), months: 3, photos: "q1", "q2")

        let storyboard = try #require(saga.storyboard([first, quest]))
        let firstEntry = try entry(for: first, in: storyboard)
        let questEntry = try entry(for: quest, in: storyboard)

        #expect(storyboard.scenes.map(\.kind) == [
            .opening,
            .entry(firstEntry),
            .photo(firstEntry, id: "p2"),
            .photo(firstEntry, id: "p3"),
            .photo(firstEntry, id: "p4"),
            .entry(questEntry),
            .photo(questEntry, id: "q2"),
            .credits(SagaCredits(questsDone: 1, bossesBeaten: 0))
        ])
        #expect(storyboard.scenes.map(\.seconds) == [3.5, 4.5, 2.5, 2.5, 2.5, 2.5, 2.5, 6])
    }

    private func entry(for event: ProgressEvent, in storyboard: SagaStoryboard) throws -> TimelineEntry {
        try #require(storyboard.scenes.lazy.compactMap { scene -> TimelineEntry? in
            if case .entry(let entry) = scene.kind, entry.id == event.id { entry } else { nil }
        }.first)
    }

    private static func entryID(_ scene: SagaScene) -> UUID? {
        if case .entry(let entry) = scene.kind { entry.id } else { nil }
    }
}
