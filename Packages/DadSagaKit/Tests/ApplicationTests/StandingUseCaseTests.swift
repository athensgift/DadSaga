import Application
import Domain
import Foundation
import Testing

/// What the store keeps so a deletion never lowers the title (ADR-0055 §3), and gear only with titles (ADR-0060 §3).
@Suite("Standing use cases")
struct StandingUseCaseTests {
    let today = Date(timeIntervalSince1970: 1_000_000)
    let child = UUID()
    let photos = SpyPhotoStore()

    /// Two titles: the first card of 20 XP brings the mug, the second the cloth.
    static let catalog = ContentCatalog(
        worlds: Stub.catalog.worlds,
        quests: Stub.catalog.quests,
        bosses: [],
        firsts: [],
        gear: [
            GearItem(id: "g-mug", skill: .patience, look: "mug", title: Stub.text),
            GearItem(id: "g-cloth", skill: .care, look: "burpCloth", title: Stub.text)
        ],
        titles: [
            DadTitle(id: "t0", order: 0, minCards: 0, minXP: 0, name: Stub.text),
            DadTitle(id: "t1", order: 1, minCards: 1, minXP: 20, gearIDs: ["g-mug"], name: Stub.text),
            DadTitle(id: "t2", order: 2, minCards: 5, minXP: 500, gearIDs: ["g-cloth"], name: Stub.text)
        ]
    )
    let content = StubContentRepository(result: .success(Self.catalog))

    func quest(_ progress: any ProgressRepository) -> DefaultCompleteQuestUseCase {
        DefaultCompleteQuestUseCase(
            contentRepository: content, progressRepository: progress, profileRepository: TheDad(), photoStore: photos
        )
    }

    func delete(_ progress: any ProgressRepository, _ standing: InMemoryStanding) -> DefaultDeleteEventUseCase {
        DefaultDeleteEventUseCase(
            contentRepository: content, progressRepository: progress, standingRepository: standing, photoStore: photos
        )
    }

    @Test("Given care XP growing with every quest, when reading the hero, then he has only what his title brings")
    func skillXPEarnsNothingNew() async throws {
        let progress = SpyProgressRepository()
        let standing = InMemoryStanding()
        let sut = quest(progress)

        for _ in 0..<3 {
            _ = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)
        }
        let stand = DadStanding(
            progress: DadProgress(events: try await progress.fetchEvents(), catalog: Self.catalog),
            catalog: Self.catalog,
            kept: await standing.kept
        )

