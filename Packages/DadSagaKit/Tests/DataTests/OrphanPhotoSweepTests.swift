import Application
import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// The launch sweep against the real store and photo folder (ADR-0048 §6).
@Suite("Orphan photo sweep")
struct OrphanPhotoSweepTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-sweep-" + UUID().uuidString)
    let child = Child(name: "Λένα", birthDay: .day(2023, 11, 14))

    var photoFolder: URL { directory.appending(path: "Photos", directoryHint: .isDirectory) }

    /// A tiny JPEG: the store only keeps images.
    let jpeg = Data(base64Encoded: """
    /9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////\
    wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAA//EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AN//Z
    """) ?? Data()

    @Test("Given rows the app can't show, when reading the referenced photos, then theirs are included")
    func referencedPhotoIDsIncludeHiddenRows() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalStore.live(in: directory)
        try await store.progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: child.id, date: .now, photoIDs: ["a"]))
        try writeRows([
            ProgressEventRecord(eventID: UUID(), kind: "dream", contentID: "d1", childID: child.id, date: .now, note: nil,
                                photoIDs: ["b"]),
            ProgressEventRecord(eventID: UUID(), kind: "quest", contentID: "q1", childID: nil, date: .now, note: nil,
                                photoIDs: ["c"])
        ])

        let reopened = LocalStore.live(in: directory)

        #expect(try await reopened.progress.fetchEvents().count == 1)
        #expect(try await reopened.progress.referencedPhotoIDs() == ["a", "b", "c"])
    }

    @Test("""
    Given a start over that stopped after erasing the saga, when the dad starts again and the app launches two days \
    later, then the old photos are gone and the new entry's photo stays
    """)
    func sweepAfterAStartOverCutShort() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalStore.inMemory()
        let photos = FilePhotoStore(directory: photoFolder)
        let old = try await photos.save(jpeg)
        try await store.profiles.save(PlayerProfile(children: [child], heroClassID: "h-chef"))
        try await store.progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: child.id, date: .now, photoIDs: [old]))
        try await store.eraser.eraseAll()
        try await store.profiles.save(PlayerProfile(children: [child], heroClassID: "h-chef"))
        let new = try await photos.save(jpeg)
        try await store.progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: child.id, date: .now, photoIDs: [new]))
        let sut = DefaultSweepOrphanPhotosUseCase(
            profileRepository: store.profiles, progressRepository: store.progress, photoStore: photos
        )

        let deleted = try await sut.execute(now: .now.addingTimeInterval(2 * 86_400))

        #expect(deleted == 1)
        #expect(try await photos.storedPhotos().map(\.id) == [new])
    }

    /// Writes rows straight into the store, as a newer build or an old store could have left them.
    private func writeRows(_ rows: [ProgressEventRecord]) throws {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: DadSagaMigrationPlan.self,
            configurations: [
                ModelConfiguration(schema: schema, url: directory.appending(path: "DadSaga.store"), cloudKitDatabase: .none)
            ]
        )
        let context = ModelContext(container)
        rows.forEach(context.insert)
        try context.save()
    }
}
