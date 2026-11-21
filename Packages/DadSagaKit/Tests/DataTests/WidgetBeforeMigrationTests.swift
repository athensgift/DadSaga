import Foundation
import Testing
@testable import Data

/// After an update with a new schema, the widget can run before the app has migrated the store. Only the app migrates
/// (ADR-0023, ADR-0026): the widget, opening the older store read-only, must fail and leave every file as it was
/// (ADR-0034 §6). Checked with the real plan and copies of the stores versions 1, 3 and 4 wrote (ADR-0042 §2,
/// ADR-0044 §6, ADR-0048 §3, ADR-0051 §8).
@Suite("Widget before the app migrates", .serialized)
struct WidgetBeforeMigrationTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-widget-v3-" + UUID().uuidString)
    /// The database and its write-ahead log hold the saga. The `-shm` file is SQLite's index of the log, rewritten by
    /// every connection that opens the store, read-only ones too, so it is not compared.
    let storeFiles = ["DadSaga.store", "DadSaga.store-wal"]

    func storeContents() throws -> [String: Data] {
        var contents: [String: Data] = [:]
        for name in storeFiles {
            let url = directory.appending(path: name)
            if FileManager.default.fileExists(atPath: url.path()) { contents[name] = try Data(contentsOf: url) }
        }
        return contents
    }

    @Test("Given an older store, when the widget opens it at the current version, then it throws and the saga is unchanged",
          arguments: [StoreV1Fixture.directory, StoreV3Fixture.directory, StoreV4Fixture.directory, StoreV5Fixture.directory])
    func widgetFailsWithoutTouchingTheStore(fixture: URL) async throws {
        try StoreFiles.copy(from: fixture, to: directory)
        let before = try storeContents()

        let widget = LocalStore.live(in: directory, readOnly: true)

        await #expect(throws: (any Error).self) { try await widget.progress.fetchEvents() }
        #expect(before.count == 2)
        #expect(try storeContents() == before)
    }

    @Test("Given a version 1 store, when the widget fails, the app migrates and the widget asks again, then it reads it")
    func widgetReadsAfterMigration() async throws {
        try StoreFiles.copy(from: StoreV1Fixture.directory, to: directory)
        let widget = LocalStore.live(in: directory, readOnly: true)
        await #expect(throws: (any Error).self) { try await widget.progress.fetchEvents() }

        #expect(try await LocalStore.live(in: directory).progress.fetchEvents() == StoreV1Fixture.events)

        #expect(try await widget.progress.fetchEvents() == StoreV1Fixture.events)
        #expect(try await widget.profiles.fetchProfile() == StoreV1Fixture.profile)
    }

    @Test("Given a version 3 store, when the widget fails, the app migrates and the widget asks again, then it reads it")
    func widgetReadsVersion3AfterMigration() async throws {
        try StoreFiles.copy(from: StoreV3Fixture.directory, to: directory)
        let widget = LocalStore.live(in: directory, readOnly: true)
        await #expect(throws: (any Error).self) { try await widget.progress.fetchEvents() }

        #expect(try await LocalStore.live(in: directory).progress.fetchEvents() == StoreV3Fixture.events)

        #expect(try await widget.profiles.fetchProfile() == StoreV3Fixture.profile)
    }

    @Test("Given a version 4 store, when the widget fails, the app migrates and the widget asks again, then it reads it")
    func widgetReadsVersion4AfterMigration() async throws {
        try StoreFiles.copy(from: StoreV4Fixture.directory, to: directory)
        let widget = LocalStore.live(in: directory, readOnly: true)
        await #expect(throws: (any Error).self) { try await widget.progress.fetchEvents() }

        #expect(try await LocalStore.live(in: directory).progress.fetchEvents() == StoreV4Fixture.events)

        #expect(try await widget.profiles.fetchProfile() == StoreV4Fixture.profile)
    }
}

extension WidgetBeforeMigrationTests {
    @Test("Given a version 5 store, when the widget fails, the app migrates and the widget asks again, then it reads it")
    func widgetReadsVersion5AfterMigration() async throws {
        try StoreFiles.copy(from: StoreV5Fixture.directory, to: directory)
        let widget = LocalStore.live(in: directory, readOnly: true)
        await #expect(throws: (any Error).self) { try await widget.profiles.fetchProfile() }

        #expect(try await LocalStore.live(in: directory).profiles.fetchProfile() == StoreV5Fixture.profile)

        #expect(try await widget.profiles.fetchProfile() == StoreV5Fixture.profile)
        #expect(try await widget.progress.fetchEvents() == StoreV5Fixture.events)
    }
}

/// Copies a fixture store, so opening it read-write never changes the original.
enum StoreFiles {
    static func copy(from fixture: URL, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for name in ["DadSaga.store", "DadSaga.store-wal", "DadSaga.store-shm"] {
            try FileManager.default.copyItem(at: fixture.appending(path: name), to: directory.appending(path: name))
        }
    }
}
