import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// The versioned store, and what happens when it cannot be opened (ADR-0026).
@Suite("Versioned store", .serialized)
struct StoreVersioningTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-versioning-" + UUID().uuidString)
    var storeURL: URL { directory.appending(path: "DadSaga.store") }

    /// A copy of the store written before versioned schemas: opening writes to it, so the original never is.
    func copyFixture() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for name in ["DadSaga.store", "DadSaga.store-wal", "DadSaga.store-shm"] {
            try FileManager.default.copyItem(
                at: StoreFixture.directory.appending(path: name),
                to: directory.appending(path: name)
            )
        }
    }

    /// Writes rows straight into a store, bypassing the repositories, then closes it.
    func writeRows(_ insert: (ModelContext) -> Void) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV1.self),
            migrationPlan: DadSagaMigrationPlan.self,
            configurations: [ModelConfiguration(url: storeURL, cloudKitDatabase: .none)]
        )
        let context = ModelContext(container)
        insert(context)
        try context.save()
    }

    @Test("Given a store written before versioned schemas, when the app opens it, then the family, events and wardrobe are there")
    func appOpensOldStore() async throws {
        try copyFixture()
        let store = LocalStore.live(in: directory)

        #expect(try await store.profiles.fetchProfile() == StoreFixture.profile)
        #expect(try await store.progress.fetchEvents() == StoreFixture.events)
        #expect(try await store.outfit.fetchOutfit() == StoreFixture.outfit)
    }

    @Test("Given a store written before versioned schemas, when the widget opens it read-only, then it reads the same")
    func widgetOpensOldStore() async throws {
        try copyFixture()
        let widget = LocalStore.live(in: directory, readOnly: true)

        #expect(try await widget.profiles.fetchProfile()?.children == StoreFixture.profile.children)
        #expect(try await widget.progress.fetchEvents() == StoreFixture.events)
    }

    @Test("Given the store folder cannot be created, when reading, then it throws; once it can, the same store opens")
    func retriesAfterFailure() async throws {
        try FileManager.default.createDirectory(at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not a folder".utf8).write(to: directory)
        let store = LocalStore.live(in: directory)

        await #expect(throws: (any Error).self) { try await store.profiles.fetchProfile() }
        #expect(try Data(contentsOf: directory) == Data("not a folder".utf8))

        try FileManager.default.removeItem(at: directory)
        #expect(try await store.profiles.fetchProfile() == nil)
    }

    @Test("Given a store file that is not a database, when reading, then it throws and the file is unchanged")
    func damagedFileIsLeftAlone() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let junk = Data(repeating: 0x42, count: 4096)
        try junk.write(to: storeURL)

        await #expect(throws: (any Error).self) { try await LocalStore.live(in: directory).progress.fetchEvents() }
        #expect(try Data(contentsOf: storeURL) == junk)
    }

    @Test("Given a stored event without a child, when fetching, then it is skipped")
    func eventWithoutChildIsSkipped() async throws {
        let kept = ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: .distantPast)
        try writeRows { context in
            context.insert(ProgressEventRecord(event: kept))
            context.insert(ProgressEventRecord(
                eventID: UUID(), kind: "quest", contentID: "q1", childID: nil, date: .now, note: nil, photoID: nil
            ))
        }

        #expect(try await LocalStore.live(in: directory).progress.fetchEvents() == [kept])
    }

    @Test("Given two profile rows and a child stored twice, when the family is saved, then one of each remains")
    func saveCleansDuplicates() async throws {
        let child = Child(name: "Λένα", birthDate: .distantPast)
        try writeRows { context in
            context.insert(ProfileRecord(heroClassID: "old", dadSkinTone: "light"))
            context.insert(ProfileRecord(heroClassID: "older", dadSkinTone: "dark"))
            context.insert(ChildRecord(child: child, order: 0))
            context.insert(ChildRecord(child: child, order: 1))
        }
        let store = LocalStore.live(in: directory)
        let profile = PlayerProfile(children: [child], heroClassID: "chef", dadSkinTone: .medium)

        try await store.profiles.save(profile)

        #expect(try await store.profiles.fetchProfile() == profile)
    }

    @Test("Given a saved family, when one child is renamed, one removed and one added, then exactly that family comes back")
    func saveUpdatesInPlace() async throws {
        let store = LocalStore.live(in: directory)
        let lena = Child(name: "Λένα", birthDate: .distantPast)
        let nikos = Child(name: "Νίκος", birthDate: .distantPast)
        try await store.profiles.save(PlayerProfile(children: [lena, nikos], heroClassID: "chef"))
        var renamed = lena
        renamed.name = "Ελένη"
        let anna = Child(name: "Άννα", birthDate: .now)
        let family = PlayerProfile(children: [anna, renamed], heroClassID: "chef")

        try await store.profiles.save(family)

        #expect(try await store.profiles.fetchProfile() == family)
    }
}
