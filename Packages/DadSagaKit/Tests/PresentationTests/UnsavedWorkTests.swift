import Foundation
@testable import Presentation
import Testing

@MainActor
@Suite("UnsavedWork")
struct UnsavedWorkTests {
    @Test("Given two open editors, when one has changes and then the other, then work is held until both have none")
    func heldUntilEveryEditorIsClear() {
        let sut = UnsavedWork()
        let note = UUID()
        let family = UUID()
        #expect(!sut.isHeld)

        sut.set(note, hasUnsavedChanges: true)
        sut.set(family, hasUnsavedChanges: true)
        sut.set(note, hasUnsavedChanges: false)
        #expect(sut.isHeld)

        sut.set(family, hasUnsavedChanges: false)
        #expect(!sut.isHeld)
    }

    @Test("Given an editor with changes, when it closes, then nothing is held for it")
    func closedEditorHoldsNothing() {
        let sut = UnsavedWork()
        let note = UUID()
        sut.set(note, hasUnsavedChanges: true)

        sut.closed(note)

        #expect(!sut.isHeld)
    }
}
