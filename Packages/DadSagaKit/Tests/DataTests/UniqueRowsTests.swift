import Application
import Domain
import Foundation
import Testing
@testable import Data

/// `#Unique` meets `replaceAll`, which deletes every row and inserts the copy's in one save, often with the same ids
/// (ADR-0065 §5). Rows are counted through a container of their own, so a duplicate can't hide behind a fetch.
@Suite("One row per id through a restore", .serialized)
struct UniqueRowsTests: SagaCopyBench {
    let root = FileManager.default.temporaryDirectory.appending(path: "dadsaga-unique-" + UUID().uuidString)
    let madeAt = Date(timeIntervalSinceReferenceDate: 815_000_000)

    var storeURL: URL { root.appending(path: "new/store/DadSaga.store") }

    /// Reads through every repository first, so each one's context holds the rows the restore replaces.
    func warm(_ phone: Phone) async throws {
        _ = try await phone.store.profiles.fetchProfile()
        _ = try await phone.store.progress.fetchEvents()
        _ = try await phone.store.outfit.fetchOutfit()
        _ = try await phone.store.standing.fetchKept()
        _ = try await phone.store.wholeSaga.readAll()
    }

    func restoreCopy(_ url: URL, on phone: Phone) async throws {
        try await restore(on: phone).restore(try await restore(on: phone).open(fileAt: url) { _ in }, on: madeAt)
    }

    /// Every repository reads `saga` (photo ids aside, which each restore makes new), and the store holds its rows once.
    func expectStored(_ saga: StoredSaga, on phone: Phone) async throws {
        let read = try #require(try await phone.store.wholeSaga.readAll())
        #expect(read.profile == saga.profile)
        #expect(read.removedChildren == saga.removedChildren)
        #expect(read.events.map(\.id) == saga.events.map(\.id))
        #expect(zip(read.events, saga.events).allSatisfy {
            $0.authorID == $1.authorID && $0.note == $1.note && $0.date == $1.date && $0.kind == $1.kind
                && $0.childID == $1.childID && $0.photoIDs.count == $1.photoIDs.count
        })
        #expect(read.outfit == saga.outfit)
        #expect(read.kept == saga.kept)
        #expect(try await phone.store.profiles.fetchProfile() == saga.profile)
        #expect(try await phone.store.progress.fetchEvents() == read.events)
        #expect(try await phone.store.outfit.fetchOutfit() == saga.outfit)
        #expect(try await phone.store.standing.fetchKept() == saga.kept)
        #expect(try storedRowCount(ProfileRecord.self, at: storeURL) == 1)
        #expect(try storedRowCount(ChildRecord.self, at: storeURL)
            == saga.profile.children.count + saga.removedChildren.count)
        #expect(try storedRowCount(ProgressEventRecord.self, at: storeURL) == saga.events.count)
        #expect(try storedRowCount(OutfitRecord.self, at: storeURL) == saga.outfit.choices.count)
    }

    @Test("Given a saga restored from a copy, when the same copy is restored again, then each row is the copy's, once")
    func sameCopyTwice() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let old = phone("old")
        _ = try await fill(old)
        let original = try #require(try await old.store.wholeSaga.readAll())
        let made = try await make(on: old).execute(on: madeAt) { _ in }
        let new = phone("new")
        try await restoreCopy(made.url, on: new)
        try await warm(new)

        try await restoreCopy(made.url, on: new)

        try await expectStored(original, on: new)
    }

    @Test("Given a saga sharing the copy's ids that changed since, nils included, when restored, then every row is the copy's")
    func copyOverAChangedSaga() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let old = phone("old")
        _ = try await fill(old)
        let original = try #require(try await old.store.wholeSaga.readAll())
        let made = try await make(on: old).execute(on: madeAt) { _ in }
        let new = phone("new")
        try await restoreCopy(made.url, on: new)
        // The copy's title kept and seen, a note, a birth day and a slot: each later set to nil, or the other way.
        var changed = try #require(try await new.store.wholeSaga.readAll())
        changed.kept = KeptStanding()
        changed.profile.heroClassID = "h-coach"
        changed.profile.children[0].name = "Άλλο όνομα"
        changed.profile.children[0].birthDay = nil
        changed.profile.children[1].birthDay = .day(2026, 1, 1)
        changed.profile.children.append(Child(name: "Νέο", birthDay: nil))
        changed.outfit = Outfit(choices: [.care: .hidden, .patience: .item("g-x")])
        changed.events = changed.events.map { event in
            ProgressEvent(
                id: event.id, authorID: UUID(), kind: event.kind, childID: event.childID,
                date: event.date.addingTimeInterval(1), note: event.note == nil ? "νέα" : nil, photoIDs: []
            )
        } + [ProgressEvent(kind: .quest(id: "q-w2-car-seat"), childID: lena.id, date: madeAt)]
        try await new.store.wholeSaga.replaceAll(with: changed)
        try await warm(new)

        try await restoreCopy(made.url, on: new)

        try await expectStored(original, on: new)
    }

    @Test("Given a restored saga, when the dad keeps playing, then every repository writes once per id")
    func writesAfterARestore() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let old = phone("old")
        _ = try await fill(old)
        let made = try await make(on: old).execute(on: madeAt) { _ in }
        let new = phone("new")
        try await restoreCopy(made.url, on: new)
        try await warm(new)
        try await restoreCopy(made.url, on: new)

        var profile = try #require(try await new.store.profiles.fetchProfile())
        profile.children[0].name = "Λενιώ"
        try await new.store.profiles.save(profile)
        _ = try await new.store.outfit.setChoice(.hidden, for: .care)
        try await new.store.progress.add(ProgressEvent(
            authorID: profile.id, kind: .quest(id: "q-w2-car-seat"), childID: lena.id, date: madeAt
        ))

        let saga = try #require(try await new.store.wholeSaga.readAll())
        #expect(saga.profile.children[0].name == "Λενιώ")
        #expect(saga.profile.id == SagaCopyPeople.dadID)
        #expect(saga.removedChildren == [removed])
        #expect(saga.outfit.choice(for: .care) == .hidden)
        #expect(try storedRowCount(ChildRecord.self, at: storeURL) == 3)
        #expect(try storedRowCount(OutfitRecord.self, at: storeURL) == saga.outfit.choices.count)
        #expect(try storedRowCount(ProgressEventRecord.self, at: storeURL) == saga.events.count)
    }
}