        #expect(stand.gear.map(\.id) == ["g-mug"])
    }

    /// Undo, as home does it: of the entry the recording returned.
    @discardableResult
    func undo(
        _ change: ProgressChange, _ progress: any ProgressRepository, _ standing: InMemoryStanding
    ) async throws -> DadTitle? {
        try await DefaultUndoRecordUseCase(
            contentRepository: content, progressRepository: progress, standingRepository: standing, photoStore: photos
        )
        .execute(undoing: try #require(change.eventID))
    }

    func standing(_ progress: any ProgressRepository, _ standing: InMemoryStanding) async throws -> DadStanding {
        DadStanding(
            progress: DadProgress(events: try await progress.fetchEvents(), catalog: Self.catalog),
            catalog: Self.catalog,
            kept: await standing.kept
        )
    }

    @Test("Given a quest that brought a title, when it is undone, then the title, its gear and its card go with it")
    func undoReturnsToBefore() async throws {
        let progress = SpyProgressRepository()
        let standing = InMemoryStanding()
        let change = try await quest(progress).execute(questID: "q1", childID: child, on: today, journal: .empty)
        #expect(try await self.standing(progress, standing).title?.id == "t1")

        try await undo(change, progress, standing)
        let stand = try await self.standing(progress, standing)

        #expect(try await progress.fetchEvents().isEmpty)
        #expect(stand.title?.id == "t0")
        #expect(stand.gear.isEmpty)
        #expect(stand.news == nil)
    }

    @Test("Given a title whose card was closed, when the quest is undone and done again, then its card comes again")
    func undoForgetsTheClosedCard() async throws {
        let progress = SpyProgressRepository()
        let standing = InMemoryStanding()
        let sut = quest(progress)
        let change = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)
        try await standing.markSeen(titleID: "t1")

        try await undo(change, progress, standing)
        #expect(await standing.kept.seenTitleID == "t0")
        _ = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)

        #expect(try await self.standing(progress, standing).news?.title.id == "t1")
    }

    @Test("Given two quests, the first bringing a title, when the second is undone, then the first's title stays")
    func undoOnlyTheLast() async throws {
        let progress = SpyProgressRepository()
        let standing = InMemoryStanding()
        let sut = quest(progress)
        let first = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)
        let second = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)

        let held = try await undo(second, progress, standing)

        #expect(try await progress.fetchEvents().count == 1)
        #expect(try await self.standing(progress, standing).title?.id == "t1")
        // The Undo says what he still holds, so home knows which closed cards may come again.
        #expect(held?.id == "t1")
        #expect(try await undo(first, progress, standing)?.id == "t0")
    }

    @Test(
        "Given two entries just recorded, the first bringing a title, when both are undone, then nothing is left of either",
        arguments: [true, false]
    )
    func twoUndosInEitherOrder(lastFirst: Bool) async throws {
        let progress = SpyProgressRepository()
        let standing = InMemoryStanding()
        let sut = quest(progress)
        let first = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)
        let second = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)
        try await standing.markSeen(titleID: "t1")

        for change in lastFirst ? [second, first] : [first, second] {
            try await undo(change, progress, standing)
        }
        let stand = try await self.standing(progress, standing)

        #expect(try await progress.fetchEvents().isEmpty)
        #expect(stand.title?.id == "t0")
        #expect(stand.gear.isEmpty)
        #expect(await standing.kept == KeptStanding(seenTitleID: "t0"))
    }

    @Test("Given a card recorded after the one being undone and deleted since, when the Undo runs, then the kept title stays")
    func undoNeverLowersWhatADeletionKept() async throws {
        let progress = SpyProgressRepository()
        let standing = InMemoryStanding()
        let sut = quest(progress)
        let first = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)
        let later = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)

        try await delete(progress, standing).execute(eventID: try #require(later.eventID))
        try await undo(first, progress, standing)

        // "Your title and what you got stay", the deletion said. Home ends the bar's Undo when the dad leaves for
        // the timeline or deletes a moment, so the two don't meet on screen; if they ever did, the title stays.
        #expect(try await progress.fetchEvents().isEmpty)
        #expect(try await self.standing(progress, standing).title?.id == "t1")
    }

    @Test("Given a quest that brought a title, when it is deleted from the timeline later, then the title stays")
    func deletionKeepsTheTitle() async throws {
        let progress = SpyProgressRepository()
        let standing = InMemoryStanding()
        let change = try await quest(progress).execute(questID: "q1", childID: child, on: today, journal: .empty)

        try await delete(progress, standing).execute(eventID: try #require(change.eventID))
        let stand = try await self.standing(progress, standing)

        #expect(try await progress.fetchEvents().isEmpty)
        #expect(stand.title?.id == "t1")
        #expect(stand.gear.map(\.id) == ["g-mug"])
    }

    @Test("Given a title's card, when a later quest is recorded, the card closed and the quest undone, then it stays closed")
    func undoKeepsACardClosedForATitleStillHeld() async throws {
        let progress = SpyProgressRepository()
        let standing = InMemoryStanding()
        let sut = quest(progress)
        _ = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)
        let later = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)
        try await standing.markSeen(titleID: "t1")

        try await undo(later, progress, standing)

        #expect(await standing.kept.seenTitleID == "t1")
        #expect(try await self.standing(progress, standing).news == nil)
    }

    @Test("Given an entry that isn't there, when undoing it, then it throws before the kept record is touched")
    func undoUnknownEntry() async throws {
        let progress = SpyProgressRepository()
        let standing = InMemoryStanding()
        let sut = DefaultUndoRecordUseCase(
            contentRepository: content, progressRepository: progress, standingRepository: standing, photoStore: photos
        )

        await #expect(throws: ProgressError.unknownEvent) { try await sut.execute(undoing: UUID()) }
        #expect(await standing.writes == 0)
        #expect(await standing.kept == KeptStanding())
    }

    @Test("Given an Undo whose delete fails, when it is tried again, then the entry stays the first time and goes the second")
    func undoRetriesAfterAFailedDelete() async throws {
        let progress = SpyProgressRepository()
        let standing = InMemoryStanding()
        let change = try await quest(progress).execute(questID: "q1", childID: child, on: today, journal: .empty)
        try await standing.markSeen(titleID: "t1")
        let keptBeforeUndo = await standing.kept
        await progress.failNextDelete()

        await #expect(throws: StubError.boom) { try await undo(change, progress, standing) }
        #expect(try await progress.fetchEvents().count == 1)
        #expect(await standing.kept == keptBeforeUndo)

        try await undo(change, progress, standing)
        #expect(try await progress.fetchEvents().isEmpty)
        #expect(try await self.standing(progress, standing).title?.id == "t0")
    }

    @Test("Given a quest saved with photos, when it is undone, then its photos are deleted too")
    func undoDeletesPhotos() async throws {
        let progress = SpyProgressRepository()
        let standing = InMemoryStanding()
        let journal = JournalInput(note: nil, photos: [Data([1]), Data([2])])
        let change = try await quest(progress).execute(questID: "q1", childID: child, on: today, journal: journal)
        #expect(await photos.stored.count == 2)

        try await undo(change, progress, standing)

        #expect(await photos.stored.isEmpty)
    }

}

