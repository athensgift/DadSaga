import Application
import Domain
import Foundation
import Testing

@Suite("Progress use cases")
struct ProgressUseCaseTests {
    let today = Date(timeIntervalSince1970: 1_000_000)
    let content = StubContentRepository(result: .success(Stub.catalog))

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

        let change = try await sut.execute(questID: "q1", on: today)

        #expect(change.gainedXP == 20)
        #expect(!change.leveledUp)
        #expect(try await repository.fetchEvents().map(\.kind) == [.quest(id: "q1")])
    }

    @Test("Given 80 XP, when completing a 20 XP quest, then the dad levels up")
    func levelsUp() async throws {
        let repository = SpyProgressRepository()
        for _ in 0..<4 {
            try await repository.add(ProgressEvent(kind: .quest(id: "q1"), date: today))
        }
        let sut = DefaultCompleteQuestUseCase(contentRepository: content, progressRepository: repository)

        let change = try await sut.execute(questID: "q1", on: today)

        #expect(change.before.totalXP == 80)
        #expect(change.after.level.level == 2)
        #expect(change.leveledUp)
    }

    @Test("Given an unknown quest, when completing it, then it throws and nothing is stored")
    func unknownQuest() async throws {
        let repository = SpyProgressRepository()
        let sut = DefaultCompleteQuestUseCase(contentRepository: content, progressRepository: repository)

        await #expect(throws: ProgressError.unknownQuest("nope")) {
            try await sut.execute(questID: "nope", on: today)
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
