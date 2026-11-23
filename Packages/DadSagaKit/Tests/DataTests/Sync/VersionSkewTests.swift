import Application
import Domain
import Foundation
import Testing
@testable import Data

/// Two iPhones on different versions of DadSaga (ADR-0065 §1, §8): what a newer one writes is kept here and in
/// iCloud, shown as far as this version can, and never sent back or deleted by this one.
@Suite("An iPhone on an older version", .serialized)
struct VersionSkewTests: SyncBench {
    let root = FileManager.default.temporaryDirectory.appending(path: "dadsaga-skew-" + UUID().uuidString)
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)

    /// The rows' records as the store holds them now, as iCloud would keep them: no field that is nil.
    func stored(_ names: RecordName..., on phone: SyncPhone) async throws -> [RecordName: [String: SyncValue]] {
        let records = try await phone.store.connection.open().feed.records(
            names.map { ($0, nil) }, zones: SyncZones(family: try await phone.family()), gone: []
        )
        return Dictionary(
            records.map { ($0.name, $0.fields.filter { $0.value != .cleared }) }, uniquingKeysWith: { first, _ in first }
        )
    }

    @Test("Given entries of a kind and a card this version doesn't know, then kept, never sent back, and in a zone built again")
    func unknownKindsAndCardsAreKept() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, entry) = try await started(on: cloud)
        let family = try await phone.family()
        let (ritual, future) = (RecordName.entry(UUID()), RecordName.entry(UUID()))
        let fields: [String: SyncValue] = [
            "author": .string(UUID.testDad.uuidString), "childID": .string(lena.id.uuidString),
            "date": .date(Date(timeIntervalSince1970: 1_800_000_900)), "photoIDs": .strings([])
        ]
        let asRitual = fields.merging(["kind": .string("ritual"), "contentID": .string("r-bedtime")]) { $1 }
        let asFuture = fields.merging(["kind": .string("quest"), "contentID": .string("q-from-the-future")]) { $1 }

        await cloud.write(try await record(ritual, asRitual, for: phone), as: "dad")
        await cloud.write(try await record(future, asFuture, for: phone), as: "dad")
        try await settle(phone)
        let sent = await cloud.requests.count
        try await phone.rename(nikos, to: "Νικόλας")
        try await settle(phone)

        // Stored as they came. The kind is on no screen; the card's id is read, and a copy carries it as it is.
        #expect(try await stored(ritual, future, on: phone) == [ritual: asRitual, future: asFuture])
        let events = try #require(try await phone.store.wholeSaga.readAll()).events
        #expect(events.map(\.kind) == [entry.kind, .quest(id: "q-from-the-future")])
        #expect(try await phone.home().progress.cardsDone == 1)
        // Only the rename went out: neither entry is ever sent back.
        #expect(await cloud.requests.dropFirst(sent).flatMap(\.self) == [.child(nikos.id)])
        #expect(await cloud.records(in: family, of: "dad")[ritual] == asRitual)

        // A zone this iPhone builds again from its store carries both, as stored.
        await cloud.deleteZone(family, by: "dad")
        try await phone.fetch()
        #expect(try await phone.coordinator.turnOn() == .turnedOn)
        try await settle(phone)
        let rebuilt = await cloud.records(in: family, of: "dad")
        #expect(rebuilt[ritual] == asRitual)
        #expect(rebuilt[future] == asFuture)
        #expect(try await stored(ritual, on: phone)[ritual] == asRitual)
    }

    @Test("Given fields a newer version added, when this iPhone edits other fields of those records, then they stay in iCloud")
    func unknownFieldsStayOnTheServer() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, entry) = try await started(on: cloud)
        await cloud.write(try await record(.entry(entry.id), ["mood": .string("calm")], for: phone), as: "dad")
        await cloud.write(try await record(.hero(.testDad), ["aura": .string("gold")], for: phone), as: "dad")
        await cloud.write(try await record(.child(lena.id), ["nickname": .string("Λ")], for: phone), as: "dad")
        try await settle(phone)

        try await phone.store.progress.update(ProgressEvent(
            id: entry.id, kind: entry.kind, childID: entry.childID, date: entry.date, note: "άλλο", photoIDs: entry.photoIDs
        ))
        try await phone.store.profiles.save(HeroEdit(beard: .full))
        try await phone.rename(lena, to: "Ελένη")
        try await settle(phone)

        // A save carries only the fields this iPhone changed (ADR-0065 §4).
        let record = try #require(try await phone.cloudRecord(.entry(entry.id)))
        #expect(record["mood"] == .string("calm"))
        #expect(record["note"] == .string("άλλο"))
        #expect(try await phone.cloudRecord(.hero(.testDad))?["aura"] == .string("gold"))
        #expect(try await phone.cloudRecord(.hero(.testDad))?["beard"] == .string("full"))
        #expect(try await phone.cloudRecord(.child(lena.id))?["nickname"] == .string("Λ"))
        #expect(try await phone.cloudRecord(.child(lena.id))?["name"] == .string("Ελένη"))
    }

    @Test("Given values a newer version wrote in known fields, when this iPhone edits other fields, then none is written back")
    func unknownValuesAreNotWrittenBack() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, _) = try await started(on: cloud)
        let (hero, child, slot) = (RecordName.hero(.testDad), RecordName.child(lena.id), RecordName.wardrobe(skill: "care"))
        await cloud.write(try await record(hero, ["hair": .string("mohawk-2030")], for: phone), as: "dad")
        await cloud.write(try await record(child, ["gender": .string("a-newer-gender")], for: phone), as: "dad")
        await cloud.write(try await record(slot, ["choice": .string("aura:gold")], for: phone), as: "dad")
        try await settle(phone)

        try await phone.store.profiles.save(HeroEdit(beard: .full))
        try await phone.rename(lena, to: "Ελένη")
        try await settle(phone)

        // Read as this version reads them, stored and kept in iCloud as they came.
        #expect(try await phone.store.profiles.fetchProfile()?.dadAppearance.beard == .full)
        #expect(try await phone.children().first?.gender == .boy)
        #expect(try await phone.store.outfit.fetchOutfit().choice(for: .care) == .automatic)
        let rows = try await stored(hero, child, slot, on: phone)
        #expect(rows[hero]?["hair"] == .string("mohawk-2030"))
        #expect(rows[child]?["gender"] == .string("a-newer-gender"))
        #expect(rows[slot] == ["choice": .string("aura:gold")])
        #expect(try await phone.cloudRecord(hero)?["hair"] == .string("mohawk-2030"))
        #expect(try await phone.cloudRecord(hero)?["beard"] == .string("full"))
        #expect(try await phone.cloudRecord(child)?["gender"] == .string("a-newer-gender"))
        #expect(try await phone.cloudRecord(child)?["name"] == .string("Ελένη"))
        #expect(try await phone.cloudRecord(slot) == ["choice": .string("aura:gold")])
    }
}
