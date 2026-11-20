import Application
import Domain
import Foundation
import Testing

/// Several photos on one entry: the order, the limit, and that no file is left behind or lost (ADR-0042 §1).
@Suite("Entry photos")
struct EntryPhotoUseCaseTests {
    let today = Date(timeIntervalSince1970: 1_000_000)
    let content = StubContentRepository(result: .success(Stub.catalog))
    let repository = SpyProgressRepository()
    let child = UUID()

    func photoData(_ count: Int) -> [Data] {
        (0..<count).map { Data([UInt8($0)]) }
    }

    func completeQuest(
        photos: [Data], store: SpyPhotoStore, repository: (any ProgressRepository)? = nil
    ) async throws -> ProgressChange {
        try await DefaultCompleteQuestUseCase(
            contentRepository: content, progressRepository: repository ?? self.repository, photoStore: store
        ).execute(questID: "q1", childID: child, on: today, journal: JournalInput(photos: photos))
    }

    /// A quest stored with photos 0, 1 and 2.
    func questWithThreePhotos(store: SpyPhotoStore) async throws -> ProgressEvent {
        _ = try await completeQuest(photos: photoData(3), store: store)
        return try #require(try await repository.fetchEvents().first)
    }

    @Test("Given three photos, when recording, then they are kept in the dad's order with the first as cover")
    func keepsOrder() async throws {
        let store = SpyPhotoStore()

        let event = try await questWithThreePhotos(store: store)

        #expect(event.photoIDs.count == 3)
        let stored = await store.stored
        #expect(event.photoIDs.map { stored[$0] } == photoData(3))
        #expect(event.coverPhotoID == event.photoIDs.first)
    }

    @Test("Given eleven photos, when recording, then it throws and nothing is written")
    func tooManyWhenRecording() async throws {
        let store = SpyPhotoStore()

        await #expect(throws: ProgressError.tooManyPhotos) {
            try await completeQuest(photos: photoData(ProgressEvent.photoLimit + 1), store: store)
        }

        #expect(await store.saveCount == 0)
        #expect(try await repository.fetchEvents().isEmpty)
    }

    @Test("Given the second photo can't be stored, when recording, then the first is removed and no event is stored")
    func failedPhotoRemovesEarlierOnes() async throws {
        let store = SpyPhotoStore(failingOnSave: 2)

        await #expect(throws: SpyPhotoStore.Failure.self) {
            try await completeQuest(photos: photoData(3), store: store)
        }

        #expect(await store.saveCount == 2)
        #expect(await store.stored.isEmpty)
        #expect(try await repository.fetchEvents().isEmpty)
    }

    @Test("Given the event can't be stored, when recording three photos, then every photo is removed")
    func failedEventRemovesEveryPhoto() async throws {
        let store = SpyPhotoStore()

        await #expect(throws: FailingUpdates.Failure.self) {
            try await completeQuest(photos: photoData(3), store: store, repository: FailingUpdates(repository))
        }

        #expect(await store.saveCount == 3)
        #expect(await store.stored.isEmpty)
    }

    @Test("Given another save of the same boss landed first, when defeating it with photos, then no photo is kept")
    func alreadyCountedKeepsNoPhotos() async throws {
        let store = SpyPhotoStore()
        let sut = DefaultDefeatBossUseCase(contentRepository: content, progressRepository: LosesRace(), photoStore: store)

        let change = try await sut.execute(
            bossID: "b1", childID: child, on: today, journal: JournalInput(photos: photoData(2))
        )

        #expect(change.eventID == nil)
        #expect(await store.saveCount == 2)
        #expect(await store.stored.isEmpty)
    }

    @Test("Given three photos, when one is added, one removed and the last made cover, then exactly those are kept")
    func updateAddsRemovesAndReorders() async throws {
        let store = SpyPhotoStore()
        let event = try await questWithThreePhotos(store: store)
        let (first, removed, last) = (event.photoIDs[0], event.photoIDs[1], event.photoIDs[2])

        try await DefaultUpdateJournalUseCase(progressRepository: repository, photoStore: store).execute(
            eventID: event.id, note: nil, photos: [.kept(last), .added(Data([9])), .kept(first)]
        )

        let updated = try #require(try await repository.fetchEvents().first)
        #expect(updated.photoIDs.count == 3)
        #expect(updated.coverPhotoID == last)
        #expect(updated.photoIDs.last == first)
        #expect(!updated.photoIDs.contains(removed))
        let stored = await store.stored
        #expect(Set(stored.keys) == Set(updated.photoIDs))
        #expect(stored[updated.photoIDs[1]] == Data([9]))
    }

    @Test("Given the event can't be saved, when editing photos, then the old ones stay and the new one is removed")
    func failedUpdateKeepsOldPhotos() async throws {
        let store = SpyPhotoStore()
        let event = try await questWithThreePhotos(store: store)

        await #expect(throws: FailingUpdates.Failure.self) {
            try await DefaultUpdateJournalUseCase(progressRepository: FailingUpdates(repository), photoStore: store)
                .execute(eventID: event.id, note: nil, photos: [.added(Data([9])), .kept(event.photoIDs[0])])
        }

        #expect(Set(await store.stored.keys) == Set(event.photoIDs))
        #expect(try await repository.fetchEvents().first?.photoIDs == event.photoIDs)
    }

    @Test("Given a kept id the entry doesn't have, or eleven photos, when editing, then it throws and nothing is written")
    func updateRejectsUnknownOrTooMany() async throws {
        let store = SpyPhotoStore()
        let event = try await questWithThreePhotos(store: store)
        let sut = DefaultUpdateJournalUseCase(progressRepository: repository, photoStore: store)
        let other = try await store.save(Data([7]))

        await #expect(throws: ProgressError.unknownPhoto) {
            try await sut.execute(eventID: event.id, note: nil, photos: [.added(Data([9])), .kept(other)])
        }
        await #expect(throws: ProgressError.tooManyPhotos) {
            try await sut.execute(eventID: event.id, note: nil, photos: photoData(11).map(EntryPhoto.added))
        }

        #expect(await store.saveCount == 4)
        #expect(try await repository.fetchEvents().first == event)
    }

    @Test("Given an entry with three photos, when deleting it, then every photo is removed")
    func deleteRemovesEveryPhoto() async throws {
        let store = SpyPhotoStore()
        let event = try await questWithThreePhotos(store: store)

        try await DefaultDeleteEventUseCase(progressRepository: repository, photoStore: store).execute(eventID: event.id)

        #expect(await store.stored.isEmpty)
    }
}

/// Keeps "photos" in memory, exactly as given. It can fail on the nth save, like a full disk.
actor SpyPhotoStore: PhotoStore {
    struct Failure: Error {}

    private(set) var stored: [String: Data] = [:]
    /// Every photo ever written, kept or not, the failed one included.
    private(set) var saveCount = 0
    private let failingOnSave: Int?

    init(failingOnSave: Int? = nil) {
        self.failingOnSave = failingOnSave
    }

    func save(_ imageData: Data) async throws -> String {
        saveCount += 1
        if saveCount == failingOnSave { throw Failure() }
        let id = UUID().uuidString
        stored[id] = imageData
        return id
    }

    /// Tags the data so tests can tell a thumbnail from the original.
    func thumbnail(id: String, maxPixelSize: Int) async -> Data? {
        stored[id].map { Data("thumb\(maxPixelSize):".utf8) + $0 }
    }

    func delete(id: String) async {
        stored[id] = nil
    }

    func deleteAll() async {
        stored = [:]
    }
}
