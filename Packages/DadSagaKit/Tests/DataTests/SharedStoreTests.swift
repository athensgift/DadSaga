import Domain
import Foundation
import Testing
@testable import Data

/// The app writes the store and the widget reads it from another process (ADR-0023).
@Suite("LocalStore on disk")
struct SharedStoreTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-store-" + UUID().uuidString)

    @Test("Given the app saved a family and progress, when a read-only store opens the folder, then it sees both")
    func readOnlyStoreReadsWhatTheAppWrote() async throws {
        let app = LocalStore.live(in: directory)
        let child = Child(name: "Λένα", birthDate: Date(timeIntervalSince1970: 1_700_000_000))
        try await app.profiles.save(PlayerProfile(children: [child], heroClassID: "h-chef"))
        let event = ProgressEvent(kind: .quest(id: "q1"), childID: child.id, date: .now)
        try await app.progress.add(event)

        let widget = LocalStore.live(in: directory, readOnly: true)

        #expect(try await widget.profiles.fetchProfile()?.children == [child])
        #expect(try await widget.progress.fetchEvents().map(\.id) == [event.id])
    }

    @Test("Given a read-only store, when saving, then it throws")
    func readOnlyCannotSave() async throws {
        // The store opens on first use, so the app reads once to create the file.
        _ = try await LocalStore.live(in: directory).profiles.fetchProfile()
        let widget = LocalStore.live(in: directory, readOnly: true)

        await #expect(throws: (any Error).self) {
            try await widget.progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: .now))
        }
    }
}
