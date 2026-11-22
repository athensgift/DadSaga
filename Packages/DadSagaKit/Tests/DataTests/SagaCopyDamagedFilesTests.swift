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

/// Files that aren't whole copies, and the format's own rules: refused before anything changes (ADR-0057 §4, §7).
@Suite("A file that isn't a whole copy", .serialized)
struct SagaCopyDamagedFilesTests: SagaCopyBench {
    let root = FileManager.default.temporaryDirectory.appending(path: "dadsaga-damaged-" + UUID().uuidString)
    let madeAt = Date(timeIntervalSinceReferenceDate: 815_000_000)

    @Test("Given a copy cut short anywhere, when importing it, then it is refused and nothing changes",
          arguments: [0.05, 0.3, 0.6, 0.9, 0.999])
    func cutShortCopiesAreRefused(keeping fraction: Double) async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let (url, target) = try await copyAndTarget()
        let data = try Data(contentsOf: url)
        try data.prefix(Int(Double(data.count) * fraction)).write(to: url)

        try await expectRefused(url, on: target, as: [.incomplete, .damaged, .notACopy])
    }

    @Test("Given a copy with a byte changed, when importing it, then it is refused and nothing changes")
    func changedCopiesAreRefused() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let (url, target) = try await copyAndTarget()
        var data = try Data(contentsOf: url)
        data[data.count * 2 / 3] ^= 0xFF
        try data.write(to: url)

        try await expectRefused(url, on: target, as: [.incomplete, .damaged])
    }

    @Test("Given a photo renamed .dadsaga, when importing it, then it isn't a copy")
    func otherFilesAreNotCopies() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let target = phone("target")
        let url = root.appending(path: "photo.dadsaga")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try png(width: 20, height: 20).write(to: url)

        try await expectRefused(url, on: target, as: [.notACopy])
    }

    @Test("Given a file that isn't there, when importing it, then it can't be read")
    func missingFilesAreUnreadable() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try await expectRefused(root.appending(path: "nowhere.dadsaga"), on: phone("target"), as: [.unreadable])
    }

    @Test("Given a copy from a newer format, when importing it, then it asks for an update and stores no photo")
    func newerFormatIsRefused() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        var (entries, target) = try await entries()
        entries[0].1 = Data(#"{"kind":"app.dadsaga.saga-copy","formatVersion":2,"somethingNew":true}"#.utf8)

        try await expectRefused(try ArchiveFiles.write(entries, in: root), on: target, as: [.newerFormat])
    }

    @Test("Given a copy whose checksums don't match, when importing it, then it is damaged")
    func wrongChecksumIsRefused() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        var (entries, target) = try await entries()
        let photo = try #require(entries.firstIndex { $0.0.hasPrefix("photos/") })
        entries[photo].1 = try png(width: 33, height: 33)

        let file = try ArchiveFiles.write(entries, in: root, recomputingChecksums: false)
        try await expectRefused(file, on: target, as: [.damaged])
    }

    @Test("Given an entry the copy doesn't name, a path out of the folder or a second manifest, then it is damaged",
          arguments: ["photos/../../escape.jpg", "photos/\(UUID().uuidString).jpg", "manifest.json", "notes.txt"])
    func strayEntriesAreRefused(path: String) async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        var (entries, target) = try await entries()
        entries.insert((path, Data("x".utf8)), at: 2)
        // Apple Archive itself won't read a path that climbs out, so that file stops reading like one cut short.
        let refusals: Set<SagaCopyError> = path.contains("..") ? [.damaged, .incomplete] : [.damaged]

        try await expectRefused(try ArchiveFiles.write(entries, in: root), on: target, as: refusals)
    }

    @Test("Given a copy missing one of its photos, when importing it, then it is damaged")
    func missingPhotoIsRefused() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        var (entries, target) = try await entries()
        entries.remove(at: try #require(entries.firstIndex { $0.0.hasPrefix("photos/") }))

        try await expectRefused(try ArchiveFiles.write(entries, in: root), on: target, as: [.damaged])
    }

    @Test("Given a saga.json with an unknown hair style, when importing it, then it is damaged, never guessed")
    func unknownValuesAreRefused() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        var (entries, target) = try await entries()
        let saga = try #require(String(data: entries[1].1, encoding: .utf8))
        entries[1].1 = Data(saga.replacingOccurrences(of: #""hair":"curly""#, with: #""hair":"mohawk""#).utf8)
        #expect(entries[1].1 != Data(saga.utf8))

        try await expectRefused(try ArchiveFiles.write(entries, in: root), on: target, as: [.damaged])
    }

    // MARK: The format, pinned

    /// Every stored property of every entity, in format 1 or named as not travelling. A new column fails here until a
    /// format version decides where it goes (ADR-0057 §4).
    @Test("Given the current schema, when listing its stored properties, then format 1 covers every one")
    func formatCoversTheSchema() {
        let covered: [String: Set<String>] = [
            "ProfileRecord": ["heroClassID", "dadSkinTone", "hairStyle", "hairColor", "beard", "glasses", "hasPartner",
                              "heldTitleID", "seenTitleID", "keptGearIDs"],
            "ChildRecord": ["childID", "name", "birthYear", "birthMonth", "birthDay", "gender", "skinTone", "order"],
            "ProgressEventRecord": ["eventID", "kind", "contentID", "childID", "date", "note", "photoIDs"],
            "OutfitRecord": ["skill", "choice"]
        ]
        let schema = Schema(versionedSchema: CurrentSchema.self)

        #expect(Set(schema.entities.map(\.name)) == Set(covered.keys))
        for entity in schema.entities {
            #expect(Set(entity.storedPropertiesByName.keys) == covered[entity.name], "\(entity.name)")
        }
    }

    @Test("Given format 1, when naming the Domain's values, then each name is the one format 1 was released with")
    func formatNamesArePinned() {
        #expect(SkinTone.allCases.map(SagaCopyNamesV1.name(of:)) == ["light", "mediumLight", "medium", "mediumDark", "dark"])
        #expect(Gender.allCases.map(SagaCopyNamesV1.name(of:)) == ["boy", "girl"])
        #expect(DadAppearance.Hair.allCases.map(SagaCopyNamesV1.name(of:)) == ["short", "curly", "long", "shaved"])
        #expect(DadAppearance.HairColor.allCases.map(SagaCopyNamesV1.name(of:)) == ["black", "brown", "blond", "red", "grey"])
        #expect(DadAppearance.Beard.allCases.map(SagaCopyNamesV1.name(of:)) == ["none", "short", "full"])
        #expect(DadAppearance.Glasses.allCases.map(SagaCopyNamesV1.name(of:)) == ["none", "round"])
        #expect(Skill.allCases.map(SagaCopyNamesV1.name(of:)) == ["care", "play", "patience", "resilience"])
        let kinds: [ProgressEvent.Kind] = [.quest(id: "x"), .boss(id: "x"), .first(id: "x")]
        #expect(kinds.map { SagaCopyNamesV1.names(of: $0).kind } == ["quest", "boss", "first"])
    }

    // MARK: Photos

    @Test("Given a stored JPEG, when adopting it, then it is kept byte for byte under a new id, with today's date")
    func adoptKeepsTheBytes() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let photos = FilePhotoStore.moments(in: root)
        let original = try await photos.storedData(id: try await photos.save(try png(width: 64, height: 48)))

        let id = try await photos.adopt(original)

        #expect(try await photos.storedData(id: id) == original)
        let saved = try #require(try await photos.storedPhotos().first { $0.id == id }?.savedAt)
        #expect(abs(saved.timeIntervalSinceNow) < 60)
    }

    @Test("Given a PNG or data that isn't an image, when adopting it, then it is refused")
    func adoptRefusesOtherFiles() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let photos = FilePhotoStore.moments(in: root)

        await #expect(throws: FilePhotoStore.PhotoError.notAnImage) { try await photos.adopt(try png(width: 10, height: 10)) }
        await #expect(throws: FilePhotoStore.PhotoError.notAnImage) { try await photos.adopt(Data("not a photo".utf8)) }
        #expect(try await photos.storedPhotos().isEmpty)
    }

}
