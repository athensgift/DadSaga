import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// Moving a store to several photos per entry, through versions 2 and 3 (ADR-0042 §2), and to the dad's look at
/// version 4 (ADR-0044 §6).
@Suite("Store migration", .serialized)
struct StoreMigrationTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-migration-" + UUID().uuidString)

    @Test("Given a store written by version 1, when the app opens it, then each photo is a one-item list")
    func version1PhotosBecomeLists() async throws {
        try StoreFiles.copy(from: StoreV1Fixture.directory, to: directory)
        let store = LocalStore.live(in: directory)

        let events = try await store.progress.fetchEvents()

        #expect(events == StoreV1Fixture.events)
        #expect(events.map(\.photoIDs) == [["photo-quest"], ["photo-boss"], ["photo-first"], []])
        #expect(try await store.profiles.fetchProfile() == StoreV1Fixture.profile)
    }

    @Test("Given a store written by version 3, when the app opens it, then everything is there and the dad looks as before")
    func version3GainsTheStandardLook() async throws {
        try StoreFiles.copy(from: StoreV3Fixture.directory, to: directory)
        let store = LocalStore.live(in: directory)

        let profile = try #require(try await store.profiles.fetchProfile())

        #expect(profile == StoreV3Fixture.profile)
        #expect(profile.dadAppearance == DadAppearance(hair: .short, hairColor: .black, beard: .full, glasses: .none))
        #expect(try await store.progress.fetchEvents() == StoreV3Fixture.events)
        #expect(try await store.outfit.fetchOutfit() == StoreV3Fixture.outfit)
    }

    @Test("Given a migrated version 3 store, when the dad chooses a look and the app opens it again, then the look is kept")
    func version3KeepsAChosenLook() async throws {
        try StoreFiles.copy(from: StoreV3Fixture.directory, to: directory)
        var profile = try #require(try await LocalStore.live(in: directory).profiles.fetchProfile())
        profile.dadAppearance = DadAppearance(hair: .curly, hairColor: .grey, beard: .none, glasses: .round)
        try await LocalStore.live(in: directory).profiles.save(profile)

        #expect(try await LocalStore.live(in: directory).profiles.fetchProfile() == profile)
    }

    @Test("Given a store written before versioned schemas, when the app opens it, then its photo is a one-item list")
    func storeBeforeVersion1Migrates() async throws {
        try StoreFiles.copy(from: StoreFixture.directory, to: directory)

        let events = try await LocalStore.live(in: directory).progress.fetchEvents()

        #expect(events.map(\.photoIDs) == [[], [], ["photo-1"]])
    }

    @Test("Given a migrated store, when it is opened again, then the photos are still there")
    func reopeningKeepsPhotos() async throws {
        try StoreFiles.copy(from: StoreV1Fixture.directory, to: directory)
        _ = try await LocalStore.live(in: directory).progress.fetchEvents()

        #expect(try await LocalStore.live(in: directory).progress.fetchEvents() == StoreV1Fixture.events)
    }

    @Test("Given a store left at version 2 with one row already copied, when the app opens it, then that row is kept")
    func resumesFromVersion2() async throws {
        try StoreFiles.copy(from: StoreV1Fixture.directory, to: directory)
        let quest = StoreV1Fixture.events[0].id
        let copiedAtVersion2 = try openAtVersion2 { records in
            var copied: [[String]] = []
            for record in records {
                copied.append(record.photoIDs)
                if record.eventID == quest { record.photoIDs = ["x", "y"] }
            }
            return copied
        }
        #expect(copiedAtVersion2 == [[], [], [], []])

        let events = try await LocalStore.live(in: directory).progress.fetchEvents()

        #expect(events.map(\.photoIDs) == [["x", "y"], ["photo-boss"], ["photo-first"], []])
    }

    /// Migrates the store only as far as version 2, lets `change` edit its events, saves and closes it: a launch that
    /// stopped between the two stages. Returns what `change` returns.
    private func openAtVersion2<T>(_ change: ([SchemaV2.ProgressEventRecord]) -> T) throws -> T {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: UpToVersion2.self,
            configurations: [
                ModelConfiguration(schema: schema, url: directory.appending(path: "DadSaga.store"), cloudKitDatabase: .none)
            ]
        )
        let context = ModelContext(container)
        let result = change(try context.fetch(FetchDescriptor<SchemaV2.ProgressEventRecord>()))
        try context.save()
        return result
    }
}

/// The real plan's first stage alone.
private enum UpToVersion2: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)] }
}
