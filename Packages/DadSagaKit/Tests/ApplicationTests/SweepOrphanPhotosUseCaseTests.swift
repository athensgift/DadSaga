import Application
import Domain
import Foundation
import Testing

/// The launch sweep of photos no entry points to (ADR-0048 §6). A wrongly deleted photo is lost for good, so every doubt
/// keeps the file: an unreadable saga, no saga at all, a recent file, a file without a date.
@Suite("Sweep of orphan photos")
struct SweepOrphanPhotosUseCaseTests {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let child = UUID()

    var twoDaysAgo: Date { now.addingTimeInterval(-2 * 86_400) }

    func sweep(
        profiles: any ProfileRepository, progress: any ProgressRepository, photos: DatedPhotoStore
    ) -> DefaultSweepOrphanPhotosUseCase {
        DefaultSweepOrphanPhotosUseCase(profileRepository: profiles, progressRepository: progress, photoStore: photos)
    }

    func profiles(children: [UUID]) async throws -> SpyProfileRepository {
        let profiles = SpyProfileRepository()
        let kids = children.map { Child(id: $0, name: "Kid", birthDay: .day(2024, 1, 1)) }
        await profiles.seed(PlayerProfile(children: kids, heroClassID: "h1"))
        return profiles
    }

    @Test("Given a saga whose entries can't be read, when sweeping, then no photo is deleted")
    func unreadableSagaDeletesNothing() async throws {
        let photos = DatedPhotoStore(["old": twoDaysAgo])

        await #expect(throws: UnreadableProgress.Failure.self) {
            try await sweep(profiles: profiles(children: [child]), progress: UnreadableProgress(), photos: photos)
                .execute(now: now)
        }

        #expect(await photos.ids == ["old"])
    }

    @Test("Given a saga whose profile can't be read, when sweeping, then no photo is deleted")
    func unreadableProfileDeletesNothing() async throws {
        let photos = DatedPhotoStore(["old": twoDaysAgo])

        await #expect(throws: UnreadableProfiles.Failure.self) {
            try await sweep(profiles: UnreadableProfiles(), progress: SpyProgressRepository(), photos: photos)
                .execute(now: now)
        }

        #expect(await photos.ids == ["old"])
    }

    @Test("Given no saga yet, when sweeping, then no photo is deleted")
    func noProfileDeletesNothing() async throws {
        let photos = DatedPhotoStore(["old": twoDaysAgo])

        let deleted = try await sweep(profiles: SpyProfileRepository(), progress: SpyProgressRepository(), photos: photos)
            .execute(now: now)

        #expect(deleted == 0)
        #expect(await photos.ids == ["old"])
    }

    @Test("Given a photo written a minute ago that no entry points to yet, when sweeping, then it is kept")
    func recentPhotoIsKept() async throws {
        let photos = DatedPhotoStore(["new": now.addingTimeInterval(-60), "almost": now.addingTimeInterval(-86_399)])

        let deleted = try await sweep(profiles: profiles(children: [child]), progress: SpyProgressRepository(), photos: photos)
            .execute(now: now)

        #expect(deleted == 0)
        #expect(await photos.ids == ["almost", "new"])
    }

    @Test("Given a photo without a date or dated in the future, when sweeping, then it is kept")
    func undatedOrFuturePhotoIsKept() async throws {
        let photos = DatedPhotoStore(["undated": nil, "future": now.addingTimeInterval(86_400 * 30)])

        let deleted = try await sweep(profiles: profiles(children: [child]), progress: SpyProgressRepository(), photos: photos)
            .execute(now: now)

        #expect(deleted == 0)
        #expect(await photos.ids == ["future", "undated"])
    }

    @Test("""
    Given old photos of two children, a removed child and content the app no longer knows, and one old photo nothing \
    points to, when sweeping, then only that one is deleted
    """)
    func oldOrphanIsDeleted() async throws {
        let second = UUID()
        let removed = UUID()
        let progress = SpyProgressRepository()
        try await progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: child, date: twoDaysAgo, photoIDs: ["a", "b"]))
        try await progress.add(ProgressEvent(kind: .first(id: "f1"), childID: second, date: twoDaysAgo, photoIDs: ["c"]))
        try await progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: removed, date: twoDaysAgo, photoIDs: ["d"]))
        try await progress.add(ProgressEvent(kind: .boss(id: "gone"), childID: child, date: twoDaysAgo, photoIDs: ["e"]))
        let names = ["a", "b", "c", "d", "e", "orphan"]
        let photos = DatedPhotoStore(Dictionary(uniqueKeysWithValues: names.map { ($0, Optional(twoDaysAgo)) }))

        let deleted = try await sweep(profiles: profiles(children: [child, second]), progress: progress, photos: photos)
            .execute(now: now)

        #expect(deleted == 1)
        #expect(await photos.ids == ["a", "b", "c", "d", "e"])
    }
}

/// A store whose entries cannot be read, like one that will not open.
struct UnreadableProgress: ProgressRepository {
    struct Failure: Error {}
    func fetchEvents() async throws -> [ProgressEvent] { throw Failure() }
    func referencedPhotoIDs() async throws -> Set<String> { throw Failure() }
    func add(_ event: ProgressEvent) async throws { throw Failure() }
    func addUnlessRecorded(_ event: ProgressEvent) async throws -> Bool { throw Failure() }
    func update(_ event: ProgressEvent) async throws { throw Failure() }
    func delete(id: UUID) async throws { throw Failure() }
}

/// Photos with the date each file was written; `nil` is a file whose date can't be read.
actor DatedPhotoStore: PhotoStore {
    private var files: [String: Date?]

    init(_ files: [String: Date?]) {
        self.files = files
    }

    var ids: [String] { files.keys.sorted() }

    func storedPhotos() async throws -> [StoredPhoto] {
        files.map { StoredPhoto(id: $0.key, savedAt: $0.value) }
    }

    func save(_ imageData: Data) async throws -> String { "" }
    func thumbnail(id: String, maxPixelSize: Int) async -> Data? { nil }
    func storedData(id: String) async throws -> Data { Data() }
    func adopt(_ jpeg: Data) async throws -> String { "" }
    func delete(id: String) async { files[id] = nil }
    func deleteAll() async { files = [:] }
}
