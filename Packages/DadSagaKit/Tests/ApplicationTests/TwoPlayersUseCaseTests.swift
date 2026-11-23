import Application
import Domain
import Foundation
import Testing

/// Two parents in one family, through the use cases the screens call (ADR-0065 §3): what is the dad's own and what is
/// the family's, and that he changes only what he recorded.
@Suite("Two players")
struct TwoPlayersUseCaseTests {
    static let text = Stub.text
    static let first = FirstMoment(id: "f-steps", order: 1, emoji: "👣", title: text, xp: 30, companionTrait: nil)
    static let catalog = ContentCatalog(
        worlds: [World(id: "w1", order: 1, title: text, tagline: text, span: .months(min: 0, max: 24))],
        quests: [Quest(id: "q1", worldID: "w1", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0)],
        bosses: [
            BossFight(id: "b1", worldID: "w1", title: text, intro: text, guide: [], badge: text,
                      skill: .care, xp: 100, minAgeMonths: 0)
        ],
        firsts: [first],
        titles: [DadTitle(id: "t0", order: 0, minCards: 0, minXP: 0, name: text)]
    )

    let today = Date(timeIntervalSince1970: 400 * 86_400)
    let dad = TheDad()
    var child: Child { dad.profile.children[0] }
    let content = StubContentRepository(result: .success(Self.catalog))
    let progress = SpyProgressRepository()
    let photos = SpyPhotoStore()

    func partners(_ kind: ProgressEvent.Kind) -> ProgressEvent {
        ProgressEvent(authorID: UUID.partner, kind: kind, childID: child.id, date: today.addingTimeInterval(-86_400))
    }

    var home: DefaultGetHomeOverviewUseCase {
        DefaultGetHomeOverviewUseCase(
            contentRepository: content, profileRepository: dad, progressRepository: progress,
            outfitRepository: SpyOutfitRepository(), standingRepository: InMemoryStanding(),
            sagaOfferRepository: FakeSagaOffers(), timeZone: .gmt
        )
    }

    @Test("Given a first the partner captured, when the dad captures it, then it is already captured and nothing is kept")
    func firstCapturedByThePartner() async throws {
        try await progress.add(partners(.first(id: Self.first.id)))
        let capture = DefaultCaptureMomentUseCase(
            contentRepository: content, progressRepository: progress, profileRepository: dad, photoStore: photos
        )

        await #expect(throws: MomentError.alreadyCaptured(Self.first.id)) {
            _ = try await capture.execute(
                CaptureMomentRequest(firstID: Self.first.id, childID: child.id, date: today), now: today
            )
        }

        #expect(try await progress.fetchEvents().count == 1)
    }

    @Test("Given a first nobody captured, when the dad captures it, then the change carries the child's new moment")
    func captureCarriesTheMoment() async throws {
        let capture = DefaultCaptureMomentUseCase(
            contentRepository: content, progressRepository: progress, profileRepository: dad, photoStore: photos
        )

        let change = try await capture.execute(
            CaptureMomentRequest(firstID: Self.first.id, childID: child.id, date: today), now: today
        )

        #expect(change.moment?.eventID == change.eventID)
        #expect(change.moment?.authorID == dad.profile.id)
        #expect(change.moment?.first == Self.first)
    }

    @Test("Given a boss the partner beat with the child, when the dad beats it too, then it is recorded and counts for him")
    func bossBeatenByThePartner() async throws {
        try await progress.add(partners(.boss(id: "b1")))
        let defeat = DefaultDefeatBossUseCase(
            contentRepository: content, progressRepository: progress, profileRepository: dad, photoStore: photos
        )

        let change = try await defeat.execute(bossID: "b1", childID: child.id, on: today, journal: .empty)
        let again = try await defeat.execute(bossID: "b1", childID: child.id, on: today, journal: .empty)

        #expect(change.gainedXP == 100)
        #expect(change.after.defeatedBossIDs(for: child.id) == ["b1"])
        #expect(again.eventID == nil)
        #expect(try await progress.fetchEvents().count == 2)
    }

    @Test("Given the partner's entries, when reading home, then the dad's progress is his and the child's firsts are all")
    func homeIsHisAndTheFamilys() async throws {
        try await progress.add(partners(.first(id: Self.first.id)))
        try await progress.add(partners(.boss(id: "b1")))
        try await progress.add(partners(.quest(id: "q1")))

        let overview = try #require(try await home.execute(childID: nil, worldID: nil, on: today))

        #expect(overview.progress == DadProgress(events: [], catalog: Self.catalog))
        #expect(overview.defeatedBossIDs.isEmpty)
        #expect(overview.moments.capturedFirstIDs(for: child.id) == [Self.first.id])
    }

    @Test("Given an entry the partner recorded, when the dad deletes or undoes it, then it is refused and stays")
    func partnersEntryIsNotHis() async throws {
        let theirs = partners(.quest(id: "q1"))
        try await progress.add(theirs)
        let standing = InMemoryStanding()
        let delete = DefaultDeleteEventUseCase(
            contentRepository: content, profileRepository: dad, progressRepository: progress,
            standingRepository: standing, photoStore: photos
        )
        let undo = DefaultUndoRecordUseCase(
            contentRepository: content, profileRepository: dad, progressRepository: progress,
            standingRepository: standing, photoStore: photos
        )

        await #expect(throws: ProgressError.notYourEntry) { try await delete.execute(eventID: theirs.id) }
        await #expect(throws: ProgressError.notYourEntry) { _ = try await undo.execute(undoing: theirs.id) }

        #expect(try await progress.fetchEvents() == [theirs])
        #expect(await standing.writes == 0)
    }

    @Test("Given entries the partner recorded, when the dad edits a quest's note or a moment's day, then both are refused")
    func partnersEntryIsNotHisToEdit() async throws {
        let quest = partners(.quest(id: "q1"))
        let moment = partners(.first(id: Self.first.id))
        try await progress.add(quest)
        try await progress.add(moment)
        let journal = DefaultUpdateJournalUseCase(profileRepository: dad, progressRepository: progress, photoStore: photos)
        let moments = DefaultUpdateMomentUseCase(profileRepository: dad, progressRepository: progress, photoStore: photos)

        await #expect(throws: ProgressError.notYourEntry) {
            try await journal.execute(eventID: quest.id, note: "μαζί", photos: [.added(Data([3]))])
        }
        await #expect(throws: ProgressError.notYourEntry) {
            try await moments.execute(momentID: moment.id, happenedOn: today, note: "x", photos: [], now: today)
        }

        #expect(try await progress.fetchEvents() == [quest, moment])
        #expect(await photos.stored.isEmpty)
    }

    @Test("Given the dad's own quest beside the partner's, when he edits its note, then it saves")
    func ownEntryStillEdits() async throws {
        let mine = ProgressEvent(kind: .quest(id: "q1"), childID: child.id, date: today)
        try await progress.add(partners(.quest(id: "q1")))
        try await progress.add(mine)

        try await DefaultUpdateJournalUseCase(profileRepository: dad, progressRepository: progress, photoStore: photos)
            .execute(eventID: mine.id, note: "δικό μου", photos: [])

        #expect(try await progress.fetchEvents().first { $0.id == mine.id }?.note == "δικό μου")
    }
}
