import AppleArchive
import Application
import CoreGraphics
import CryptoKit
import Domain
import Foundation
import ImageIO
import SwiftData
import System
import Testing
import UniformTypeIdentifiers
@testable import Data

/// A copy of the saga through real stores, real photo files and real Apple Archive files (ADR-0057).
@Suite("A copy of the saga in a file", .serialized)
struct SagaCopyFilesTests: SagaCopyBench {
    let root = FileManager.default.temporaryDirectory.appending(path: "dadsaga-copy-" + UUID().uuidString)
    let madeAt = Date(timeIntervalSinceReferenceDate: 815_000_000.123_456)

    // MARK: Round trip

    @Test("Given a full saga, when it is exported and imported on another phone, then every screen reads it exactly")
    func roundTrip() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let old = phone("old")
        _ = try await fill(old)
        let original = try #require(try await old.store.wholeSaga.readAll())
        let made = try await make(on: old).execute(on: madeAt) { _ in }
        #expect(made.url.lastPathComponent.hasPrefix("DadSaga "))
        #expect(made.url.pathExtension == "dadsaga")
        #expect(made.byteCount > 0)

        let new = phone("new")
        let opened = try await restore(on: new).open(fileAt: made.url) { _ in }
        #expect(opened.childNames == ["Λένα 🌟", "Μπέμπης"])
        #expect(opened.madeAt == madeAt)
        try await restore(on: new).restore(opened, on: madeAt)

