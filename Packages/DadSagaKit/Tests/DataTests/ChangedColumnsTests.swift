import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// Every write says what changed, and only that (ADR-0065 §1, §4): an update lists only the columns whose value moved,
/// and a write of equal values reaches neither the file nor its history ("a row update setting an equal value must not
/// count as a change", ADR-0065 Risks). The change feed sync sends will read exactly this history (ADR-0065 §2).
@Suite("Only changed columns are written", .serialized)
struct ChangedColumnsTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-columns-" + UUID().uuidString)
    var storeURL: URL { directory.appending(path: "DadSaga.store") }
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)
    let look = DadAppearance(hair: .curly, hairColor: .black, beard: .full, glasses: .none)

    /// A store on disk with the dad, Λένα and Νίκος, and one entry of his.
    func onboarded() async throws -> (store: LocalStore, entry: ProgressEvent) {
        let store = LocalStore.live(in: directory)
        try await store.profiles.create(PlayerProfile(
            children: [lena, nikos], heroClassID: "h-cool", dadSkinTone: .medium, dadAppearance: look
        ))
        let entry = ProgressEvent(kind: .quest(id: "q1"), childID: lena.id, date: .now, note: "πρώτο", photoIDs: ["a"])
        try await store.progress.add(entry)
        return (store, entry)
    }

    /// The row changes `act` writes, one list per transaction.
    func changes(_ act: () async throws -> Void) async throws -> [[RowChange]] {
        let before = try storeHistory(at: storeURL).count
        try await act()
        return Array(try storeHistory(at: storeURL).dropFirst(before))
    }

    @Test("Given two children, when one is renamed, then one update of that child lists only its name")
    func renameListsOnlyTheName() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let (store, _) = try await onboarded()
        var renamed = lena
        renamed.name = "Ελένη"

        let written = try await changes {
            try await store.profiles.save(FamilyEdit(changed: [ChildEdit(child: renamed, fields: [.name])]))
        }

        #expect(written == [[.update(ChildRecord.self, [\ChildRecord.name])]])
    }

    @Test("Given a child not born, when a birth day is set, then the three day columns; when moved in the month, only the day")
    func birthDayColumns() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let (store, _) = try await onboarded()
        var born = nikos
        born.birthDay = .day(2026, 11, 1)
        var moved = born
        moved.birthDay = .day(2026, 11, 3)

        let set = try await changes {
            try await store.profiles.save(FamilyEdit(changed: [ChildEdit(child: born, fields: [.birthDay])]))
        }
        let move = try await changes {
            try await store.profiles.save(FamilyEdit(changed: [ChildEdit(child: moved, fields: [.birthDay])]))
        }

        #expect(set == [[.update(ChildRecord.self, [\ChildRecord.birthYear, \.birthMonth, \.birthDay])]])
        #expect(move == [[.update(ChildRecord.self, [\ChildRecord.birthDay])]])
    }

    @Test("Given two children, when one is added or one removed, then only that row is written and none renumbered")
    func addAndRemoveTouchNoOtherChild() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let (store, _) = try await onboarded()

        let added = try await changes {
            try await store.profiles.save(FamilyEdit(added: [Child(name: "Ίρις", birthDay: nil)]))
        }
        let removed = try await changes { try await store.profiles.save(FamilyEdit(removedIDs: [lena.id])) }

        #expect(added == [[.insert(ChildRecord.self)]])
        #expect(removed == [[.delete(ChildRecord.self)]])
        #expect(try await store.profiles.fetchProfile()?.children.map(\.name) == ["Νίκος", "Ίρις"])
    }

    @Test("Given the dad's look, when only the beard changes, then one update of the profile lists only the beard")
    func beardListsOnlyTheBeard() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let (store, _) = try await onboarded()

        let written = try await changes { try await store.profiles.save(HeroEdit(beard: .short)) }

        #expect(written == [[.update(ProfileRecord.self, [\ProfileRecord.beard])]])
    }

    @Test("Given an entry, when its photos change, then one update lists only the photos")
    func photosListOnlyThePhotos() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let (store, entry) = try await onboarded()
        let changed = ProgressEvent(
            id: entry.id, kind: entry.kind, childID: entry.childID, date: entry.date, note: entry.note, photoIDs: ["a", "b"]
        )

        let written = try await changes { try await store.progress.update(changed) }

        #expect(written == [[.update(ProgressEventRecord.self, [\ProgressEventRecord.photoIDs])]])
    }

    @Test("Given stored values, when a family, hero, entry, wardrobe or title write sets the same ones, then nothing is written")
    func equalValuesWriteNothing() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let (store, entry) = try await onboarded()
        _ = try await store.outfit.setChoice(.hidden, for: .care)
        try await store.standing.keep(titleID: "t1")
        try await store.standing.markSeen(titleID: "t1")

        let written = try await changes {
            try await store.profiles.save(FamilyEdit(
                changed: [ChildEdit(child: lena, fields: Set(ChildField.allCases))], hasPartner: true
            ))
            try await store.profiles.save(FamilyEdit(added: [nikos]))
            try await store.profiles.save(HeroEdit(
                heroClassID: "h-cool", dadSkinTone: .medium, hair: look.hair, hairColor: look.hairColor,
                beard: look.beard, glasses: look.glasses
            ))
            try await store.progress.update(entry)
            _ = try await store.outfit.setChoice(.hidden, for: .care)
            try await store.standing.keep(titleID: "t1")
            try await store.standing.markSeen(titleID: "t1")
        }

        #expect(written.isEmpty)
    }
}
