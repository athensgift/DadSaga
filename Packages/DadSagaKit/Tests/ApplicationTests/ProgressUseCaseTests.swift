import Application
import Domain
import Foundation
import Testing

@Suite("Progress use cases")
struct ProgressUseCaseTests {
    let today = Date(timeIntervalSince1970: 1_000_000)
    let content = StubContentRepository(result: .success(Stub.catalog))
    let child = UUID()
    let photos = SpyPhotoStore()

    @Test("Given a note and a photo, when completing a quest, then both are kept on the event and are its last journal")
    func completesQuestWithJournal() async throws {
        let repository = SpyProgressRepository()
        let sut = DefaultCompleteQuestUseCase(contentRepository: content, progressRepository: repository, photoStore: photos)

        let change = try await sut.execute(
            questID: "q1", childID: child, on: today, journal: JournalInput(note: "  first bath!  ", photos: [Data([1])])
        )

        let event = try #require(try await repository.fetchEvents().first)
        #expect(event.note == "first bath!")
        #expect(event.photoIDs.count == 1)
        #expect(await photos.stored.count == 1)
        #expect(change.after.lastJournal(for: .quest(id: "q1"), childID: child)?.note == "first bath!")
        #expect(change.after.lastJournal(for: .quest(id: "q1"), childID: UUID()) == nil)
    }

    @Test("Given a quest with a photo, when updating its journal, then the note changes and the old photo is removed")
    func updatesJournal() async throws {
        let repository = SpyProgressRepository()
        _ = try await DefaultCompleteQuestUseCase(contentRepository: content, progressRepository: repository, photoStore: photos)
            .execute(questID: "q1", childID: child, on: today, journal: JournalInput(note: "a", photos: [Data([1])]))
        let event = try #require(try await repository.fetchEvents().first)

        try await DefaultUpdateJournalUseCase(progressRepository: repository, photoStore: photos)
            .execute(eventID: event.id, note: "b", photos: [])

        let updated = try #require(try await repository.fetchEvents().first)
        #expect(updated.note == "b")
        #expect(updated.photoIDs.isEmpty)
        #expect(updated.date == event.date)
        #expect(await photos.stored.isEmpty)
    }

    @Test("Given a known quest, when completing it, then an event is stored and its XP is gained")
    func completesQuest() async throws {
        let repository = SpyProgressRepository()
        let sut = DefaultCompleteQuestUseCase(contentRepository: content, progressRepository: repository, photoStore: photos)

        let change = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)