        let restored = try #require(try await new.store.wholeSaga.readAll())
        let renamed = Dictionary(uniqueKeysWithValues: zip(original.photoIDs, restored.photoIDs))
        #expect(restored == original.replacingPhotoIDs(renamed))
        #expect(Set(restored.photoIDs).isDisjoint(with: original.photoIDs))
        for (oldID, newID) in renamed {
            #expect(try await new.photos.storedData(id: newID) == old.photos.storedData(id: oldID))
        }
        #expect(try await new.store.profiles.fetchProfile() == original.profile)
        #expect(try await new.store.progress.fetchEvents() == restored.events)
        #expect(try await new.store.outfit.fetchOutfit() == original.outfit)
        #expect(try await new.store.standing.fetchKept() == original.kept)
        #expect(try await new.store.standing.fetchKept().gearIDs == nil)
        #expect(await new.offers.answeredOccasionIDs() == ["lena/birthday/1", "lena/world/w2"])
    }

    @Test("Given a saga started with titles, when it goes through a copy, then its gear stays none, not unfrozen")
    func emptyGearStaysEmpty() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let old = phone("old")
        _ = try await fill(old, kept: .fresh)
        let made = try await make(on: old).execute(on: madeAt) { _ in }

        let new = phone("new")
        try await restore(on: new).restore(try await restore(on: new).open(fileAt: made.url) { _ in }, on: madeAt)

        #expect(try await new.store.standing.fetchKept() == .fresh)
    }

    @Test("Given a phone with its own saga, when a copy is imported, then the old saga and its photos are gone")
    func importReplacesTheSagaOnThePhone() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let old = phone("old")
        _ = try await fill(old)
        let made = try await make(on: old).execute(on: madeAt) { _ in }
        let new = phone("new")
        let other = Child(name: "Άρης", birthDay: .day(2022, 1, 1))
        try await new.store.profiles.save(PlayerProfile(children: [other], heroClassID: "h-coach"))
        let photo = try await new.photos.save(try png(width: 30, height: 30))
        let sea = ProgressEvent(kind: .first(id: "f-sea"), childID: other.id, date: madeAt, photoIDs: [photo])
        try await new.store.progress.add(sea)
        await new.offers.markAnswered("aris/birthday/3")

        try await restore(on: new).restore(try await restore(on: new).open(fileAt: made.url) { _ in }, on: madeAt)

        #expect(try await new.store.profiles.fetchProfile()?.children.map(\.name) == ["Λένα 🌟", "Μπέμπης"])
        #expect(try await new.store.progress.fetchEvents().allSatisfy { $0.childID != other.id })
        #expect(try await new.photos.storedPhotos().map(\.id).contains(photo) == false)
        #expect(await new.offers.answeredOccasionIDs() == ["lena/birthday/1", "lena/world/w2"])
    }

    @Test("Given an imported saga, when the dad keeps playing, then every repository writes on it and reads it back")
    func repositoriesWorkAfterAReplace() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let old = phone("old")
        _ = try await fill(old)
        let made = try await make(on: old).execute(on: madeAt) { _ in }
        let new = phone("new")
        try await new.store.profiles.save(PlayerProfile(children: [Child(name: "Άρης", birthDay: nil)], heroClassID: "h-coach"))
        _ = try await new.store.progress.fetchEvents()
        _ = try await new.store.outfit.fetchOutfit()

        try await restore(on: new).restore(try await restore(on: new).open(fileAt: made.url) { _ in }, on: madeAt)
        var profile = try #require(try await new.store.profiles.fetchProfile())
        profile.children[0].name = "Λενάκι"
        try await new.store.profiles.save(profile)
        let quest = ProgressEvent(kind: .quest(id: "q-w1-skin-to-skin"), childID: lena.id, date: madeAt)
        try await new.store.progress.add(quest)
        _ = try await new.store.outfit.setChoice(.automatic, for: .play)
        try await new.store.standing.keep(titleID: "t-second", gearIDs: ["g-mug"])
        try await new.store.standing.markSeen(titleID: "t-second")

        #expect(try await new.store.profiles.fetchProfile()?.children.map(\.name) == ["Λενάκι", "Μπέμπης"])
        #expect(try await new.store.progress.fetchEvents().contains(quest))
        #expect(try await new.store.progress.fetchEvents().count == 6)
        #expect(try await new.store.outfit.fetchOutfit() == Outfit(choices: [.care: .item("g-mug")]))
        #expect(try await new.store.standing.fetchKept().seenTitleID == "t-second")
    }

    @Test("Given a store that can't be written, when replacing the saga fails, then every row is as it was")
    func failedReplaceKeepsEveryRow() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appending(path: "phone/store")
        let app = LocalStore.live(in: folder)
        try await app.profiles.save(PlayerProfile(children: [lena], heroClassID: "h-chef"))
        try await app.progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: lena.id, date: madeAt))
        let before = try await app.wholeSaga.readAll()
        let readOnly = LocalStore.live(in: folder, readOnly: true)
        let other = StoredSaga(
            profile: PlayerProfile(children: [unborn], heroClassID: "h-coach"), events: [], outfit: Outfit(), kept: .fresh
        )

        await #expect(throws: (any Error).self) { try await readOnly.wholeSaga.replaceAll(with: other) }

        #expect(try await readOnly.wholeSaga.readAll() == before)
    }

    @Test("Given an imported saga, when the widget opens the store read-only, then it reads the new family")
    func widgetReadsTheImportedSaga() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let old = phone("old")
        _ = try await fill(old)
        let made = try await make(on: old).execute(on: madeAt) { _ in }
        let folder = root.appending(path: "new/store")
        let new = Phone(
            store: LocalStore.live(in: folder), photos: FilePhotoStore.moments(in: root.appending(path: "new")),
            files: AppleArchiveSagaCopyFiles(app: "test", folder: root.appending(path: "new/tmp")), offers: MemoryOffers()
        )
        try await new.store.profiles.save(PlayerProfile(children: [Child(name: "Άρης", birthDay: nil)], heroClassID: "h-coach"))
        let widget = LocalStore.live(in: folder, readOnly: true)
        _ = try await widget.profiles.fetchProfile()

        try await restore(on: new).restore(try await restore(on: new).open(fileAt: made.url) { _ in }, on: madeAt)

        #expect(try await widget.profiles.fetchProfile()?.children.map(\.name) == ["Λένα 🌟", "Μπέμπης"])
    }

    @Test("Given a photo that can't be read, when exporting, then it fails and leaves no file behind")
    func failedExportLeavesNoFile() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appending(path: "tmp")
        let files = AppleArchiveSagaCopyFiles(app: "test", folder: folder)
        let copy = SagaCopy(
            saga: StoredSaga(
                profile: PlayerProfile(children: [lena], heroClassID: "h-chef"),
                events: [ProgressEvent(
                    kind: .first(id: "f-steps"), childID: lena.id, date: madeAt, photoIDs: [UUID().uuidString]
                )],
                outfit: Outfit(), kept: .fresh
            ),
            answeredOccasionIDs: [], madeAt: madeAt
        )
        struct Unreadable: Error {}

        await #expect(throws: Unreadable.self) {
            try await files.write(copy, photo: { _ in throw Unreadable() }, progress: { _ in })
        }

        let left = (try? FileManager.default.subpathsOfDirectory(atPath: folder.path)) ?? []
        #expect(left.isEmpty)
    }

    @Test("Given a copy made at 23:30 UTC, when naming it in Athens, then it is named for the day there")
    func fileNameFollowsThePhonesDay() throws {
        let lateEvening = try #require(ISO8601DateFormatter().date(from: "2026-11-22T23:30:00Z"))
        let athens = try #require(TimeZone(identifier: "Europe/Athens"))

        #expect(SagaCopyFormat.fileName(madeAt: lateEvening, in: athens) == "DadSaga 2026-11-23.dadsaga")
        #expect(SagaCopyFormat.fileName(madeAt: lateEvening, in: .gmt) == "DadSaga 2026-11-22.dadsaga")
    }

    @Test("Given copies made and a file opened, when temporary files are discarded, then the folder is empty")
    func temporaryFilesAreDiscarded() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let old = phone("old")
        _ = try await fill(old)
        let made = try await make(on: old).execute(on: madeAt) { _ in }
        #expect(FileManager.default.fileExists(atPath: made.url.path))

        await make(on: old).discardCopies()

        #expect(!FileManager.default.fileExists(atPath: made.url.path))
    }

}
