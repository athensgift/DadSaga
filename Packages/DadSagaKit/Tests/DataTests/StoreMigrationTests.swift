import Domain
import Foundation
import Testing
@testable import Data

/// Moving a store to several photos per entry, through versions 2 and 3 (ADR-0042 §2).
@Suite("Store migration to several photos", .serialized)
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

    @Test("Given ten photos on an entry, when saved and fetched, then they come back in the same order")
    func tenPhotosKeepTheirOrder() async throws {
        let ids = (1...ProgressEvent.photoLimit).map { "photo-\(11 - $0)" }
        let event = ProgressEvent(kind: .first(id: "f1"), childID: UUID(), date: .distantPast, photoIDs: ids)
        let store = LocalStore.live(in: directory)

        try await store.progress.add(event)

        #expect(try await LocalStore.live(in: directory).progress.fetchEvents().first?.photoIDs == ids)
    }
}
