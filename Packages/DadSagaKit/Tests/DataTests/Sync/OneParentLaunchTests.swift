import Application
import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// What a kill, a launch and the store's history do to one parent's sync (ADR-0065 §2): `Sync.store` is the record
/// of what waits, so a change is given again at every launch; the engines carry on from the state kept for them; a
/// batch that couldn't be applied is fetched again; and the history's two edges, expired and never read.
@Suite("Launches, kills and the history, for one parent", .serialized)
struct OneParentLaunchTests: SyncBench {
    let root = FileManager.default.temporaryDirectory.appending(path: "dadsaga-launch-" + UUID().uuidString)
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)

    func child(_ child: Child, on phone: SyncPhone) async throws -> Child? {
        try await phone.store.profiles.fetchProfile()?.children.first { $0.id == child.id }
    }

    @Test("Given a change waiting when the app was killed, when it launches again, then it is sent and nothing is fetched twice")
    func aRelaunchCarriesOn() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, _) = try await started(on: cloud)
        await cloud.write(try await record(.child(nikos.id), ["name": .string("Νικόλας")], for: phone), as: "dad")
        try await settle(phone)
        var edited = lena
        edited.name = "Ελένη"
        try await phone.store.profiles.save(FamilyEdit(changed: [ChildEdit(child: edited, fields: [.name])]))
        // Read into Sync.store, never sent: the engine that held it goes with the app.
        await phone.coordinator.drain()

        let again = phone.relaunched()
        await again.coordinator.resume()
        try await again.fetch()

        // The engine carries on from the state Sync.store kept: the zones are not fetched from scratch.
        #expect(await again.device.engine()?.moved == 0)
        try await again.send()
        #expect(try await again.cloudRecord(.child(lena.id))?["name"] == .string("Ελένη"))
        #expect(try await child(nikos, on: again)?.name == "Νικόλας")
        #expect(try await again.ledger().pending().isEmpty)
    }

    @Test("Given a batch being sent, when the dad changes the same child again, then the later value goes too")
    func aChangeWhileABatchIsOutGoesAgain() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, _) = try await started(on: cloud)
        var edited = lena
        edited.name = "Ελένη"
        try await phone.store.profiles.save(FamilyEdit(changed: [ChildEdit(child: edited, fields: [.name])]))
        await phone.coordinator.drain()
        edited.name = "Λενάκι"
        let later = FamilyEdit(changed: [ChildEdit(child: edited, fields: [.name])])
        await cloud.whileNextRequestIsOut {
            try? await phone.store.profiles.save(later)
            await phone.coordinator.drain()
        }

        try await phone.send()

        #expect(try await phone.cloudRecord(.child(lena.id))?["name"] == .string("Λενάκι"))
        #expect(try await phone.ledger().pending().isEmpty)
        #expect(await phone.device.engine()?.pending.isEmpty == true)
    }

    @Test("Given a fetched batch that couldn't be applied, when the app launches again, then it is fetched again")
    func anUnappliedBatchIsFetchedAgain() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let content = UnreadableContent()
        let phone = phone("iphone", account: "dad", on: cloud, content: content)
        try await onboard(phone)
        #expect(try await phone.coordinator.turnOn() == .turnedOn)
        try await settle(phone)
        await cloud.write(try await record(.child(nikos.id), ["name": .string("Νικόλας")], for: phone), as: "dad")

        await content.setReadable(false)
        try await phone.fetch()
        #expect(try await child(nikos, on: phone)?.name == "Νίκος")

        await content.setReadable(true)
        let again = phone.relaunched()
        await again.coordinator.resume()
        try await again.fetch()

        #expect(try await child(nikos, on: again)?.name == "Νικόλας")
    }

    @Test("Given a history that can't be read, when sync next fetches, then a row iCloud lacks is sent, others keep its values")
    func anExpiredHistoryToken() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, _) = try await started(on: cloud)
        await cloud.write(try await record(.child(nikos.id), ["skinTone": .string("dark")], for: phone), as: "dad")
        // While sync wasn't looking the history went, and with it what the dad changed since.
        let again = phone.relaunched()
        try await again.store.connection.open().feed.trim()
        var edited = nikos
        edited.name = "Νικόλας"
        try await again.store.profiles.save(FamilyEdit(changed: [ChildEdit(child: edited, fields: [.name])]))
        let recorded = ProgressEvent(kind: .quest(id: "q1"), childID: nikos.id, date: .now)
        try await again.store.progress.add(recorded)

        await again.coordinator.resume()
        #expect(try await again.ledger().settings().resendAfterFetch)
        try await settle(again)

        #expect(try await again.cloudRecord(.entry(recorded.id))?["childID"] == .string(nikos.id.uuidString))
        #expect(try await child(nikos, on: again)?.name == "Νίκος")
        #expect(try await child(nikos, on: again)?.skinTone == .dark)
        #expect(try await again.cloudRecord(.child(nikos.id))?["name"] == .string("Νίκος"))
        #expect(try await again.ledger().settings().resendAfterFetch == false)
        #expect(try await again.ledger().pending().isEmpty)
    }

    @Test("Given iCloud never turned on, when the app resumes, then the history is trimmed and no Sync.store is made")
    func offResumeOnlyTrims() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let phone = phone("iphone", account: "dad", on: cloud)
        try await onboard(phone)
        #expect(try storeHistory(at: phone.storeURL).isEmpty == false)

        await phone.coordinator.resume()

        #expect(try storeHistory(at: phone.storeURL).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: phone.syncStoreURL.path))
        #expect(phone.device.engines.isEmpty)
        #expect(await cloud.zones(of: "dad").isEmpty)
        #expect(await phone.coordinator.status() == ShareStatus(sharing: .off))
    }
}
