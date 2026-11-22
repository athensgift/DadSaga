import Domain
import Foundation
import SQLite3
import SwiftData
import Testing
@testable import Data

/// An older shape: `hasPartner` and `childID` optional, and a column `SchemaV1` doesn't have.
enum OlderSchema: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(0, 9, 0) }

    static var models: [any PersistentModel.Type] {
        [ProfileRecord.self, ChildRecord.self, ProgressEventRecord.self, OutfitRecord.self]
    }

    @Model
    final class ProfileRecord {
        var heroClassID: String
        var dadSkinTone: String = "mediumLight"
        var hairStyle: String?
        var hairColor: String?
        var beard: String?
        var glasses: String?
        var hasPartner: Bool?
        var heldTitleID: String?
        var seenTitleID: String?
        var keptGearIDs: [String]?

        init(heroClassID: String) {
            self.heroClassID = heroClassID
        }
    }

    @Model
    final class ChildRecord {
        var childID: UUID
        var name: String
        var birthYear: Int?
        var birthMonth: Int?
        var birthDay: Int?
        var gender: String
        var skinTone: String
        var order: Int

        init(childID: UUID) {
            self.childID = childID
            name = "Ελένη"
            gender = "girl"
            skinTone = "light"
            order = 0
        }
    }

    @Model
    final class ProgressEventRecord {
        var eventID = UUID()
        var kind = "quest"
        var contentID = "q1"
        var childID: UUID?
        var date = Date(timeIntervalSince1970: 1_790_000_000)
        var note: String?
        var photoIDs: [String] = []

        init(childID: UUID?) {
            self.childID = childID
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

/// A store written in a shape `SchemaV1` no longer has, as a `develop` build before ADR-0060 left it: what the app and
/// the widget do with it (ADR-0060 §6). Made here from a test-only schema, so no binary fixture is needed.
@Suite("A store from an older shape", .serialized)
struct OlderStoreTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-older-" + UUID().uuidString)
    let child = UUID()

    /// Writes a saga in the older shape, its event's child as given, then folds the write-ahead log into the store, so
    /// the writer's own closing, whenever it comes, can't change the files the test compares.
    func writeOlderStore(eventChild: UUID?) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try autoreleasepool {
            let schema = Schema(versionedSchema: OlderSchema.self)
            let url = directory.appending(path: "DadSaga.store")
            let container = try ModelContainer(
                for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]
            )
            let context = ModelContext(container)
            let profile = OlderSchema.ProfileRecord(heroClassID: "h-cool")
            profile.hairStyle = "short"
            profile.hairColor = "brown"
            profile.beard = "full"
            profile.glasses = "none"
            profile.hasPartner = true
            profile.keptGearIDs = ["g-burp-cloth"]
            context.insert(profile)
            context.insert(OlderSchema.ChildRecord(childID: child))
            context.insert(OlderSchema.ProgressEventRecord(childID: eventChild))
            try context.save()
        }
        var database: OpaquePointer?
        defer { sqlite3_close(database) }
        let url = directory.appending(path: "DadSaga.store")
        guard sqlite3_open(url.path(), &database) == SQLITE_OK,
              sqlite3_busy_timeout(database, 5_000) == SQLITE_OK,
              sqlite3_exec(database, "PRAGMA wal_checkpoint(TRUNCATE)", nil, nil, nil) == SQLITE_OK
        else { throw CocoaError(.fileWriteUnknown) }
    }

    /// The store's files as they are on disk now. An empty log is the same as none.
    func storeFiles() throws -> [String: Data] {
        var files: [String: Data] = [:]
        for name in ["DadSaga.store", "DadSaga.store-wal"] {
            let url = directory.appending(path: name)
            guard FileManager.default.fileExists(atPath: url.path()) else { continue }
            let data = try Data(contentsOf: url)
            if !data.isEmpty { files[name] = data }
        }
        return files
    }

    @Test("Given a store in an older shape, when the widget opens it read-only, then it throws and the store is unchanged")
    func widgetLeavesAnOlderStoreAlone() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeOlderStore(eventChild: child)
        let before = try storeFiles()

        await #expect(throws: (any Error).self) {
            try await LocalStore.live(in: directory, readOnly: true).progress.fetchEvents()
        }
        #expect(try storeFiles() == before)
    }

    @Test("Given an older store with nil in a column SchemaV1 requires, when the app opens it, then it throws")
    func appRefusesANilInARequiredColumn() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeOlderStore(eventChild: nil)
        let before = try storeFiles()

        await #expect(throws: (any Error).self) { try await LocalStore.live(in: directory).progress.fetchEvents() }
        #expect(try storeFiles() == before)
    }
}
