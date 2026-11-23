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

/// Two phones and the copies between them, shared by the suites that test copies of the saga (ADR-0057).
protocol SagaCopyBench {
    var root: URL { get }
    var madeAt: Date { get }
}

extension SagaCopyBench {
    var lena: Child {
        Child(id: SagaCopyPeople.lenaID, name: "Λένα 🌟", birthDay: .day(2023, 11, 14), gender: .girl, skinTone: .medium)
    }
    var unborn: Child { Child(id: SagaCopyPeople.unbornID, name: "Μπέμπης", birthDay: nil, gender: .boy, skinTone: .dark) }
    /// A child removed from the family, kept to bring back or delete for good (ADR-0065 §4).
    var removed: Child { Child(id: SagaCopyPeople.removedID, name: "Ίρις", birthDay: .day(2022, 3, 1)) }

    func phone(_ name: String) -> Phone {
        let folder = root.appending(path: name)
        return Phone(
            store: LocalStore.live(in: folder.appending(path: "store")),
            photos: FilePhotoStore.moments(in: folder),
            files: AppleArchiveSagaCopyFiles(app: "test", folder: folder.appending(path: "tmp"), ),
            offers: MemoryOffers()
        )
    }

    func make(on phone: Phone) -> DefaultMakeSagaCopyUseCase {
        DefaultMakeSagaCopyUseCase(
            wholeSaga: phone.store.wholeSaga, sagaOffers: phone.offers, photoStore: phone.photos, files: phone.files
        )
    }

    func restore(on phone: Phone) -> DefaultRestoreSagaUseCase {
        DefaultRestoreSagaUseCase(
            wholeSaga: phone.store.wholeSaga, progressRepository: phone.store.progress, photoStore: phone.photos,
            sagaOffers: phone.offers, files: phone.files, schedule: NoSchedule(), notificationScheduler: NoNotifications()
        )
    }

    /// A saga with every kind of thing a copy carries: a born child and one not born yet, a quest, a boss and firsts;
    /// two ids the content no longer has and one from the future; notes in Greek with emoji; none to five photos; a
    /// hidden slot and a chosen item; a title kept; film offers answered; a removed child, and an entry with them by the
    /// partner.
    func fill(
        _ phone: Phone,
        kept: KeptStanding = KeptStanding(titleID: "t-new-to-the-journey", seenTitleID: "t-new-to-the-journey")
    ) async throws -> [String] {
        try await phone.store.profiles.create(PlayerProfile(
            id: SagaCopyPeople.dadID, children: [lena, unborn], heroClassID: "h-chef", dadSkinTone: .mediumDark,
            dadAppearance: DadAppearance(hair: .curly, hairColor: .grey, beard: .none, glasses: .round), hasPartner: false
        ))
        var photoIDs: [String] = []
        for side in [40, 60, 80, 100, 120, 140] {
            photoIDs.append(try await phone.photos.save(try png(width: side, height: side / 2)))
        }
        let events = [
            dads(.quest(id: "q-w2-car-seat"), childID: lena.id, date: madeAt.addingTimeInterval(-9_000.5)),
            dads(.boss(id: "b-w1-first-fever"), childID: lena.id, date: madeAt.addingTimeInterval(-8_000),
                 note: "Δύσκολη νύχτα 😅\nαλλά τα καταφέραμε", photoIDs: [photoIDs[0]]),
            dads(.quest(id: "q-w1-tummy-time"), childID: lena.id, date: madeAt.addingTimeInterval(-7_000)),
            dads(.first(id: "f-steps"), childID: lena.id, date: madeAt.addingTimeInterval(-6_000),
                 note: "", photoIDs: Array(photoIDs[1...5])),
            dads(.quest(id: "q-from-the-future"), childID: unborn.id, date: madeAt.addingTimeInterval(-5_000))
        ]
        for event in events { try await phone.store.progress.add(event) }
        _ = try await phone.store.outfit.setChoice(.hidden, for: .play)
        _ = try await phone.store.outfit.setChoice(.item("g-mug"), for: .care)
        let partners = ProgressEvent(
            authorID: SagaCopyPeople.partnerID, kind: .first(id: "f-smile"), childID: removed.id,
            date: madeAt.addingTimeInterval(-4_000), note: "Χαμόγελο"
        )
        var profile = try #require(try await phone.store.profiles.fetchProfile())
        profile.removedChildren = [removed]
        try await phone.store.wholeSaga.replaceAll(with: StoredSaga(
            profile: profile,
            events: try await phone.store.progress.fetchEvents() + [partners],
            outfit: try await phone.store.outfit.fetchOutfit(),
            kept: kept
        ))
        await phone.offers.markAnswered("lena/birthday/1")
        await phone.offers.markAnswered("lena/world/w2")
        return photoIDs
    }

    /// A real copy, then the store and photos of a phone that is about to import it.
    func copyAndTarget() async throws -> (url: URL, target: Phone) {
        let old = phone("old")
        _ = try await fill(old)
        let made = try await make(on: old).execute(on: madeAt) { _ in }
        let target = phone("target")
        let aris = PlayerProfile(children: [Child(name: "Άρης", birthDay: nil)], heroClassID: "h-coach")
        try await target.store.profiles.create(aris)
        return (made.url, target)
    }

