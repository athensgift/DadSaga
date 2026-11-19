import Foundation
import SwiftData
import Testing
@testable import Data

/// After an update with a new schema, the widget can run before the app has migrated the store. Only the app migrates
/// (ADR-0023, ADR-0026): the widget, opening the older store read-only, must fail and leave every file as it was.
/// `SchemaV2Draft` stands in for the first real V2 until it ships; then these tests use `.dadSaga`. The repositories
/// still read through version 1's record classes, which works only because the draft keeps their entity names.
@Suite("Widget before the app migrates", .serialized)
struct WidgetBeforeMigrationTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-widget-v2-" + UUID().uuidString)
    /// The database and its write-ahead log hold the saga. The `-shm` file is SQLite's index of the log, rewritten by
    /// every connection that opens the store, read-only ones too, so it is not compared.
    let storeFiles = ["DadSaga.store", "DadSaga.store-wal"]

    /// A store from the released version 1, written the way the app writes it. The caller keeps the returned store
    /// open: closing it moves the write-ahead log into the database, on SQLite's schedule, which would change the files
    /// in the middle of a comparison.
    func writeVersion1Store() async throws -> LocalStore {
        let app = LocalStore.live(in: directory)
        try await app.progress.add(StoreFixture.events[0])
        return app
    }

    func storeContents() throws -> [String: Data] {
        var contents: [String: Data] = [:]
        for name in storeFiles {
            let url = directory.appending(path: name)
            if FileManager.default.fileExists(atPath: url.path()) { contents[name] = try Data(contentsOf: url) }
        }
        return contents
    }

    @Test("Given a version 1 store, when the widget opens it at version 2, then it throws and the saga is unchanged")
    func widgetFailsWithoutTouchingTheStore() async throws {
        let version1 = try await writeVersion1Store()
        let before = try storeContents()

        let widget = LocalStore.live(in: directory, readOnly: true, versions: .draftV2)

        await #expect(throws: (any Error).self) { try await widget.progress.fetchEvents() }
        #expect(!before.isEmpty)
        #expect(try storeContents() == before)
        withExtendedLifetime(version1) {}
    }

    @Test("Given a version 1 store, when the app opens it at version 2, then it migrates and keeps the events")
    func appMigrates() async throws {
        _ = try await writeVersion1Store()

        let app = LocalStore.live(in: directory, readOnly: false, versions: .draftV2)

        #expect(try await app.progress.fetchEvents() == [StoreFixture.events[0]])
    }

    @Test("Given the app has migrated, when the widget opens the store at version 2, then it reads the events")
    func widgetReadsAfterMigration() async throws {
        _ = try await writeVersion1Store()
        _ = try await LocalStore.live(in: directory, readOnly: false, versions: .draftV2).progress.fetchEvents()

        let widget = LocalStore.live(in: directory, readOnly: true, versions: .draftV2)

        #expect(try await widget.progress.fetchEvents() == [StoreFixture.events[0]])
    }
}

extension StoreVersions {
    static var draftV2: StoreVersions {
        StoreVersions(current: Schema(versionedSchema: SchemaV2Draft.self), migrationPlan: DraftMigrationPlan.self)
    }
}

private enum DraftMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2Draft.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2Draft.self)]
    }
}

/// Version 1 with one more stored property, the smallest change that needs a migration.
private enum SchemaV2Draft: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ProfileRecord.self, ChildRecord.self, ProgressEventRecord.self, OutfitRecord.self]
    }

    @Model
    final class ProfileRecord {
        var heroClassID: String
        var dadSkinTone: String = "mediumLight"

        init(heroClassID: String, dadSkinTone: String) {
            self.heroClassID = heroClassID
            self.dadSkinTone = dadSkinTone
        }
    }

    @Model
    final class ChildRecord {
        var childID: UUID
        var name: String
        var birthDate: Date
        var gender: String
        var skinTone: String
        var order: Int
        /// New in the draft.
        var nickname: String?

        init(childID: UUID, name: String, birthDate: Date, gender: String, skinTone: String, order: Int) {
            self.childID = childID
            self.name = name
            self.birthDate = birthDate
            self.gender = gender
            self.skinTone = skinTone
            self.order = order
        }
    }

    @Model
    final class ProgressEventRecord {
        var eventID: UUID
        var kind: String
        var contentID: String
        var childID: UUID?
        var date: Date
        var note: String?
        var photoID: String?

        init(eventID: UUID, kind: String, contentID: String, childID: UUID?, date: Date, note: String?, photoID: String?) {
            self.eventID = eventID
            self.kind = kind
            self.contentID = contentID
            self.childID = childID
            self.date = date
            self.note = note
            self.photoID = photoID
        }
    }

    @Model
    final class OutfitRecord {
        var skill: String
        var choice: String

        init(skill: String, choice: String) {
            self.skill = skill
            self.choice = choice
        }
    }
}
