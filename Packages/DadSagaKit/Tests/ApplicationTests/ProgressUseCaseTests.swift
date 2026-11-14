import Application
import Domain
import Foundation
import Testing

@Suite("Progress use cases")
struct ProgressUseCaseTests {
    let today = Date(timeIntervalSince1970: 1_000_000)
    let content = StubContentRepository(result: .success(Stub.catalog))
    let child = UUID()

    @Test("Given no events, when getting progress, then the dad is level 1 with 0 XP")
    func emptyProgress() async throws {
        let sut = DefaultGetProgressUseCase(contentRepository: content, progressRepository: SpyProgressRepository())
        let progress = try await sut.execute()
        #expect(progress.totalXP == 0)
        #expect(progress.level.level == 1)
    }

    @Test("Given a known quest, when completing it, then an event is stored and its XP is gained")
    func completesQuest() async throws {
        let repository = SpyProgressRepository()
        let sut = DefaultCompleteQuestUseCase(contentRepository: content, progressRepository: repository)

        let change = try await sut.execute(questID: "q1", childID: child, on: today)

        #expect(change.gainedXP == 20)
        #expect(!change.leveledUp)
        #expect(try await repository.fetchEvents().map(\.kind) == [.quest(id: "q1")])
        #expect(try await repository.fetchEvents().map(\.childID) == [child])
    }

    @Test("Given 80 XP, when completing a 20 XP quest, then the dad levels up")
    func levelsUp() async throws {
        let repository = SpyProgressRepository()
        for _ in 0..<4 {
            try await repository.add(ProgressEvent(kind: .quest(id: "q1"), date: today))
        }
        let sut = DefaultCompleteQuestUseCase(contentRepository: content, progressRepository: repository)

        let change = try await sut.execute(questID: "q1", childID: child, on: today)

        #expect(change.before.totalXP == 80)
        #expect(change.after.level.level == 2)
        #expect(change.leveledUp)
    }

    @Test("Given an unknown quest, when completing it, then it throws and nothing is stored")
    func unknownQuest() async throws {
        let repository = SpyProgressRepository()
        let sut = DefaultCompleteQuestUseCase(contentRepository: content, progressRepository: repository)

        await #expect(throws: ProgressError.unknownQuest("nope")) {
            try await sut.execute(questID: "nope", childID: child, on: today)
        }
        #expect(try await repository.fetchEvents().isEmpty)
    }

    @Test("Given an undefeated boss, when defeating it, then its XP is gained once and one event is stored")
    func defeatsBoss() async throws {
        let repository = SpyProgressRepository()
        let sut = DefaultDefeatBossUseCase(contentRepository: content, progressRepository: repository)

        let change = try await sut.execute(bossID: "b1", childID: child, on: today)

        #expect(change.gainedXP == 100)
        #expect(change.after.defeatedBossIDs(for: child) == ["b1"])
        #expect(try await repository.fetchEvents().map(\.kind) == [.boss(id: "b1")])
    }

    @Test("Given a boss already defeated, when defeating it again, then nothing changes and nothing is stored")
    func bossOnlyOnce() async throws {
        let repository = SpyProgressRepository()
        let sut = DefaultDefeatBossUseCase(contentRepository: content, progressRepository: repository)
        _ = try await sut.execute(bossID: "b1", childID: child, on: today)

        let change = try await sut.execute(bossID: "b1", childID: child, on: today)

        #expect(change.gainedXP == 0)
        #expect(try await repository.fetchEvents().count == 1)
    }

    @Test("Given a boss defeated with one child, when defeating it with another, then it counts again")
    func bossPerChild() async throws {
        let repository = SpyProgressRepository()
        let sut = DefaultDefeatBossUseCase(contentRepository: content, progressRepository: repository)
        _ = try await sut.execute(bossID: "b1", childID: child, on: today)

        let change = try await sut.execute(bossID: "b1", childID: UUID(), on: today)

        #expect(change.gainedXP == 100)
        #expect(try await repository.fetchEvents().count == 2)
    }

    @Test("Given an unknown boss, when defeating it, then it throws and nothing is stored")
    func unknownBoss() async throws {
        let repository = SpyProgressRepository()
        let sut = DefaultDefeatBossUseCase(contentRepository: content, progressRepository: repository)

        await #expect(throws: ProgressError.unknownBoss("nope")) {
            try await sut.execute(bossID: "nope", childID: child, on: today)
        }
        #expect(try await repository.fetchEvents().isEmpty)
    }
}

actor SpyProgressRepository: ProgressRepository {
    private var events: [ProgressEvent] = []

    func fetchEvents() async throws -> [ProgressEvent] {
        events
    }

    func add(_ event: ProgressEvent) async throws {
        events.append(event)
    }

    func deleteAll() async throws {
        events = []
    }
}
