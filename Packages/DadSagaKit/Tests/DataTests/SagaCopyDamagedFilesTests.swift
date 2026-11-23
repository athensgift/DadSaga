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

    @Test("Given a copy cut short anywhere, when importing it, then it isn't whole and no photo is stored",
          arguments: [0.002, 0.3, 0.6, 0.9, 0.999])
    func cutShortCopiesAreIncomplete(keeping fraction: Double) async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let (url, target) = try await copyAndTarget()
        let data = try Data(contentsOf: url)
        try data.prefix(max(4, Int(Double(data.count) * fraction))).write(to: url)

        try await expectRefused(url, on: target, as: [.incomplete])
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

    @Test("Given an entry the copy doesn't name, a path out or a second manifest, when importing, then it is damaged",
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

    @Test("Given a saga.json from before ids and authors, when importing it, then it is damaged and nothing changes",
          arguments: [("hero", "id"), ("entries", "author"), ("children", "removed")])
    func copiesWithoutIDsOrAuthorsAreRefused(part: String, key: String) async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        var (entries, target) = try await entries()
        var saga = try #require(try JSONSerialization.jsonObject(with: entries[1].1) as? [String: Any])
        switch saga[part] {
        case var object as [String: Any]:
            #expect(object.removeValue(forKey: key) != nil)
            saga[part] = object
        case let list as [[String: Any]]:
            #expect(list.allSatisfy { $0[key] != nil })
            saga[part] = list.map { $0.filter { $0.key != key } }
        default:
            Issue.record("No \(part) in saga.json")
        }
        entries[1].1 = try JSONSerialization.data(withJSONObject: saga)

        try await expectRefused(try ArchiveFiles.write(entries, in: root), on: target, as: [.damaged])
    }

    @Test("Given a copy whose children are all removed, when importing it, then it is damaged and nothing changes")
    func everyChildRemovedIsRefused() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        var (entries, target) = try await entries()
        let saga = try #require(String(data: entries[1].1, encoding: .utf8))
        entries[1].1 = Data(saga.replacingOccurrences(of: #""removed":false"#, with: #""removed":true"#).utf8)
        #expect(entries[1].1 != Data(saga.utf8))

        try await expectRefused(try ArchiveFiles.write(entries, in: root), on: target, as: [.damaged])
    }

    @Test("Given a manifest larger than its limit, when importing, then it is refused before it is read")
    func oversizedEntriesAreRefused() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        var (entries, target) = try await entries()
        entries[0].1 += Data(repeating: 0x20, count: SagaCopyFormat.manifestLimit)

        try await expectRefused(try ArchiveFiles.write(entries, in: root), on: target, as: [.damaged])
    }

    // MARK: The format, pinned

    /// Every stored property of every entity, in format 1 or named as not travelling. A new column fails here until a
    /// format version decides where it goes (ADR-0057 §4).
    @Test("Given the current schema, when listing its stored properties, then format 1 covers every one")
    func formatCoversTheSchema() {
        let covered: [String: Set<String>] = [
            "ProfileRecord": ["profileID", "heroClassID", "dadSkinTone", "hairStyle", "hairColor", "beard", "glasses",
                              "hasPartner",
                              "heldTitleID", "seenTitleID"],
            "ChildRecord": ["childID", "name", "birthYear", "birthMonth", "birthDay", "gender", "skinTone", "order",
                            "isRemoved"],
            "ProgressEventRecord": ["eventID", "authorID", "kind", "contentID", "childID", "date", "note", "photoIDs"],
            "OutfitRecord": ["skill", "choice"]
        ]
        let schema = Schema(versionedSchema: CurrentSchema.self)

        #expect(Set(schema.entities.map(\.name)) == Set(covered.keys))
        for entity in schema.entities {
            #expect(Set(entity.storedPropertiesByName.keys) == covered[entity.name], "\(entity.name)")
        }
    }

    /// One row per id, which a sync that names rows by id needs (ADR-0065 §5). A store frozen without one would need a
    /// new version that removes duplicates first.
    @Test("Given the current schema, when listing its unique columns, then each entity's id is unique, and only it")
    func idsAreUnique() {
        let unique: [String: [[String]]] = [
            "ProfileRecord": [["profileID"]], "ChildRecord": [["childID"]], "ProgressEventRecord": [["eventID"]],
            "OutfitRecord": [["skill"]]
        ]
        for entity in Schema(versionedSchema: CurrentSchema.self).entities {
            #expect(entity.uniquenessConstraints == unique[entity.name], "\(entity.name)")
        }
    }

    @Test("Given format 1's names, when reading each one back, then it is the value it names")
    func formatNamesReadBack() throws {
        typealias Names = SagaCopyNamesV1
        #expect(try SkinTone.allCases.map { try Names.skinTone(Names.name(of: $0)) } == SkinTone.allCases)
        #expect(try Gender.allCases.map { try Names.gender(Names.name(of: $0)) } == Gender.allCases)
        #expect(try DadAppearance.Hair.allCases.map { try Names.hair(Names.name(of: $0)) } == DadAppearance.Hair.allCases)
        #expect(try DadAppearance.HairColor.allCases.map { try Names.hairColor(Names.name(of: $0)) }
            == DadAppearance.HairColor.allCases)
        #expect(try DadAppearance.Beard.allCases.map { try Names.beard(Names.name(of: $0)) } == DadAppearance.Beard.allCases)
        #expect(try DadAppearance.Glasses.allCases.map { try Names.glasses(Names.name(of: $0)) }
            == DadAppearance.Glasses.allCases)
        #expect(try Skill.allCases.map { try Names.skill(Names.name(of: $0)) } == Skill.allCases)
        let kinds: [ProgressEvent.Kind] = [.quest(id: "x"), .boss(id: "x"), .first(id: "x")]
        #expect(try kinds.map { try Names.kind(Names.names(of: $0).kind, contentID: "x") } == kinds)
    }

    /// Format 1's `saga.json` written out by hand: every key, and the wardrobe's two choices. It keeps the
    /// `standing.gearIDs` a `develop` build before ADR-0060 wrote, which is now read and ignored.
    @Test("Given format 1's saga.json by hand, old gearIDs and all, when reading it, then every key lands where meant")
    func handWrittenSagaReads() throws {
        let json = #"""
        {"answeredOccasionIDs":["x/birthday/1"],
         "children":[
           {"birthDay":"2024-02-29","gender":"girl","id":"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA","name":"Ελένη",
            "removed":false,"skinTone":"dark"},
           {"gender":"girl","id":"CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC","name":"Ίρις","removed":true,"skinTone":"medium"},
           {"gender":"boy","id":"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB","name":"Μπέμπης","removed":false,"skinTone":"light"}],
         "entries":[
           {"author":"F0000000-0000-0000-0000-00000000000F","childID":"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
            "contentID":"f-steps","date":790000000.5,
            "id":"E0000000-0000-0000-0000-000000000001","kind":"first","note":"Μπράβο",
            "photos":["11111111-1111-1111-1111-111111111111"]}],
         "hero":{"beard":"short","classID":"h-cool","glasses":"round","hair":"long","hairColor":"red",
                 "hasPartner":false,"id":"D0000000-0000-0000-0000-00000000000D","skinTone":"medium"},
         "standing":{"gearIDs":["g-mug"],"seenTitleID":"t-2","titleID":"t-3"},
         "wardrobe":[{"choice":"hidden","skill":"play"},{"choice":"item","itemID":"g-mug","skill":"care"}]}
        """#
        let eleni = Child(id: SagaCopyV1Fixture.id("AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"), name: "Ελένη",
                          birthDay: .day(2024, 2, 29), gender: .girl, skinTone: .dark)
        let baby = Child(id: SagaCopyV1Fixture.id("BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"), name: "Μπέμπης", birthDay: nil,
                         skinTone: .light)
        let iris = Child(id: SagaCopyV1Fixture.id("CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"), name: "Ίρις", birthDay: nil,
                         gender: .girl, skinTone: .medium)
        let madeAt = Date(timeIntervalSinceReferenceDate: 1)

        let copy = try JSONDecoder().decode(SagaCopySagaV1.self, from: Data(json.utf8)).toDomain(madeAt: madeAt)

        #expect(copy == SagaCopy(
            saga: StoredSaga(
                profile: PlayerProfile(
                    id: SagaCopyV1Fixture.id("D0000000-0000-0000-0000-00000000000D"),
                    children: [eleni, baby], heroClassID: "h-cool", dadSkinTone: .medium,
                    dadAppearance: DadAppearance(hair: .long, hairColor: .red, beard: .short, glasses: .round),
                    hasPartner: false
                ),
                removedChildren: [iris],
                events: [ProgressEvent(
                    id: SagaCopyV1Fixture.id("E0000000-0000-0000-0000-000000000001"),
                    authorID: SagaCopyV1Fixture.id("F0000000-0000-0000-0000-00000000000F"), kind: .first(id: "f-steps"),
                    childID: eleni.id, date: Date(timeIntervalSinceReferenceDate: 790_000_000.5), note: "Μπράβο",
                    photoIDs: ["11111111-1111-1111-1111-111111111111"]
                )],
                outfit: Outfit(choices: [.play: .hidden, .care: .item("g-mug")]),
                kept: KeptStanding(titleID: "t-3", seenTitleID: "t-2")
            ),
            answeredOccasionIDs: ["x/birthday/1"],
            madeAt: madeAt
        ))
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
