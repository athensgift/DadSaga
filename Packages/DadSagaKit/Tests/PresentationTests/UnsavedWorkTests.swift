import Foundation
@testable import Presentation
import Testing

/// What holds a link back, and the moments that let it go (ADR-0050).
@MainActor
@Suite("UnsavedWork")
struct UnsavedWorkTests {
    @Test("Given two open editors, when one has changes and then the other, then work is held until both have none")
    func heldUntilEveryEditorIsClear() {
        let sut = UnsavedWork()
        let note = UUID()
        let family = UUID()
        #expect(!sut.isHeld)

        sut.set(note, in: UnsavedScope.homeSheet, hasUnsavedChanges: true)
        sut.set(family, in: UnsavedScope.settings, hasUnsavedChanges: true)
        sut.set(note, in: UnsavedScope.homeSheet, hasUnsavedChanges: false)
        #expect(sut.isHeld)

        sut.set(family, in: UnsavedScope.settings, hasUnsavedChanges: false)
        #expect(!sut.isHeld)
    }

    @Test("Given editors holding in two places, when endAll, then nothing is held, released once")
    func endAllReleasesOnce() {
        let sut = UnsavedWork()
        var releases = 0
        sut.onRelease = { releases += 1 }
        sut.set(UUID(), in: UnsavedScope.settings, hasUnsavedChanges: true)
        sut.set(UUID(), in: UnsavedScope.timelineJournal, hasUnsavedChanges: true)
        #expect(sut.isHeld)

        sut.endAll()

        #expect(!sut.isHeld)
        #expect(releases == 1)
    }

    @Test("Given an editor with changes, when it closes, then nothing is held for it")
    func closedEditorHoldsNothing() {
        let sut = UnsavedWork()
        let note = UUID()
        sut.set(note, in: UnsavedScope.homeSheet, hasUnsavedChanges: true)

        sut.closed(note)

        #expect(!sut.isHeld)
    }

    @Test("Given a quest sheet that kept its note after recording, when the sheet is dismissed, then it holds nothing")
    func dismissedSheetHoldsNothing() {
        let sut = UnsavedWork()
        sut.set(UUID(), in: UnsavedScope.homeSheet, hasUnsavedChanges: true)
        sut.set(UUID(), in: UnsavedScope.settings, hasUnsavedChanges: true)

        sut.end(scope: UnsavedScope.homeSheet)
        #expect(sut.isHeld)

        sut.end(scope: UnsavedScope.settings)
        #expect(!sut.isHeld)
    }

    @Test("Given an editor with changes, when the dad discards, then nothing is held while its sheet still slides away")
    func discardLetsGoAtOnce() {
        let sut = UnsavedWork()
        let registration = EditorRegistration()
        registration.report(hasUnsavedChanges: true, in: UnsavedScope.homeSheet, to: sut)

        registration.discard()

        #expect(!sut.isHeld)
    }

    @Test("Given two editors holding, when they let go one by one, then the release is reported once, at the last")
    func releaseIsReportedOnceAtTheLast() {
        let sut = UnsavedWork()
        var releases = 0
        sut.onRelease = { releases += 1 }
        let note = UUID()
        let family = UUID()
        sut.set(note, in: UnsavedScope.homeSheet, hasUnsavedChanges: true)
        sut.set(family, in: UnsavedScope.settings, hasUnsavedChanges: true)

        sut.closed(note)
        #expect(releases == 0)
        sut.end(scope: UnsavedScope.settings)
        #expect(releases == 1)
        sut.end(scope: UnsavedScope.settings)
        #expect(releases == 1)
    }

    @Test("Given an editor with changes, when its registration ends, then nothing is held; not before")
    func registrationIsTheLastResort() {
        let sut = UnsavedWork()
        var registration: EditorRegistration? = EditorRegistration()
        registration?.report(hasUnsavedChanges: true, in: UnsavedScope.homeSheet, to: sut)
        #expect(sut.isHeld)

        registration = nil

        #expect(!sut.isHeld)
    }
}