    /// Opening `url` throws one of `errors`, and the target's saga and photos are as they were.
    func expectRefused(_ url: URL, on target: Phone, as errors: Set<SagaCopyError>) async throws {
        let before = try await target.store.wholeSaga.readAll()
        let photosBefore = try await target.photos.storedPhotos().map(\.id)
        do {
            _ = try await restore(on: target).open(fileAt: url) { _ in }
            Issue.record("The file was opened")
        } catch let error as SagaCopyError {
            #expect(errors.contains(error), "\(error)")
        }
        #expect(try await target.store.wholeSaga.readAll() == before)
        #expect(try await target.photos.storedPhotos().map(\.id) == photosBefore)
    }

    /// The entries of a real copy, to change one at a time.
    func entries() async throws -> (entries: [(String, Data)], target: Phone) {
        let (url, target) = try await copyAndTarget()
        return (try ArchiveFiles.entries(of: url), target)
    }

    /// An entry by the dad of `fill`'s saga.
    func dads(
        _ kind: ProgressEvent.Kind, childID: UUID, date: Date, note: String? = nil, photoIDs: [String] = []
    ) -> ProgressEvent {
        ProgressEvent(authorID: SagaCopyPeople.dadID, kind: kind, childID: childID, date: date, note: note, photoIDs: photoIDs)
    }

    func png(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        // Noise, so a copy's photos don't compress to nothing and a file spans many compression blocks.
        var random = SystemRandomNumberGenerator()
        for column in 0..<width {
            for row in 0..<height {
                let red = CGFloat.random(in: 0...1, using: &random)
                context.setFillColor(red: red, green: 0.6, blue: .random(in: 0...1, using: &random), alpha: 1)
                context.fill(CGRect(x: column, y: row, width: 1, height: 1))
            }
        }
        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        _ = CGImageDestinationFinalize(destination)
        return output as Data
    }
}

enum SagaCopyPeople {
    static let dadID = UUID()
    static let partnerID = UUID()
    static let lenaID = UUID()
    static let unbornID = UUID()
    static let removedID = UUID()
}

/// A phone: its store, its photos and the folder its copies go to.
struct Phone {
    let store: LocalStore
    let photos: FilePhotoStore
    let files: AppleArchiveSagaCopyFiles
    let offers: MemoryOffers
}

// MARK: - Helpers

actor MemoryOffers: SagaOfferRepository {
    private var answered: Set<String> = []
    func answeredOccasionIDs() async -> Set<String> { answered }
    func markAnswered(_ occasionID: String) async { answered.insert(occasionID) }
    func deleteAll() async { answered = [] }
}

struct NoSchedule: ScheduleWeeklyRemindersUseCase {
    func execute(on date: Date) async {}
}

struct NoNotifications: NotificationScheduler {
    func authorization() async -> NotificationAuthorization { .denied }
    func requestAuthorization() async -> Bool { false }
    func replacePending(with reminders: [PendingReminder]) async {}
    func removeDelivered() async {}
}

/// Reads and writes Apple Archive files entry by entry, so tests can make copies the app never would. Checksums are
/// recomputed on write, so only what a test changes on purpose is wrong.
enum ArchiveFiles {
    static func entries(of url: URL) throws -> [(String, Data)] {
        let file = try #require(ArchiveByteStream.fileStream(
            path: FilePath(url.path), mode: .readOnly, options: [], permissions: [.ownerReadWrite]
        ))
        defer { try? file.close() }
        let decompressed = try #require(ArchiveByteStream.decompressionStream(readingFrom: file))
        defer { try? decompressed.close() }
        let decoder = try #require(ArchiveStream.decodeStream(readingFrom: decompressed))
        defer { try? decoder.close() }
        var entries: [(String, Data)] = []
        while let header = try decoder.readHeader() {
            guard case .string(_, let path)? = header.field(forKey: .init("PAT")),
                  case .blob(_, let size, _)? = header.field(forKey: .init("DAT")) else { continue }
            var data = Data(count: Int(size))
            try data.withUnsafeMutableBytes { try decoder.readBlob(key: .init("DAT"), into: $0) }
            entries.append((path, data))
        }
        return entries
    }

    /// `entries` written as a copy. Unless told not to, `checksums.json` is recomputed over the entries before it, so
    /// only what a test changes on purpose is wrong.
    static func write(_ entries: [(String, Data)], in folder: URL, recomputingChecksums: Bool = true) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "made-by-hand-\(UUID().uuidString).dadsaga")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let file = try #require(ArchiveByteStream.fileStream(
            path: FilePath(url.path), mode: .writeOnly, options: [.truncate], permissions: [.ownerReadWrite]
        ))
        let compressed = try #require(ArchiveByteStream.compressionStream(using: .lzfse, writingTo: file))
        let encoder = try #require(ArchiveStream.encodeStream(writingTo: compressed))
        var hashes: [String: String] = [:]
        for (path, original) in entries {
            var data = original
            if path == "checksums.json", recomputingChecksums {
                data = try JSONEncoder().encode(SagaCopyChecksumsV1(sha256: hashes))
            }
            hashes[path] = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let header = ArchiveHeader()
            header.append(.string(key: .init("PAT"), value: path))
            header.append(.uint(key: .init("TYP"), value: UInt64(ArchiveHeader.EntryType.regularFile.rawValue)))
            header.append(.blob(key: .init("DAT"), size: UInt64(data.count)))
            try encoder.writeHeader(header)
            try data.withUnsafeBytes { try encoder.writeBlob(key: .init("DAT"), from: $0) }
        }
        try encoder.close()
        try compressed.close()
        try file.close()
        return url
    }
}
