import Application
import Domain
import Foundation
@testable import Presentation
import Testing

/// A link from outside the app waits for whatever the dad hasn't saved, then opens once, for the right child
/// (ADR-0023, ADR-0050).
@MainActor
@Suite("Home, links that wait")
struct HomeLinkTests {
    let progress = FakeProgress()
    let work = UnsavedWork()
    let eleniQuest = PendingLink(.quest(id: "q1", childID: HeroStub.eleni.id))

    func makeSUT() async -> HomeViewModel {
        let sut = makeHomeViewModel(profile: HeroStub.family, progress: progress)
        await sut.onAppear()
        return sut
    }

    /// Lets the waiting task run as far as it can.
    func settle() async {
        for _ in 0..<20 { await Task.yield() }
    }

    @Test("Given an editor with unsaved changes, when a link arrives, then it waits, and opens once the editor is clear")
    func waitsForAnEditor() async throws {
        let sut = await makeSUT()
        let editor = UUID()
        work.set(editor, in: UnsavedScope.homeSheet, hasUnsavedChanges: true)
        var sheetsClosed = 0

        let receiving = Task { await sut.receive(eleniQuest, unsavedWork: work) { sheetsClosed += 1 } }
        await settle()
        #expect(sheetsClosed == 0)
        #expect(sut.selectedQuest == nil)

        work.set(editor, in: UnsavedScope.homeSheet, hasUnsavedChanges: false)
        #expect(await receiving.value)
        #expect(sheetsClosed == 1)
        #expect(sut.selectedChildID == HeroStub.eleni.id)
        #expect(sut.selectedQuest?.id == "q1")
    }

    @Test("Given a quest saving, when a link arrives, then it opens after the save, and the save stays recorded")
    func waitsForASave() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await progress.slowNext()
        let saving = Task { await sut.completeSelectedQuest() }
        await settle()
        #expect(sut.isCompleting)

        let receiving = Task { await sut.receive(eleniQuest, unsavedWork: work) {} }
        await settle()
        #expect(sut.selectedChildID == HeroStub.niko.id)

        await progress.finishSlowSave()
        await saving.value
        #expect(await receiving.value)
        #expect(await progress.eventCount == 1)
        #expect(sut.selectedChildID == HeroStub.eleni.id)
        #expect(sut.selectedQuest?.id == "q1")
    }

    @Test("Given nothing held, when a link arrives, then it opens at once, closing the view's sheets once")
    func opensOnce() async throws {
        let sut = await makeSUT()
        var sheetsClosed = 0

        let opened = await sut.receive(eleniQuest, unsavedWork: work) { sheetsClosed += 1 }

        #expect(opened)
        #expect(sheetsClosed == 1)
        #expect(sut.selectedQuest?.id == "q1")
    }

    @Test("Given a link to one child's quest, when the dad picks another child while it loads, then its quest stays shut")
    func otherChildPickedMeanwhile() async throws {
        let sut = await makeSUT()
        await progress.holdOverviews()

        let opening = Task { await sut.open(.quest(id: "q1", childID: HeroStub.eleni.id)) }
        await progress.waitUntilHeld(1)
        let picking = Task { await sut.selectChild(id: HeroStub.niko.id) }
        await progress.waitUntilHeld(2)
        await progress.releaseOldestOverview()
        await opening.value
        await progress.releaseAllOverviews()
        await picking.value

        #expect(sut.selectedChildID == HeroStub.niko.id)
        #expect(sut.selectedQuest == nil)
    }

    @Test("Given a link waiting, when a newer one replaces it, then only the newer opens, and the older says it didn't")
    func newerLinkWins() async throws {
        let sut = await makeSUT()
        let editor = UUID()
        work.set(editor, in: UnsavedScope.homeSheet, hasUnsavedChanges: true)
        let older = PendingLink(.child(HeroStub.niko.id))

        let first = Task { await sut.receive(older, unsavedWork: work) {} }
        await settle()
        first.cancel()
        // Cancelling alone ends the wait: the editor still holds.
        #expect(await first.value == false)
        #expect(work.isHeld)

        let second = Task { await sut.receive(eleniQuest, unsavedWork: work) {} }
        work.set(editor, in: UnsavedScope.homeSheet, hasUnsavedChanges: false)

        #expect(await second.value)
        #expect(sut.selectedChildID == HeroStub.eleni.id)
        #expect(sut.selectedQuest?.id == "q1")
    }

    @Test("Given a link opening, when its run is cancelled during the load, then no sheet opens")
    func cancelledOpenOpensNothing() async throws {
        let sut = await makeSUT()
        await progress.holdOverviews()

        let opening = Task { await sut.open(.quest(id: "q1", childID: HeroStub.eleni.id)) }
        await progress.waitUntilHeld(1)
        opening.cancel()
        await progress.releaseAllOverviews()
        await opening.value

        #expect(sut.selectedQuest == nil)
    }

    @Test("Given a link waiting for an editor, when the dad comes back to the app, then home reloads and the link opens later")
    func returnReloadsWhileALinkWaits() async throws {
        let sut = await makeSUT()
        let editor = UUID()
        work.set(editor, in: UnsavedScope.homeSheet, hasUnsavedChanges: true)
        let receiving = Task { await sut.receive(eleniQuest, unsavedWork: work) {} }
        await settle()

        await progress.holdOverviews()
        let returning = Task { await sut.appBecameActive() }
        await progress.waitUntilHeld(1)
        await progress.releaseAllOverviews()
        await returning.value

        work.set(editor, in: UnsavedScope.homeSheet, hasUnsavedChanges: false)
        #expect(await receiving.value)
        #expect(sut.selectedQuest?.id == "q1")
    }

    @Test("Given two links, when home reports the older one handled, then the newer still waits at the root")
    func rootKeepsTheNewerLink() async {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: HeroStub.family), getPreferences: StubGetPreferences())
        await sut.onAppear()
        let older = AppLink.child(HeroStub.niko.id)
        let newer = AppLink.quest(id: "q1", childID: HeroStub.eleni.id)
        sut.open(url: older.url)
        sut.open(url: newer.url)

        sut.linkHandled(PendingLink(older))
        #expect(sut.pendingLink == PendingLink(newer))

        sut.linkHandled(PendingLink(newer))
        #expect(sut.pendingLink == nil)
    }

    @Test("Given a celebration read out, when its time starts again, then VoiceOver doesn't read it twice")
    func celebrationIsReadOnce() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        let celebration = try #require(sut.celebration)

        #expect(sut.shouldAnnounce(celebration))
        #expect(!sut.shouldAnnounce(celebration))
    }

    @Test("Given a quest's sheet open with the note just written, when undoing that entry, then the sheet drops the note")
    func undoRefreshesTheOpenSheet() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest(note: "Καλό")
        sut.select(cardID: "q1")
        #expect(sut.selectedQuest?.lastJournal != nil)

        await sut.undoLastRecord()

        #expect(sut.selectedQuest?.id == "q1")
        #expect(sut.selectedQuest?.lastJournal == nil)
    }
}
