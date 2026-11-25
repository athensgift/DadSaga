import Application
import Domain
import Foundation
import Presentation
import Testing

/// A sheet records with the child it was built for, whatever home loads meanwhile, and home's choice is always the
/// child it shows once a load has failed.
@MainActor
@Suite("Home, the sheet's child")
struct HomeSheetChildTests {
    let progress = FakeProgress()
    let maria = Child(name: "Μαρία", birthDay: CalendarDay(HeroStub.today, in: .gmt))

    func makeSUT() async -> HomeViewModel {
        let profile = PlayerProfile(children: [HeroStub.niko, maria], heroClassID: "h-cool")
        let sut = makeHomeViewModel(profile: profile, progress: progress)
        await sut.onAppear()
        return sut
    }

    /// Picks Μαρία, whose load waits, and runs `act` on the home that still shows Νίκος.
    private func whileMariaLoads(_ sut: HomeViewModel, _ act: () -> Void) async {
        await progress.holdOverviews()
        let picking = Task { await sut.selectChild(id: maria.id) }
        await progress.waitUntilHeld(1)
        act()
        await progress.releaseAllOverviews()
        await picking.value
    }

    @Test("Given one child's quest opened while another child loads, when recording it, then it is the first child's")
    func questKeepsItsChild() async {
        let sut = await makeSUT()
        await whileMariaLoads(sut) { sut.select(cardID: "q1") }

        await sut.completeSelectedQuest()

        #expect(await progress.recordedChildIDs == [HeroStub.niko.id])
        #expect(sut.selectedChildID == maria.id)
    }

    @Test("Given one child's boss opened while another child loads, when recording it, then it is the first child's")
    func bossKeepsItsChild() async {
        let sut = await makeSUT()
        await whileMariaLoads(sut) { sut.select(cardID: "b1") }

        await sut.defeatSelectedBoss()

        #expect(await progress.recordedChildIDs == [HeroStub.niko.id])
    }

    @Test("Given one child's moment sheet opened while another child loads, when recording it, then it is the first child's")
    func momentKeepsItsChild() async {
        let sut = await makeSUT()
        await whileMariaLoads(sut) { sut.startCapture() }

        await sut.captureMoment(firstID: "f1", date: HeroStub.today)

        #expect(await progress.recordedChildIDs == [HeroStub.niko.id])
        #expect(sut.momentCapture?.title == HeroStub.niko.name)
    }

    @Test("Given one child's quest opened while a link to another's loads, when it has loaded, then the sheet is as it was")
    func linkLeavesASheetOpenedMeanwhile() async {
        let sut = await makeSUT()
        await progress.holdOverviews()
        let opening = Task { await sut.open(.quest(id: "q1", childID: maria.id)) }
        await progress.waitUntilHeld(1)
        sut.select(cardID: "q1")
        await progress.releaseAllOverviews()
        await opening.value

        await sut.completeSelectedQuest()

        #expect(sut.selectedChildID == maria.id)
        #expect(await progress.recordedChildIDs == [HeroStub.niko.id])
    }

    @Test("Given one child's quest opened while another child loads, when undoing an earlier one, then it stays the first's")
    func undoKeepsTheSheetsChild() async {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        await whileMariaLoads(sut) { sut.select(cardID: "q1") }
        await sut.undoLastRecord()

        await sut.completeSelectedQuest()

        #expect(await progress.recordedChildIDs == [HeroStub.niko.id])
    }

    @Test("Given another child picked, when loading them fails, then home's choice is again the child it shows")
    func failedPickGoesBack() async {
        let sut = await makeSUT()
        await progress.failOverview()

        await sut.selectChild(id: maria.id)

        #expect(sut.pickedChildID == HeroStub.niko.id)
        await progress.mendOverview()
        await sut.reload()
        #expect(sut.selectedChildID == HeroStub.niko.id)
        // Picked again, they show.
        await sut.selectChild(id: maria.id)
        #expect(sut.selectedChildID == maria.id)
    }

    @Test("Given a link to another child, when its load fails, then home's choice is again the child it shows")
    func failedLinkGoesBack() async {
        let sut = await makeSUT()
        await progress.failOverview()

        await sut.open(.quest(id: "q1", childID: maria.id))

        #expect(sut.selectedChildID == HeroStub.niko.id)
        #expect(sut.selectedQuest == nil)
    }
}
