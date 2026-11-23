import Domain
import Foundation
import Testing
@testable import Data

/// A save that fails leaves nothing pending: the next save would otherwise write it after the dad was told it failed
/// (ADR-0048 §1). A read-only store is a store whose every save throws.
@Suite("A save that fails")
struct FailedSaveTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-failed-save-" + UUID().uuidString)
    let child = Child(name: "Λένα", birthDay: .day(2023, 11, 14))

    /// A store with a family and one entry, reopened so that it cannot be written.
    private func unwritableStore(with events: [ProgressEvent] = []) async throws -> LocalStore {
        let app = LocalStore.live(in: directory)
        try await app.profiles.create(PlayerProfile(children: [child], heroClassID: "h-chef"))
        for event in events { try await app.progress.add(event) }
        _ = try await app.outfit.setChoice(.hidden, for: .play)
        return LocalStore.live(in: directory, readOnly: true)
    }

    private func entry(_ kind: ProgressEvent.Kind = .quest(id: "q1"), note: String? = nil) -> ProgressEvent {
        ProgressEvent(kind: kind, childID: child.id, date: Date(timeIntervalSince1970: 1_750_000_000), note: note,
                      photoIDs: ["photo-a"])
    }

    @Test("Given a store that can't be written, when adding an event fails, then the events read back are unchanged")
    func failedAddLeavesNothingBehind() async throws {
        let stored = entry()
        let store = try await unwritableStore(with: [stored])

        await #expect(throws: (any Error).self) { try await store.progress.add(entry(.boss(id: "b1"))) }

        #expect(try await store.progress.fetchEvents() == [stored])
    }

    @Test("Given a first whose save failed, when the dad tries again, then it is tried again, not called already recorded")
    func failedFirstCanBeTriedAgain() async throws {
        let store = try await unwritableStore()
        let first = entry(.first(id: "f-steps"))

        await #expect(throws: (any Error).self) { _ = try await store.progress.addUnlessRecorded(first) }
        await #expect(throws: (any Error).self) { _ = try await store.progress.addUnlessRecorded(first) }
        #expect(try await store.progress.fetchEvents().isEmpty)
    }

    @Test("Given a stored entry, when an update fails, then the entry keeps its note and photos")
    func failedUpdateKeepsTheStoredEntry() async throws {
        let stored = entry(note: "Πρώτα")
        let store = try await unwritableStore(with: [stored])
        let changed = ProgressEvent(id: stored.id, kind: stored.kind, childID: stored.childID, date: stored.date,
                                    note: "Άλλο", photoIDs: [])

        await #expect(throws: (any Error).self) { try await store.progress.update(changed) }

        #expect(try await store.progress.fetchEvents() == [stored])
    }

    @Test("Given a stored entry, when deleting it fails, then the entry is still there")
    func failedDeleteKeepsTheEntry() async throws {
        let stored = entry()
        let store = try await unwritableStore(with: [stored])

        await #expect(throws: (any Error).self) { try await store.progress.delete(id: stored.id) }

        #expect(try await store.progress.fetchEvents() == [stored])
    }

    @Test("Given a stored family, when a family edit or a hero edit fails, then the stored family and hero are read back")
    func failedProfileSaveKeepsTheStoredFamily() async throws {
        let store = try await unwritableStore()
        let other = Child(name: "Νίκος", birthDay: .day(2024, 3, 9))

        await #expect(throws: (any Error).self) {
            try await store.profiles.save(FamilyEdit(added: [other], removedIDs: [child.id]))
        }
        await #expect(throws: (any Error).self) {
            try await store.profiles.save(HeroEdit(heroClassID: "h-smart"))
        }

        let profile = try await store.profiles.fetchProfile()
        #expect(profile?.children == [child])
        #expect(profile?.heroClassID == "h-chef")
    }

    @Test("Given a stored outfit choice, when changing it fails, then the stored choice is read back")
    func failedOutfitChoiceKeepsTheStoredChoice() async throws {
        let store = try await unwritableStore()

        await #expect(throws: (any Error).self) { _ = try await store.outfit.setChoice(.item("g-mug"), for: .play) }

        #expect(try await store.outfit.fetchOutfit() == Outfit(choices: [.play: .hidden]))
    }

    @Test("Given a stored saga, when erasing it fails, then the saga is still there")
    func failedEraseKeepsTheSaga() async throws {
        let stored = entry()
        let store = try await unwritableStore(with: [stored])

        await #expect(throws: (any Error).self) { try await store.wholeSaga.eraseAll() }

        #expect(try await store.progress.fetchEvents() == [stored])
        #expect(try await store.profiles.fetchProfile()?.children == [child])
    }
}
