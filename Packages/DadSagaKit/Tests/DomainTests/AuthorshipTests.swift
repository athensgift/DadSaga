import Domain
import Foundation
import Testing

/// Two parents, one family (ADR-0065 §3): a parent's standing comes only from their own entries, the family's story
/// from everyone's. A partner's entry never adds to the dad's standing or takes from it (ADR-0006).
@Suite("Authorship")
struct AuthorshipTests {
    let anna = UUID()
    let niko = UUID()
    let catalog = Fixtures.catalog

    func mine(_ kind: ProgressEvent.Kind, child: UUID, at seconds: TimeInterval) -> ProgressEvent {
        ProgressEvent(kind: kind, childID: child, date: Date(timeIntervalSince1970: seconds))
    }

    func partners(_ kind: ProgressEvent.Kind, child: UUID, at seconds: TimeInterval) -> ProgressEvent {
        ProgressEvent(authorID: UUID.partner, kind: kind, childID: child, date: Date(timeIntervalSince1970: seconds))
    }

    @Test("Given my entries and a partner's quests, bosses and firsts, when counting mine, then they are as mine alone")
    func partnersEntriesChangeNothingOfMine() throws {
        let mine = [mine(.quest(id: "q1"), child: anna, at: 1), mine(.boss(id: "b1"), child: anna, at: 2)]
        let theirs = [
            partners(.quest(id: "q2"), child: anna, at: 3),
            partners(.quest(id: "q1"), child: niko, at: 4),
            partners(.boss(id: "b1"), child: niko, at: 5),
            partners(.first(id: "f1"), child: anna, at: 6)
        ]

        let alone = DadProgress(events: mine, catalog: catalog)
        let together = DadProgress(events: mine + theirs, catalog: catalog)

        #expect(together == alone)
        #expect(together.totalXP == 120)
        #expect(together.cardsDone == 2)
        #expect(SkillGrowth.all(together, catalog: catalog) == SkillGrowth.all(alone, catalog: catalog))
        #expect(together.defeatedBossIDs(for: niko).isEmpty)
        #expect(together.questCompletions(for: niko).isEmpty)
        let world = try #require(catalog.world(id: "w1"))
        #expect(together.progress(in: world, catalog: catalog, childID: niko) == WorldProgress(questsDone: 0, bossesDone: 0))
    }

    @Test("Given only a partner's entries, when reading my title, then I hold the first and have nothing counted")
    func onlyPartnersEntries() {
        let theirs = (0..<5).map { partners(.quest(id: "q"), child: anna, at: TimeInterval($0)) }
            + [partners(.boss(id: "b"), child: anna, at: 9)]

        let progress = DadProgress(events: theirs, catalog: TitleTests.catalog)
        let standing = DadStanding(progress: progress, catalog: TitleTests.catalog, kept: KeptStanding())

        #expect(progress == .none)
        #expect(standing.title?.id == "t0")
        #expect(standing.gear.isEmpty)
    }

    @Test("Given a first the partner captured, when reading the family's moments, then it is captured, with their name")
    func partnersFirstIsTheFamilys() {
        let theirs = partners(.first(id: "f1"), child: anna, at: 1)

        let moments = FamilyMoments(events: [theirs], catalog: catalog)

        #expect(moments.capturedFirstIDs(for: anna) == ["f1"])
        #expect(moments.moments(for: anna).map(\.authorID) == [UUID.partner])
        #expect(DadProgress(events: [theirs], catalog: catalog).totalXP == 0)
    }

    @Test("Given a first both captured before either synced, when counting, then the family has the earlier, each their own")
    func firstCapturedTwice() {
        let theirs = partners(.first(id: "f1"), child: anna, at: 1)
        let mine = mine(.first(id: "f1"), child: anna, at: 2)
        let events = [mine, theirs]

        let moments = FamilyMoments(events: events, catalog: catalog)

        #expect(moments.moments(for: anna).map(\.eventID) == [theirs.id])
        #expect(DadProgress(events: events, catalog: catalog).totalXP == 30)
        #expect(Timeline.entries(from: events, catalog: catalog).map(\.id) == [mine.id, theirs.id])
    }

