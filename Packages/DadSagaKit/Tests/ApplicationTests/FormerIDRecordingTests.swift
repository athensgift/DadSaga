import Application
import Domain
import Foundation
import Testing

/// Recording through an id the content no longer uses (an old widget link, an old notification) stores the content's
/// current id, and a first stored under its former id still counts once (ADR-0048 §5).
@Suite("Recording under a former id")
struct FormerIDRecordingTests {
    static let quest = Quest(
        id: "q-new", worldID: "w1", title: Stub.text, description: Stub.text, skill: .care, xp: 20, minAgeMonths: 0,
        formerIDs: ["q-old"]
    )
    static let first = FirstMoment(
        id: "f-new", order: 1, emoji: "👣", title: Stub.text, xp: 30, companionTrait: "walk", formerIDs: ["f-old"]
    )
    let today = Date(timeIntervalSince1970: 1_000_000)
    let content = StubContentRepository(
        result: .success(ContentCatalog(worlds: [], quests: [Self.quest], bosses: [], firsts: [Self.first]))
    )
    let repository = SpyProgressRepository()
    let photos = SpyPhotoStore()
    let child = UUID()

    @Test("Given a quest renamed from q-old, when completing it as q-old, then it is stored as q-new with its XP")
    func questUnderFormerIDStoresTheCurrentID() async throws {
        let sut = DefaultCompleteQuestUseCase(contentRepository: content, progressRepository: repository, photoStore: photos)

        let change = try await sut.execute(questID: "q-old", childID: child, on: today, journal: .empty)

        #expect(change.gainedXP == 20)
        #expect(try await repository.fetchEvents().map(\.kind) == [.quest(id: "q-new")])
    }

    @Test("Given a first renamed from f-old, when capturing it as f-old, then it is stored as f-new")
    func firstUnderFormerIDStoresTheCurrentID() async throws {
        _ = try await capture.execute(CaptureMomentRequest(firstID: "f-old", childID: child, date: today), now: today)

        #expect(try await repository.fetchEvents().map(\.kind) == [.first(id: "f-new")])
    }

    @Test("Given a first stored under its former id, when capturing it again under its current id, then it is already captured")
    func firstStoredUnderFormerIDCountsOnce() async throws {
        try await repository.add(ProgressEvent(kind: .first(id: "f-old"), childID: child, date: today))

        await #expect(throws: MomentError.alreadyCaptured("f-new")) {
            try await capture.execute(CaptureMomentRequest(firstID: "f-new", childID: child, date: today), now: today)
        }
        #expect(try await repository.fetchEvents().count == 1)
    }

    private var capture: DefaultCaptureMomentUseCase {
        DefaultCaptureMomentUseCase(contentRepository: content, progressRepository: repository, photoStore: photos)
    }
}
