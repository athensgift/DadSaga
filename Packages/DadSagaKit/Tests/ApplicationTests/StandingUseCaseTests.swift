import Application
import Domain
import Foundation
import Testing

/// What the store keeps so a title never goes down and gear from before titles stays (ADR-0055 §3, §4).
@Suite("Standing use cases")
struct StandingUseCaseTests {
    let today = Date(timeIntervalSince1970: 1_000_000)
    let child = UUID()
    let photos = SpyPhotoStore()

    /// Two titles: the first card of 20 XP brings the mug. The cloth shipped before titles at 30 care XP.
    static let catalog = ContentCatalog(
        worlds: Stub.catalog.worlds,
        quests: Stub.catalog.quests,
        bosses: [],
        firsts: [],
        gear: [
            GearItem(id: "g-mug", skill: .patience, look: "mug", title: Stub.text),
            GearItem(id: "g-cloth", skill: .care, skillXPBeforeTitles: 30, look: "burpCloth", title: Stub.text)
        ],
        titles: [
            DadTitle(id: "t0", order: 0, minCards: 0, minXP: 0, name: Stub.text),
            DadTitle(id: "t1", order: 1, minCards: 1, minXP: 20, gearIDs: ["g-mug"], name: Stub.text),
            DadTitle(id: "t2", order: 2, minCards: 5, minXP: 500, gearIDs: ["g-cloth"], name: Stub.text)
        ]
    )
    let content = StubContentRepository(result: .success(Self.catalog))

    func quest(_ progress: any ProgressRepository, _ standing: InMemoryStanding) -> DefaultCompleteQuestUseCase {
        DefaultCompleteQuestUseCase(
            contentRepository: content, progressRepository: progress, standingRepository: standing, photoStore: photos
        )
    }

    func delete(_ progress: any ProgressRepository, _ standing: InMemoryStanding) -> DefaultDeleteEventUseCase {
        DefaultDeleteEventUseCase(
            contentRepository: content, progressRepository: progress, standingRepository: standing, photoStore: photos
        )
    }

    @Test("Given a store from before titles with 40 care XP, when recording a quest, then the cloth is frozen first")
    func firstRecordFreezesOldGear() async throws {
        let progress = SpyProgressRepository()
        try await progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: child, date: today))
        try await progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: child, date: today))
        let standing = InMemoryStanding(KeptStanding())

        _ = try await quest(progress, standing).execute(questID: "q1", childID: child, on: today, journal: .empty)

        #expect(await standing.kept.gearIDs == ["g-cloth"])
        #expect(await standing.kept.titleID == "t1")
    }

    @Test("Given a saga begun with titles, when skill XP passes an old threshold, then it earns nothing")
    func skillXPEarnsNothingNew() async throws {
        let progress = SpyProgressRepository()
        let standing = InMemoryStanding()
        let sut = quest(progress, standing)

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

    @Test("Given a quest that brought a title, when it is undone, then the title, its gear and its card stay")
    func undoKeepsTheTitle() async throws {
        let progress = SpyProgressRepository()
        let standing = InMemoryStanding()
        let change = try await quest(progress, standing).execute(questID: "q1", childID: child, on: today, journal: .empty)
        // The next change keeps what the first one brought.
        let second = try await quest(progress, standing).execute(questID: "q1", childID: child, on: today, journal: .empty)

        try await delete(progress, standing).execute(eventID: try #require(second.eventID))
        try await delete(progress, standing).execute(eventID: try #require(change.eventID))
        let stand = DadStanding(
            progress: DadProgress(events: try await progress.fetchEvents(), catalog: Self.catalog),
            catalog: Self.catalog,
            kept: await standing.kept
        )

        #expect(try await progress.fetchEvents().isEmpty)
        #expect(stand.title?.id == "t1")
        #expect(stand.gear.map(\.id) == ["g-mug"])
        #expect(stand.news?.title.id == "t1")
    }

    @Test("Given an entry from before titles that earned the cloth, when it is deleted, then the cloth stays")
    func deletingAnOldEntryKeepsGear() async throws {
        let progress = SpyProgressRepository()
        let old = ProgressEvent(kind: .quest(id: "q1"), childID: child, date: today)
        try await progress.add(old)
        try await progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: child, date: today))
        let standing = InMemoryStanding(KeptStanding())

        try await delete(progress, standing).execute(eventID: old.id)
        let stand = DadStanding(
            progress: DadProgress(events: try await progress.fetchEvents(), catalog: Self.catalog),
            catalog: Self.catalog,
            kept: await standing.kept
        )

        #expect(stand.gear.map(\.id).sorted() == ["g-cloth", "g-mug"])
    }

    @Test("Given keeping fails, when deleting or recording, then nothing is deleted or recorded")
    func failedKeepChangesNothing() async throws {
        let progress = SpyProgressRepository()
        let event = ProgressEvent(kind: .quest(id: "q1"), childID: child, date: today)
        try await progress.add(event)
        let standing = InMemoryStanding(KeptStanding())
        await standing.failKeeping()

        await #expect(throws: StubError.boom) { try await delete(progress, standing).execute(eventID: event.id) }
        await #expect(throws: StubError.boom) {
            try await quest(progress, standing).execute(questID: "q1", childID: child, on: today, journal: .empty)
        }
        #expect(try await progress.fetchEvents() == [event])
    }

    @Test("Given nothing changes, when recording a quest at the kept title, then the store is not written again")
    func keepsOnlyWhatChanged() async throws {
        let progress = SpyProgressRepository()
        let standing = InMemoryStanding()
        let sut = quest(progress, standing)

        for _ in 0..<3 {
            _ = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)
        }

        // The first record had title 0 to keep; the second keeps title 1; the third has nothing new.
        #expect(await standing.writes == 2)
    }

    @Test("Given a title card, when the dad closes it, then the title is remembered as seen")
    func marksTitleSeen() async throws {
        let standing = InMemoryStanding()

        try await DefaultMarkTitleSeenUseCase(standingRepository: standing).execute(titleID: "t1")

        #expect(await standing.kept.seenTitleID == "t1")
    }
}
