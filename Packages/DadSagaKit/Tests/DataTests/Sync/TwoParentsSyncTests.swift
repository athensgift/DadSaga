import Application
import Domain
import Foundation
import Testing
@testable import Data

/// Two parents sharing one family through the owner's iCloud (ADR-0065 §3, §4, §8): what each records and edits
/// reaches the other and merges by field, each one's XP and title come only from their own entries, and nothing a
/// zone or an account does ever takes the saga from either iPhone.
@Suite("Two parents, one family", .serialized)
struct TwoParentsSyncTests: SyncBench {
    let root = FileManager.default.temporaryDirectory.appending(path: "dadsaga-two-" + UUID().uuidString)
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)

    @Test("Given a partner with a saga, when they join, then one family on both iPhones, each a member, nothing waiting")
    func joiningMakesOneFamily() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum) = (family.dad, family.mum)

        #expect(try await dad.children() == [lena, nikos])
        #expect(try await mum.children() == [lena, nikos])
        #expect(try await dad.store.progress.fetchEvents() == [family.dadsEntry, family.mumsEntry])
        #expect(try await mum.store.progress.fetchEvents() == [family.dadsEntry, family.mumsEntry])
        #expect(try await mum.photos.storedData(id: family.dadsEntry.photoIDs[0])
            == (try await dad.photos.storedData(id: family.dadsEntry.photoIDs[0])))
        let records = await family.cloud.records(in: family.zone, of: "dad")
        #expect(records[.member(.testDad)] == ["userRecordName": .string("dad")])
        #expect(records[.member(.partner)] == ["userRecordName": .string("mum")])
        #expect(records.keys.filter { $0.type == .child }.count == 2)
        #expect(await dad.coordinator.status() == ShareStatus(sharing: .owner))
        #expect(await mum.coordinator.status() == ShareStatus(sharing: .partner))
        #expect(try await dad.ledger().pending().isEmpty)
        #expect(try await mum.ledger().pending().isEmpty)
    }

    @Test("Given both offline, when each records, then each sees every entry, and XP, title and skills only from their own")
    func bothRecordOffline() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum) = (family.dad, family.mum)
        let photoID = try await mum.photos.save(try smallImage())

        let mums = try await mum.record(nikos, by: .partner, minute: 1, photoIDs: [photoID])
        let dads = [try await dad.record(nikos, by: .testDad, minute: 2), try await dad.record(lena, by: .testDad, minute: 3)]
        try await settle(dad, mum)

        let everyone = Set([family.dadsEntry, family.mumsEntry, mums].map(\.id) + dads.map(\.id))
        #expect(try await dad.entryIDs() == everyone)
        #expect(try await mum.entryIDs() == everyone)
        #expect(try await dad.photos.storedData(id: photoID) == (try await mum.photos.storedData(id: photoID)))
        // Three entries of his, two of hers: neither counts the other's (ADR-0006, ADR-0065 §3).
        let (his, hers) = (try await dad.home(), try await mum.home())
        #expect(his.progress.totalXP == 60)
        #expect(his.progress.cardsDone == 3)
        #expect(his.progress.skillXP[.care] == 60)
        #expect(hers.progress.totalXP == 40)
        #expect(hers.progress.cardsDone == 2)
        #expect(hers.progress.skillXP[.care] == 40)
        #expect(hers.standing.title?.id == "t2")
        // Neither one's hero or kept title is in the family's zone.
        let records = await family.cloud.records(in: family.zone, of: "dad")
        #expect(records.keys.allSatisfy { [.member, .child, .entry, .photo].contains($0.type) })
    }

    @Test("Given both edit one child offline, then different fields both stay, and the same field is the later save's")
    func bothEditOneChild() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum) = (family.dad, family.mum)
        var toned = lena
        toned.skinTone = .dark

        try await dad.rename(lena, to: "Ελένη")
        try await mum.store.profiles.save(FamilyEdit(changed: [ChildEdit(child: toned, fields: [.skinTone])]))
        try await settle(dad, mum)

        for phone in [dad, mum] {
            let child = try #require(try await phone.children().first)
            #expect(child.name == "Ελένη")
            #expect(child.skinTone == .dark)
        }

        // The same field: the dad's save reaches iCloud first, the partner's after it.
        try await dad.rename(lena, to: "Λένα του μπαμπά")
        try await mum.rename(lena, to: "Λενάκι")
        try await settle(dad, mum)

        #expect(try await dad.children().first?.name == "Λενάκι")
        #expect(try await mum.children().first?.name == "Λενάκι")
        #expect(try await dad.ledger().pending().isEmpty)
        #expect(try await mum.ledger().pending().isEmpty)
    }

    @Test("Given one parent removes a child, then removed on both; and the other brings them back, on both")
    func removingAndBringingBackReachBoth() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum) = (family.dad, family.mum)
        let before = try await mum.home().progress

        try await dad.store.profiles.save(FamilyEdit(removedIDs: [lena.id]))
        try await settle(dad, mum)

        #expect(try await mum.children() == [nikos])
        #expect(try await mum.removedChildren() == [lena])
        // Her entry with the removed child still counts for her (ADR-0065 §4).
        #expect(try await mum.home().progress == before)

        try await mum.store.profiles.bringBack(childID: lena.id)
        try await settle(dad, mum)

        #expect(try await dad.children() == [lena, nikos])
        #expect(try await dad.removedChildren().isEmpty)
        #expect(try await mum.children() == [lena, nikos])
    }

    @Test("Given both capture one first offline, then both entries are kept, and the family counts it once: the earlier")
    func aFirstCapturedTwice() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let content = FixedContent(catalog: .titlesAQuestAndAFirst)
        let family = try await family(on: makeCloud(), content: content)
        let (dad, mum) = (family.dad, family.mum)
        let day = Date(timeIntervalSince1970: 1_800_050_000)
        let his = ProgressEvent(kind: .first(id: "f1"), childID: lena.id, date: day.addingTimeInterval(3_600), note: "δικό του")
        let hers = ProgressEvent(
            id: UUID(), authorID: .partner, kind: .first(id: "f1"), childID: lena.id, date: day, note: "δικό της", photoIDs: []
        )

        try await dad.store.progress.add(his)
        try await mum.store.progress.add(hers)
        try await settle(dad, mum)

        for phone in [dad, mum] {
            let events = try await phone.store.progress.fetchEvents()
            #expect(Set(events.filter { $0.kind == .first(id: "f1") }.map(\.note)) == ["δικό της", "δικό του"])
            let moments = FamilyMoments(events: events, catalog: .titlesAQuestAndAFirst)
            #expect(moments.capturedFirstIDs(for: lena.id) == ["f1"])
            #expect(moments.moments(for: lena.id).map(\.eventID) == [hers.id])
        }
        // Each one gets the XP of the first they captured themselves.
        #expect(try await dad.home().progress.totalXP == 50)
        #expect(try await mum.home().progress.totalXP == 50)
    }

    @Test("Given both add children offline past four, then five on both; edits are accepted, adding and bringing back refused")
    func moreThanFourChildren() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum) = (family.dad, family.mum)
        let his = [Child(name: "Γιάννης", birthDay: nil), Child(name: "Μαρία", birthDay: nil)]
        let hers = Child(name: "Άρης", birthDay: nil)

        try await dad.store.profiles.save(FamilyEdit(added: his))
        try await mum.store.profiles.save(FamilyEdit(added: [hers]))
        try await settle(dad, mum)

        let children = try await dad.children()
        #expect(Set(children.map(\.name)) == ["Λένα", "Νίκος", "Γιάννης", "Μαρία", "Άρης"])
        // Two were added at the same place: both iPhones show them in the same order.
        #expect(try await mum.children() == children)
        let edit = DefaultUpdateFamilyUseCase(profileRepository: mum.store.profiles)
        var renamed = hers
        renamed.name = "Άρης ο μικρός"
        try await edit.execute(FamilyEdit(changed: [ChildEdit(child: renamed, fields: [.name])]), on: .now)
        await #expect(throws: ProfileValidationError.tooManyChildren) {
            try await edit.execute(FamilyEdit(added: [Child(name: "Ζωή", birthDay: nil)]), on: .now)
        }
        try await edit.execute(FamilyEdit(removedIDs: [hers.id]), on: .now)
        await #expect(throws: ProfileValidationError.tooManyChildren) {
            try await DefaultBringBackChildUseCase(profileRepository: mum.store.profiles).execute(childID: hers.id)
        }
        try await settle(dad, mum)
        #expect(try await dad.children().count == 4)
        #expect(try await dad.removedChildren().map(\.name) == ["Άρης ο μικρός"])
    }

    @Test("Given the owner's iCloud full, when the partner records, then it waits, and their status says whose iCloud")
    func theOwnersICloudIsFull() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum) = (family.dad, family.mum)
        await family.cloud.setQuota("dad", bytes: await family.cloud.usage(of: "dad") + 20)
        let photoID = try await mum.photos.save(try smallImage())

        let recorded = try await mum.record(nikos, by: .partner, minute: 1, photoIDs: [photoID])
        try await settle(dad, mum)

        // The family's photos count in the owner's iCloud (ADR-0065 §4).
        #expect(await mum.coordinator.status() == ShareStatus(sharing: .partner, waiting: .iCloudFull(isPartners: true)))
        #expect(try await mum.store.progress.fetchEvents().contains(recorded))
        #expect(try await dad.entryIDs().contains(recorded.id) == false)
        #expect(Set(try await mum.ledger().pending().map(\.name)).isSuperset(of: [.entry(recorded.id), .photo(photoID)]))

        await family.cloud.setQuota("dad", bytes: nil)
        await mum.coordinator.resume()
        try await settle(dad, mum)

        #expect(await mum.coordinator.status() == ShareStatus(sharing: .partner))
        #expect(try await dad.store.progress.fetchEvents().contains(recorded))
        #expect(try await mum.ledger().pending().isEmpty)
    }

    @Test("Given the partner's iPhone on another Apple Account, when they edit, then sync is off and nothing goes anywhere")
    func thePartnerSwitchesAccount() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let family = try await family(on: makeCloud())
        let (dad, mum) = (family.dad, family.mum)
        let before = await family.cloud.records(in: family.zone, of: "dad")

        await mum.device.switchAccount(to: "other")
        try await mum.rename(lena, to: "Ελένη")
        let recorded = try await mum.record(nikos, by: .partner, minute: 1)
        await mum.coordinator.resume()
        try await mum.send()
        try await settle(dad)

        #expect(await mum.coordinator.status() == ShareStatus(sharing: .off))
        #expect(await family.cloud.zones(of: "other").isEmpty)
        #expect(await family.cloud.zones(of: "other", in: .shared).isEmpty)
        #expect(await family.cloud.records(in: family.zone, of: "dad") == before)
        // Nothing is deleted either: the saga is as she left it.
        #expect(try await mum.entryIDs() == [family.dadsEntry.id, family.mumsEntry.id, recorded.id])
        #expect(try await mum.children().map(\.name) == ["Ελένη", "Νίκος"])
    }
}
