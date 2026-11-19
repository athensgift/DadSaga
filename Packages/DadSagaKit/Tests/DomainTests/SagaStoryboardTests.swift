import Domain
import Foundation
import Testing

@Suite("SagaStoryboard")
struct SagaStoryboardTests {
    let saga = SagaFixtures()

    @Test("Given entries in two worlds, when making the film, then scenes run oldest first with a chapter per world")
    func oldestFirstWithChapters() throws {
        let questPhoto = saga.event(.quest(id: "q1"), months: 2, photo: "p1")
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
        let kept = saga.event(.first(id: "f1"), months: 11, photo: "p")
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
        let events = (0..<200).map { saga.event(.quest(id: "q1"), months: 0, days: $0, photo: "p\($0)") }

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
        let photoBoss = saga.event(.boss(id: "b40"), months: 3, photo: "p")
        let quest = saga.event(.quest(id: "q1"), months: 2, photo: "q")

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
        let firsts = (1...24).map { saga.event(.first(id: "f\($0)"), months: 0, days: $0 * 7, photo: "p\($0)") }
        let quest = saga.event(.quest(id: "q1"), months: 1, photo: "q")

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
        let bosses = (1...30).map { saga.event(.boss(id: "b\($0)"), months: 1, days: $0, photo: "b\($0)") }
        let first = saga.event(.first(id: "f1"), months: 3, photo: "f")

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
        let events = (0..<100).map { saga.event(.quest(id: "q1"), months: 0, days: $0, photo: "p\($0)") }
        let index = Dictionary(uniqueKeysWithValues: events.enumerated().map { ($1.id, $0) })

        let storyboard = try #require(saga.storyboard(events))
        let kept = storyboard.scenes.compactMap(Self.entryID).compactMap { index[$0] }
        let gaps = zip(kept.dropFirst(), kept).map { $0 - $1 }

        #expect(kept.count < 100)
        #expect((gaps.max() ?? 0) - (gaps.min() ?? 0) <= 1)
    }

    @Test("Given firsts with and without photos that don't fit, when making the film, then the time left is shared")
    func firstsShareTheTimeLeft() throws {
        let withPhoto = (1...14).map { saga.event(.first(id: "f\($0)"), months: 0, days: $0, photo: "p\($0)") }
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
        let quests = (0..<5_000).map { saga.event(.quest(id: "q1"), months: 0, days: $0 / 3, photo: "p\($0)") }
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

    @Test("Given no entries, when making the film, then it is the opening and the credits")
    func empty() throws {
        let storyboard = try #require(saga.storyboard([], period: .year(1)))
        #expect(storyboard.scenes.map(\.kind) == [.opening, .credits(SagaCredits(questsDone: 0, bossesBeaten: 0))])
    }

    @Test("Given a period that hasn't started, when making the film, then there is none")
    func notStarted() {
        #expect(saga.storyboard([], period: .year(9)) == nil)
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
