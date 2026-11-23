import Application
import Domain
import Foundation
import Testing
@testable import Data

/// A photo is a record of its own (ADR-0065 §1, §2): sent once for the entry that lists it, deleted when the entry
/// stops listing it or goes, and placed under its own id, byte for byte, when it comes from another iPhone.
@Suite("Photos, in iCloud", .serialized)
struct PhotoSyncTests: SyncBench {
    let root = FileManager.default.temporaryDirectory.appending(path: "dadsaga-photos-" + UUID().uuidString)
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)

    func entry(_ entry: ProgressEvent, listing photoIDs: [String]) -> ProgressEvent {
        ProgressEvent(
            id: entry.id, kind: entry.kind, childID: entry.childID, date: entry.date, note: entry.note,
            photoIDs: photoIDs
        )
    }

    @Test("Given an entry and its photo from another iPhone, when they come, in either order, then the photo is stored")
    func aFetchedPhotoIsPlacedUnderItsID() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, mine) = try await started(on: cloud)
        let jpeg = try await phone.photos.storedData(id: mine.photoIDs[0])
        let file = root.appending(path: "from-the-other-iphone.jpg")
        try jpeg.write(to: file)
        let sent = await cloud.requests.count

        for reversed in [false, true] {
            await cloud.setDeliversInReverse(reversed)
            let photoID = UUID().uuidString
            let other = ProgressEvent(kind: .quest(id: "q1"), childID: nikos.id, date: .now, photoIDs: [photoID])
            let zones = SyncZones(family: try await phone.family())
            await cloud.write(ProgressEventRecord(event: other).syncRecord(fields: nil, zones: zones), as: "dad")
            var photo = try await record(.photo(photoID), ["entryID": .string(other.id.uuidString)], for: phone)
            photo.asset = file
            await cloud.write(photo, as: "dad")

            try await settle(phone)

            #expect(try await phone.photos.storedData(id: photoID) == jpeg)
            #expect(try await phone.store.progress.fetchEvents().contains(other))
            #expect(try await phone.ledger().knownPhotos()[photoID] == other.id)
        }
        // Nothing of it is sent back, at a resume either.
        await phone.coordinator.resume()
        try await settle(phone)
        #expect(await cloud.requests.count == sent)
    }

    @Test("Given an entry's photos in iCloud, when the dad removes one, then its record goes; deleting the entry takes the rest")
    func photosGoWithWhatListedThem() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, recorded) = try await started(on: cloud)
        let first = recorded.photoIDs[0]
        let second = try await phone.photos.save(try smallImage())

        try await phone.store.progress.update(entry(recorded, listing: [first, second]))
        try await settle(phone)
        #expect(try await phone.cloudRecord(.photo(second)) == ["entryID": .string(recorded.id.uuidString)])

        try await phone.store.progress.update(entry(recorded, listing: [second]))
        try await settle(phone)
        #expect(try await phone.cloudRecord(.photo(first)) == nil)
        #expect(try await phone.cloudRecord(.photo(second)) != nil)
        #expect(try await phone.cloudRecord(.entry(recorded.id))?["photoIDs"] == .strings([second]))

        try await phone.store.progress.delete(id: recorded.id)
        try await settle(phone)
        #expect(try await phone.cloudRecord(.photo(second)) == nil)
        #expect(try await phone.cloudRecord(.entry(recorded.id)) == nil)
        #expect(try await phone.ledger().knownPhotos().isEmpty)
        #expect(try await phone.ledger().pending().isEmpty)
    }

    @Test("Given an entry with a photo never sent, when the dad deletes the entry, then nothing of it reaches iCloud")
    func aPhotoThatOnlyWaitedIsDropped() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, _) = try await started(on: cloud)
        let before = try await phone.cloudNames()
        let photoID = try await phone.photos.save(try smallImage())
        let short = ProgressEvent(kind: .quest(id: "q1"), childID: nikos.id, date: .now, photoIDs: [photoID])

        try await phone.store.progress.add(short)
        await phone.coordinator.drain()
        try await phone.store.progress.delete(id: short.id)
        try await settle(phone)

        #expect(try await phone.cloudNames() == before)
        #expect(try await phone.ledger().pending().isEmpty)
        #expect(await phone.device.engine()?.pending.isEmpty == true)
    }
}
