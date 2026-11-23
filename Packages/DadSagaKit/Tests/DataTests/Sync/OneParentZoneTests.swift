import Application
import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// What can go under one parent's sync (ADR-0065 §4): a record or a zone that is no longer there, an iCloud with no
/// room, the Apple Account signing out or changing, and a zone that goes by itself. None of it ever deletes the saga
/// on the iPhone, and nothing is uploaded again by itself where the parent took it away.
@Suite("Zones, the account and room, for one parent", .serialized)
struct OneParentZoneTests: SyncBench {
    let root = FileManager.default.temporaryDirectory.appending(path: "dadsaga-zones-" + UUID().uuidString)
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)

    func rename(_ child: Child, to name: String, on phone: SyncPhone) async throws {
        var renamed = child
        renamed.name = name
        try await phone.store.profiles.save(FamilyEdit(changed: [ChildEdit(child: renamed, fields: [.name])]))
    }

    func names(on phone: SyncPhone) async throws -> [String] {
        try #require(try await phone.store.profiles.fetchProfile()).children.map(\.name)
    }

    @Test("Given an entry deleted on another iPhone, when this one edits it, then the edit waits and the deletion wins")
    func aDeletionWinsOverAnEdit() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, entry) = try await started(on: cloud)
        await cloud.delete(.entry(entry.id), in: try await phone.family(), as: "dad")

        try await phone.store.progress.update(ProgressEvent(
            id: entry.id, kind: entry.kind, childID: entry.childID, date: entry.date, note: "άλλο",
            photoIDs: entry.photoIDs
        ))
        try await phone.sendChanges()

        // The zone has no such record: nothing says yet whether it was deleted, so the row stays and the change waits.
        #expect(try await phone.store.progress.fetchEvents().map(\.note) == ["άλλο"])
        #expect(try await phone.ledger().pending().map(\.behindFetch) == [true])

        try await phone.fetch()

        // The entry goes with its photo's file, and nothing waits for it any more: only the title it had earned him,
        // kept before it went.
        #expect(try await phone.store.progress.fetchEvents().isEmpty)
        #expect(try await phone.photos.storedPhotos().isEmpty)
        #expect(try await phone.ledger().pending().map(\.name) == [.hero(.testDad)])
        try await settle(phone)
        #expect(try await phone.cloudRecord(.entry(entry.id)) == nil)
        #expect(try await phone.cloudRecord(.hero(.testDad))?["heldTitleID"] == .string("t1"))
        #expect(try await phone.ledger().pending().isEmpty)
    }

    @Test("Given an entry deleted in iCloud with no deletion reported here, when the dad edits it, then it goes back whole")
    func anEditWithNoDeletionReportedIsSentAsNew() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, entry) = try await started(on: cloud)
        // Signed out and in again, the engine starts from nothing: its fetch brings what is there, and no deletion.
        await phone.device.signOut()
        await cloud.delete(.entry(entry.id), in: try await phone.family(), as: "dad")
        await phone.device.signIn("dad")

        try await phone.store.progress.update(ProgressEvent(
            id: entry.id, kind: entry.kind, childID: entry.childID, date: entry.date, note: "άλλο",
            photoIDs: entry.photoIDs
        ))
        try await settle(phone)

        // Never lost, at worst back (ADR-0065 §2): a record with every field, not only the note that changed.
        #expect(try await phone.store.progress.fetchEvents().map(\.note) == ["άλλο"])
        let record = try #require(try await phone.cloudRecord(.entry(entry.id)))
        #expect(record["note"] == .string("άλλο"))
        #expect(record["childID"] == .string(lena.id.uuidString))
        #expect(record["photoIDs"] == .strings(entry.photoIDs))
        #expect(try await phone.ledger().pending().isEmpty)
    }

    @Test("Given zones made again after a reset, when this iPhone saves on old system fields, then all is sent as new")
    func aZoneMadeAgainGetsEverythingAsNew() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, entry) = try await started(on: cloud)
        let family = try await phone.family()
        let before = try await phone.cloudNames()
        await cloud.resetEncryptedData("dad")
        await cloud.saveZone(.personal, as: "dad")
        await cloud.saveZone(family, as: "dad")

        try await rename(lena, to: "Ελένη", on: phone)
        try await phone.sendChanges()

        // `unknownItem` is not a deletion: a zone made again answers stale system fields the same way.
        #expect(try await names(on: phone) == ["Ελένη", "Νίκος"])
        #expect(try await phone.store.progress.fetchEvents() == [entry])

        try await settle(phone)

        #expect(try await phone.cloudNames() == before)
        #expect(try await phone.cloudRecord(.child(lena.id))?["name"] == .string("Ελένη"))
        #expect(try await phone.cloudRecord(.child(nikos.id))?["name"] == .string("Νίκος"))
        #expect(try await phone.ledger().pending().isEmpty)
        #expect(try await names(on: phone) == ["Ελένη", "Νίκος"])
    }

    @Test("Given the account's encrypted data reset, when this iPhone fetches, then both zones are made again, whole")
    func encryptedDataResetIsUploadedAgain() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, entry) = try await started(on: cloud)
        let family = try await phone.family()
        let before = try await phone.cloudNames()
        await cloud.resetEncryptedData("dad")
        #expect(await cloud.zones(of: "dad").isEmpty)

        try await settle(phone)

        #expect(Set(await cloud.zones(of: "dad")) == [.personal, family])
        #expect(try await phone.cloudNames() == before)
        #expect(await cloud.asset(of: .photo(entry.photoIDs[0]), in: family, of: "dad") != nil)
        #expect(try await phone.cloudRecord(.hero(.testDad))?["classID"] == .string("h-cool"))
        #expect(try await phone.store.progress.fetchEvents() == [entry])
        #expect(await phone.coordinator.status() == ShareStatus(sharing: .alone))
    }

    @Test("Given an iCloud with no room, when the dad records, then the changes wait; with room, a resume sends them")
    func aFullICloudWaits() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, entry) = try await started(on: cloud)
        await cloud.setQuota("dad", bytes: await cloud.usage(of: "dad") + 20)
        let photoID = try await phone.photos.save(try smallImage())
        let big = ProgressEvent(
            kind: .quest(id: "q1"), childID: nikos.id, date: entry.date.addingTimeInterval(60),
            note: String(repeating: "σ", count: 200), photoIDs: [photoID]
        )

        try await phone.store.progress.add(big)
        try await settle(phone)

        let full = ShareStatus(sharing: .alone, waiting: .iCloudFull(isPartners: false))
        #expect(await phone.coordinator.status() == full)
        #expect(try await phone.store.progress.fetchEvents() == [entry, big])
        #expect(Set(try await phone.ledger().pending().map(\.name)) == [.entry(big.id), .photo(photoID)])
        #expect(try await phone.cloudRecord(.entry(big.id)) == nil)
        // What he changes meanwhile waits with it.
        try await rename(lena, to: "Ελένη", on: phone)
        try await settle(phone)
        #expect(try await phone.cloudRecord(.child(lena.id))?["name"] == .string("Λένα"))

        await cloud.setQuota("dad", bytes: nil)
        await phone.coordinator.resume()
        try await settle(phone)

        #expect(await phone.coordinator.status() == ShareStatus(sharing: .alone))
        #expect(try await phone.cloudRecord(.entry(big.id))?["note"] == .string(big.note ?? ""))
        #expect(try await phone.cloudRecord(.photo(photoID)) == ["entryID": .string(big.id.uuidString)])
        #expect(try await phone.cloudRecord(.child(lena.id))?["name"] == .string("Ελένη"))
        #expect(try await phone.ledger().pending().isEmpty)
    }

    @Test("Given a sign-out, when the dad edits, then everything is kept and the same account coming back sends it")
    func aSignOutWaitsForTheSameAccount() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, entry) = try await started(on: cloud)

        await phone.device.signOut()
        try await rename(lena, to: "Ελένη", on: phone)
        await phone.coordinator.drain()

        #expect(await phone.coordinator.status() == ShareStatus(sharing: .alone, waiting: .signedOut))
        #expect(try await phone.ledger().pending().map(\.name) == [.child(lena.id)])
        #expect(await phone.device.engine()?.pending.isEmpty == true)
        #expect(try await phone.store.progress.fetchEvents() == [entry])

        await phone.device.signIn("dad")
        try await settle(phone)

        #expect(await phone.coordinator.status() == ShareStatus(sharing: .alone))
        #expect(await cloud.records(in: try await phone.family(), of: "dad")[.child(lena.id)]?["name"] == .string("Ελένη"))
        #expect(try await names(on: phone) == ["Ελένη", "Νίκος"])
        #expect(try await phone.ledger().pending().isEmpty)
    }

    @Test("Given another Apple Account signed in, when the dad edits, then sync is off and nothing goes into that iCloud")
    func anotherAccountTurnsSyncOff() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, entry) = try await started(on: cloud)
        let family = try await phone.family()
        let before = await cloud.records(in: family, of: "dad")

        await phone.device.switchAccount(to: "other")
        #expect(await phone.coordinator.status() == ShareStatus(sharing: .off))
        try await rename(lena, to: "Ελένη", on: phone)
        await phone.coordinator.resume()
        try await phone.send()

        #expect(try await phone.ledger().settings().offReason == .otherAccount)
        #expect(await cloud.zones(of: "other").isEmpty)
        #expect(await cloud.records(in: family, of: "dad") == before)
        #expect(try await names(on: phone) == ["Ελένη", "Νίκος"])
        #expect(try await phone.store.progress.fetchEvents() == [entry])

        // Only the parent turning iCloud on for that account sends the saga there, into a family zone of its own.
        #expect(try await phone.coordinator.turnOn() == .turnedOn)
        try await settle(phone)
        let theirs = try await phone.family()
        #expect(theirs != family)
        #expect(await cloud.records(in: theirs, of: "other")[.child(lena.id)]?["name"] == .string("Ελένη"))
        #expect(await cloud.records(in: family, of: "dad") == before)
    }

    @Test("Given the account changed while the app was closed, when it resumes, then sync is off before anything is sent")
    func anAccountChangedWhileClosed() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, _) = try await started(on: cloud)
        try await rename(lena, to: "Ελένη", on: phone)
        await phone.coordinator.drain()

        let again = phone.relaunched()
        await again.device.switchAccount(to: "other")
        await again.coordinator.resume()

        #expect(await again.coordinator.status() == ShareStatus(sharing: .off))
        #expect(again.device.engines.isEmpty)
        #expect(await cloud.zones(of: "other").isEmpty)
        #expect(try await names(on: again) == ["Ελένη", "Νίκος"])
    }

    @Test("Given DadSaga's data deleted in iCloud's settings, when this iPhone fetches, then sync is off for good")
    func aPurgeTurnsSyncOff() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, entry) = try await started(on: cloud)

        await cloud.purge("dad")
        try await phone.fetch()
        try await rename(lena, to: "Ελένη", on: phone)
        await phone.coordinator.resume()
        try await phone.send()

        #expect(await phone.coordinator.status() == ShareStatus(sharing: .off))
        #expect(try await phone.ledger().settings().offReason == .purged)
        #expect(await cloud.zones(of: "dad").isEmpty)
        #expect(try await names(on: phone) == ["Ελένη", "Νίκος"])
        #expect(try await phone.store.progress.fetchEvents() == [entry])
        #expect(try await phone.photos.storedPhotos().map(\.id) == entry.photoIDs)
    }

    @Test("Given the family's zone deleted by another iPhone, when this one fetches, then sync is off here and the saga stays")
    func aZoneDeletedElsewhereTurnsSyncOff() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, entry) = try await started(on: cloud)

        await cloud.deleteZone(try await phone.family(), by: "dad")
        try await phone.fetch()
        try await phone.send()

        #expect(await phone.coordinator.status() == ShareStatus(sharing: .off))
        #expect(try await phone.ledger().settings().offReason == .zoneDeleted)
        #expect(await cloud.zones(of: "dad") == [.personal])
        #expect(try await names(on: phone) == ["Λένα", "Νίκος"])
        #expect(try await phone.store.progress.fetchEvents() == [entry])
    }

    @Test("Given sync off after it was on, when a child is deleted for good, then a resume keeps their id before trimming")
    func aChildDeletedForGoodWhileOffIsRemembered() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, _) = try await started(on: cloud)
        await cloud.purge("dad")
        try await phone.fetch()

        try await phone.store.profiles.save(FamilyEdit(removedIDs: [nikos.id]))
        _ = try await phone.store.profiles.deleteForGood(childID: nikos.id)
        await phone.coordinator.resume()

        #expect(try await phone.ledger().goneIDs() == [nikos.id])
        #expect(try storeHistory(at: phone.storeURL).isEmpty)

        // The zones this iPhone builds when iCloud is turned on again carry the marker, never the child.
        #expect(try await phone.coordinator.turnOn() == .turnedOn)
        try await settle(phone)
        #expect(try await phone.cloudRecord(.child(nikos.id)) == ["gone": .bool(true)])
        #expect(try await phone.cloudRecord(.child(lena.id))?["name"] == .string("Λένα"))
    }

    @Test("Given sync off and the parent's own zone still in iCloud, when iCloud is turned on again, then a fetch comes first")
    func turningOnAgainFetchesFirst() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, entry) = try await started(on: cloud)
        let family = try await phone.family()
        await cloud.deleteZone(family, by: "dad")
        try await phone.fetch()
        // While sync is off: another iPhone changes the beard, this one renames a child.
        await cloud.write(try await record(.hero(.testDad), ["beard": .string("full")], for: phone), as: "dad")
        try await rename(lena, to: "Ελένη", on: phone)

        #expect(try await phone.coordinator.turnOn() == .turnedOn)
        try await settle(phone)

        // The same family, made again and whole; the hero iCloud had merges as a fetched one does.
        #expect(try await phone.family() == family)
        #expect(await cloud.records(in: family, of: "dad").count == 5)
        #expect(try await phone.cloudRecord(.child(lena.id))?["name"] == .string("Ελένη"))
        #expect(try await phone.cloudRecord(.entry(entry.id))?["note"] == .string("πρώτο"))
        #expect(try await phone.store.profiles.fetchProfile()?.dadAppearance.beard == .full)
        #expect(try await phone.ledger().pending().isEmpty)
        #expect(try await phone.ledger().settings().resendAfterFetch == false)
    }
}