        #expect(change.gainedXP == 20)
        #expect(!change.leveledUp)
        #expect(try await repository.fetchEvents().map(\.kind) == [.quest(id: "q1")])
        #expect(try await repository.fetchEvents().map(\.childID) == [child])
    }

    @Test("Given 80 XP, when completing a 20 XP quest, then the dad levels up")
    func levelsUp() async throws {
        let repository = SpyProgressRepository()
        for _ in 0..<4 {
            try await repository.add(ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: today))
        }
        let sut = DefaultCompleteQuestUseCase(contentRepository: content, progressRepository: repository, photoStore: photos)

        let change = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)

        #expect(change.before.totalXP == 80)
        #expect(change.after.level.level == 2)
        #expect(change.leveledUp)
    }

    @Test("Given an unknown quest, when completing it, then it throws and nothing is stored")
    func unknownQuest() async throws {
        let repository = SpyProgressRepository()
        let sut = DefaultCompleteQuestUseCase(contentRepository: content, progressRepository: repository, photoStore: photos)

        await #expect(throws: ProgressError.unknownQuest("nope")) {
            try await sut.execute(questID: "nope", childID: child, on: today, journal: .empty)
        }
        #expect(try await repository.fetchEvents().isEmpty)
    }

    @Test("Given an undefeated boss, when defeating it, then its XP is gained once and one event is stored")
    func defeatsBoss() async throws {
        let repository = SpyProgressRepository()
        let sut = DefaultDefeatBossUseCase(contentRepository: content, progressRepository: repository, photoStore: photos)

        let change = try await sut.execute(bossID: "b1", childID: child, on: today, journal: .empty)

        #expect(change.gainedXP == 100)
        #expect(change.after.defeatedBossIDs(for: child) == ["b1"])
        #expect(try await repository.fetchEvents().map(\.kind) == [.boss(id: "b1")])
    }

    @Test("Given a boss already defeated, when defeating it again with a photo, then nothing changes and nothing is kept")
    func bossOnlyOnce() async throws {
        let repository = SpyProgressRepository()
        let sut = DefaultDefeatBossUseCase(contentRepository: content, progressRepository: repository, photoStore: photos)
        _ = try await sut.execute(bossID: "b1", childID: child, on: today, journal: .empty)

        let change = try await sut.execute(bossID: "b1", childID: child, on: today, journal: JournalInput(photos: [Data([1])]))

        #expect(change.gainedXP == 0)
        #expect(change.eventID == nil)
        #expect(try await repository.fetchEvents().count == 1)
        #expect(await photos.saveCount == 0)
    }

    @Test("Given a boss defeated with one child, when defeating it with another, then it counts again")
    func bossPerChild() async throws {
        let repository = SpyProgressRepository()
        let sut = DefaultDefeatBossUseCase(contentRepository: content, progressRepository: repository, photoStore: photos)
        _ = try await sut.execute(bossID: "b1", childID: child, on: today, journal: .empty)

        let change = try await sut.execute(bossID: "b1", childID: UUID(), on: today, journal: .empty)

        #expect(change.gainedXP == 100)
        #expect(try await repository.fetchEvents().count == 2)
    }

    @Test("Given a quest done once, when completing it again with the same child, then it is stored and counts again")
    func questRepeatable() async throws {
        let repository = SpyProgressRepository()
        let sut = DefaultCompleteQuestUseCase(contentRepository: content, progressRepository: repository, photoStore: photos)
        _ = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)

        let change = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)

        #expect(change.gainedXP == 20)
        #expect(try await repository.fetchEvents().count == 2)
    }

    @Test("Given another save of the same boss landed first, when defeating it, then nothing is added and no photo is kept")
    func bossRace() async throws {
        let sut = DefaultDefeatBossUseCase(contentRepository: content, progressRepository: LosesRace(), photoStore: photos)

        let change = try await sut.execute(bossID: "b1", childID: child, on: today, journal: JournalInput(photos: [Data([1])]))

        #expect(change.eventID == nil)
        #expect(change.gainedXP == 0)
        #expect(await photos.stored.isEmpty)
    }

    @Test("Given storing fails, when recording a quest or a boss with a photo, then it throws and the photo is removed")
    func failedSaveRemovesPhoto() async throws {
        let failing = FailingUpdates(SpyProgressRepository())
        let quest = DefaultCompleteQuestUseCase(contentRepository: content, progressRepository: failing, photoStore: photos)
        let boss = DefaultDefeatBossUseCase(contentRepository: content, progressRepository: failing, photoStore: photos)

        await #expect(throws: FailingUpdates.Failure.self) {
            try await quest.execute(questID: "q1", childID: child, on: today, journal: JournalInput(photos: [Data([1])]))
        }
        await #expect(throws: FailingUpdates.Failure.self) {
            try await boss.execute(bossID: "b1", childID: child, on: today, journal: JournalInput(photos: [Data([2])]))
        }
        #expect(await photos.saveCount == 2)
        #expect(await photos.stored.isEmpty)
    }

    @Test("Given a quest that crosses a gear threshold, when completing it, then the change names the new gear")
    func newGear() async throws {
        let text = Stub.text
        let catalog = ContentCatalog(
            worlds: Stub.catalog.worlds,
            quests: Stub.catalog.quests,
            bosses: [],
            firsts: [],
            gear: [
                GearItem(id: "g-cloth", skill: .care, minXP: 40, look: "burpCloth", title: text),
                GearItem(id: "g-duck", skill: .play, minXP: 20, look: "duck", title: text)
            ]
        )
        let sut = DefaultCompleteQuestUseCase(
            contentRepository: StubContentRepository(result: .success(catalog)),
            progressRepository: SpyProgressRepository(),
            photoStore: photos
        )

        let first = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)
        let second = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)
        let third = try await sut.execute(questID: "q1", childID: child, on: today, journal: .empty)

        #expect(first.newGear.isEmpty)
        #expect(second.newGear.map(\.id) == ["g-cloth"])
        #expect(third.newGear.isEmpty)
    }

    @Test("Given an unknown boss, when defeating it, then it throws and nothing is stored")
    func unknownBoss() async throws {
        let repository = SpyProgressRepository()
        let sut = DefaultDefeatBossUseCase(contentRepository: content, progressRepository: repository, photoStore: photos)

        await #expect(throws: ProgressError.unknownBoss("nope")) {
            try await sut.execute(bossID: "nope", childID: child, on: today, journal: .empty)
        }
        #expect(try await repository.fetchEvents().isEmpty)
    }
}

/// Shows no events, then finds the event already stored when adding: another save got there first.
struct LosesRace: ProgressRepository {
    func fetchEvents() async throws -> [ProgressEvent] { [] }
    func referencedPhotoIDs() async throws -> Set<String> { [] }
    func add(_ event: ProgressEvent) async throws {}
    func addUnlessRecorded(_ event: ProgressEvent) async throws -> Bool { false }
    func update(_ event: ProgressEvent) async throws {}
    func delete(id: UUID) async throws {}
}

actor SpyProgressRepository: ProgressRepository {
    private var events: [ProgressEvent] = []

    func fetchEvents() async throws -> [ProgressEvent] {
        events
    }

    func referencedPhotoIDs() async throws -> Set<String> {
        Set(events.flatMap(\.photoIDs))
    }

    func add(_ event: ProgressEvent) async throws {
        events.append(event)
    }

    func addUnlessRecorded(_ event: ProgressEvent) async throws -> Bool {
        guard !events.contains(where: { $0.kind == event.kind && $0.childID == event.childID }) else { return false }
        events.append(event)
        return true
    }

    func update(_ event: ProgressEvent) async throws {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { throw ProgressError.unknownEvent }
        events[index] = event
    }

    func delete(id: UUID) async throws {
        events.removeAll { $0.id == id }
    }
}