extension StandingUseCaseTests {
    @Test("Given keeping the title fails, when deleting, then nothing is deleted")
    func failedKeepChangesNothing() async throws {
        let progress = SpyProgressRepository()
        let event = ProgressEvent(kind: .quest(id: "q1"), childID: child, date: today)
        try await progress.add(event)
        let standing = InMemoryStanding(KeptStanding())
        await standing.failKeeping()

        await #expect(throws: StubError.boom) { try await delete(progress, standing).execute(eventID: event.id) }
        #expect(try await progress.fetchEvents() == [event])
    }

    @Test("Given quests that bring a title, when recording them, then nothing is kept")
    func keepsOnlyWhatChanged() async throws {
        let progress = SpyProgressRepository()
        let standing = InMemoryStanding()
        let sut = quest(progress)

        for _ in 0..<3 {
            _ = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)
        }

        // The title is kept before a deletion only, so an Undo can take back the one a card brings.
        #expect(await standing.writes == 0)
        #expect(await standing.kept == KeptStanding())
    }

    @Test("Given a title held, when entries are deleted one after another, then it is written once")
    func deletionKeepsATitleOnce() async throws {
        let progress = SpyProgressRepository()
        let standing = InMemoryStanding()
        let sut = quest(progress)
        let first = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)
        let second = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)

        try await delete(progress, standing).execute(eventID: try #require(first.eventID))
        try await delete(progress, standing).execute(eventID: try #require(second.eventID))

        #expect(await standing.writes == 1)
        #expect(await standing.kept.titleID == "t1")
    }

    @Test("Given a title card, when the dad closes it, then the title is remembered as seen")
    func marksTitleSeen() async throws {
        let standing = InMemoryStanding()

        try await DefaultMarkTitleSeenUseCase(standingRepository: standing).execute(titleID: "t1")

        #expect(await standing.kept.seenTitleID == "t1")
    }
}