    @Test("Given a first both captured on the same date, when read in either order, then the lower id's is the child's")
    func sameDateCaptureIsTheSameEverywhere() throws {
        let lower = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000001"))
        let higher = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000002"))
        let date = Date(timeIntervalSince1970: 5)
        let theirs = ProgressEvent(id: lower, authorID: .partner, kind: .first(id: "f1"), childID: anna, date: date)
        let mine = ProgressEvent(id: higher, kind: .first(id: "f1"), childID: anna, date: date)

        let one = FamilyMoments(events: [mine, theirs], catalog: catalog).moments(for: anna)
        let other = FamilyMoments(events: [theirs, mine], catalog: catalog).moments(for: anna)

        #expect(one == other)
        #expect(one.map(\.authorID) == [.partner])
    }

    @Test("Given a boss both beat with one child, when counting, then it counts once for each and the film shows both")
    func bossBeatenByBoth() throws {
        let saga = SagaFixtures()
        let mine = ProgressEvent(kind: .boss(id: "b1"), childID: saga.child.id, date: saga.date(months: 1))
        let theirs = ProgressEvent(
            authorID: UUID.partner, kind: .boss(id: "b1"), childID: saga.child.id, date: saga.date(months: 2)
        )
        let again = ProgressEvent(kind: .boss(id: "b1"), childID: saga.child.id, date: saga.date(months: 3))

        let progress = DadProgress(events: [mine, theirs, again], catalog: saga.catalog)
        let film = try #require(saga.storyboard([mine, theirs, again]))

        #expect(progress.cardsDone == 1)
        let shown = film.scenes.compactMap { if case .entry(let entry) = $0.kind { entry.id } else { nil } }
        #expect(shown == [mine.id, theirs.id])
        #expect(film.scenes.last?.kind == .credits(SagaCredits(questsDone: 0, bossesBeaten: 1)))
    }

    @Test("Given the partner's quests with photos and a first, when making my film, then they play, the credits only mine")
    func filmIsTheFamilysCreditsMine() throws {
        let saga = SagaFixtures()
        let events = [
            saga.event(.quest(id: "q1"), months: 1, photos: "p1"),
            ProgressEvent(
                authorID: UUID.partner, kind: .quest(id: "q1"), childID: saga.child.id, date: saga.date(months: 2),
                photoIDs: ["p2"]
            ),
            ProgressEvent(authorID: UUID.partner, kind: .first(id: "f1"), childID: saga.child.id, date: saga.date(months: 3))
        ]

        let film = try #require(saga.storyboard(events))

        let shown = film.scenes.compactMap { if case .entry(let entry) = $0.kind { entry.id } else { nil } }
        #expect(shown == events.map(\.id))
        #expect(film.scenes.last?.kind == .credits(SagaCredits(questsDone: 1, bossesBeaten: 0)))
    }

    @Test("Given the partner's entry in a year of nothing of mine, when listing films, then that year has one")
    func partnersEntryMakesAPeriod() {
        let saga = SagaFixtures()
        let theirs = ProgressEvent(
            authorID: UUID.partner, kind: .quest(id: "q1"), childID: saga.child.id, date: saga.date(months: 14)
        )

        let periods = SagaPeriod.available(
            for: saga.child, events: [theirs], catalog: saga.catalog, now: saga.date(months: 30), timeZone: saga.timeZone
        )

        #expect(periods.contains(.year(2)))
        #expect(!periods.contains(.year(1)))
    }

    @Test("Given many of the partner's entries, when a deletion keeps my title, then it is the title mine reach")
    func deletionKeepsMyTitleOnly() {
        let mine = [mine(.quest(id: "q"), child: anna, at: 1)]
        let theirs = (0..<12).map { partners(.quest(id: "q"), child: anna, at: TimeInterval(2 + $0)) }
            + [partners(.boss(id: "b"), child: anna, at: 20), partners(.boss(id: "b2"), child: anna, at: 21)]

        let standing = DadStanding(
            progress: DadProgress(events: mine + theirs, catalog: TitleTests.catalog),
            catalog: TitleTests.catalog,
            kept: KeptStanding()
        )

        #expect(standing.titleToKeep?.id == "t1")
    }
}
