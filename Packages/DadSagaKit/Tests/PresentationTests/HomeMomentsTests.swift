import Application
import Domain
import Foundation
import Presentation
import Testing

@MainActor
@Suite("HomeViewModel, legendary moments in two steps")
struct HomeMomentsTests {
    let progress = FakeProgress()

    func makeSUT(profile: PlayerProfile? = HeroStub.profile) async -> HomeViewModel {
        let sut = makeHomeViewModel(profile: profile, progress: progress)
        await sut.onAppear()
        return sut
    }

    func loadedMoments(_ sut: HomeViewModel) -> MomentsSection? {
        guard case .loaded(let content) = sut.state else { return nil }
        return content.moments
    }

    func choice(_ sut: HomeViewModel) -> MomentChoice? {
        guard case .choose(let choice) = sut.momentCapture?.step else { return nil }
        return choice
    }

    @Test("Given no moments, when appearing, then the section is empty and counts all firsts")
    func emptyMoments() async {
        let sut = await makeSUT()
        let moments = loadedMoments(sut)
        #expect(moments?.title == "Θρυλικές στιγμές")
        #expect(moments?.progress == "0")
        #expect(moments?.cards.isEmpty == true)
        #expect(moments?.isComplete == false)
    }

    @Test("Given step 1, when choosing first steps, then they are recorded and the same sheet moves to step 2")
    func stepOneRecords() async throws {
        let sut = await makeSUT()
        sut.startCapture()
        let id = try #require(sut.momentCapture?.id)
        #expect(sut.momentCapture?.title == "Νίκος")
        #expect(choice(sut)?.options.map(\.title) == ["Βήματα"])
        #expect(choice(sut)?.nextLine == "Μετά, αν θες, φωτογραφίες ή δυο λόγια.")

        await sut.captureMoment(firstID: "f1", date: HeroStub.today)

        #expect(sut.momentCapture?.id == id)
        let details = try #require(sut.momentCapture?.details)
        #expect(details.isNew)
        #expect(details.title == "👣 Βήματα")
        #expect(details.heading == "Αποθηκεύτηκε! Θες να κρατήσεις κάτι ακόμα;")
        #expect(details.line == "Φωτογραφίες ή δυο λόγια, τώρα ή όποτε θέλεις.")
        #expect(details.notNowTitle == "Όχι τώρα")
        #expect(details.photoIDs.isEmpty)
        #expect(loadedMoments(sut)?.cards.map(\.title) == ["👣 Βήματα"])
        #expect(loadedMoments(sut)?.isComplete == true)
        #expect(await progress.eventCount == 1)
    }

    @Test("Given step 2, when saving a note and three photos, then the moment keeps them and the sheet closes")
    func stepTwoSaves() async throws {
        let sut = await makeSUT()
        sut.startCapture()
        await sut.captureMoment(firstID: "f1", date: HeroStub.today)
        var photos = PhotoDrafts()
        photos.append([Data([1]), Data([2]), Data([3])])
        photos.makeCover(id: try #require(photos.items.last?.id))

        await sut.saveMomentDetails(date: HeroStub.today, note: "Τρία βήματα!", photos: photos)

        #expect(sut.momentCapture == nil)
        let card = try #require(loadedMoments(sut)?.cards.first)
        #expect(card.subtitle.hasSuffix(" · Τρία βήματα!"))
        #expect(card.photoIDs == ["photo-1", "photo-2", "photo-3"])
        #expect(card.photoCount == "3 φωτογραφίες")
        #expect(await sut.photoData(id: "photo-1", maxPixelSize: 192) == Data([3]))
        #expect(loadedMoments(sut)?.viewer.showPhotos == "Δες τις φωτογραφίες")
    }

    @Test("Given step 2, when closing it with Not now, then the moment and its XP stay")
    func closingKeepsTheMoment() async throws {
        let sut = await makeSUT()
        sut.startCapture()
        await sut.captureMoment(firstID: "f1", date: HeroStub.today)

        sut.dismissSelection()

        #expect(sut.momentCapture == nil)
        #expect(loadedMoments(sut)?.cards.count == 1)
        guard case .loaded(let content) = sut.state else { throw StubError.boom }
        #expect(content.dadTitle?.text == "Επίπεδο 1 · Νέος στο ταξίδι")
    }

    @Test("Given step 2 of a new moment, when undoing, then the moment and the title it brought are gone and the sheet closes")
    func undoInStepTwo() async throws {
        let sut = await makeSUT()
        sut.startCapture()
        await sut.captureMoment(firstID: "f1", date: HeroStub.today)

        await sut.deleteMoment()

        #expect(sut.momentCapture == nil)
        #expect(loadedMoments(sut)?.cards.isEmpty == true)
        guard case .loaded(let content) = sut.state else { throw StubError.boom }
        #expect(content.dadTitle?.text == "Επίπεδο 0 · Σε αναμονή")
        #expect(content.companions.first?.traits.isEmpty == true)
    }

    @Test("Given a captured moment with photos, when editing it, then it opens at step 2 with Delete and no celebration")
    func editingOpensAtDetails() async throws {
        await progress.seedMoment(photos: [Data([1]), Data([2])])
        let sut = await makeSUT()
        let card = try #require(loadedMoments(sut)?.cards.first)

        sut.editMoment(id: card.id)

        let details = try #require(sut.momentCapture?.details)
        #expect(!details.isNew)
        #expect(details.heading == nil)
        #expect(details.undoOffer == nil)
        #expect(details.photoIDs == ["photo-1", "photo-2"])
        #expect(details.labels.delete == "Διαγραφή στιγμής")

        var photos = PhotoDrafts(storedIDs: details.photoIDs)
        photos.makeCover(id: "photo-2")
        await sut.saveMomentDetails(date: HeroStub.today, note: "μετά", photos: photos)
        sut.sheetDismissed()

        #expect(sut.momentCapture == nil)
        #expect(sut.celebration == nil)
        #expect(loadedMoments(sut)?.cards.first?.photoIDs == ["photo-2", "photo-1"])
    }

    @Test("Given saving fails, when recording at step 1, then step 1 stays with an error and nothing is recorded")
    func stepOneFailure() async throws {
        let sut = await makeSUT()
        sut.startCapture()
        await progress.failNext()

        await sut.captureMoment(firstID: "f1", date: HeroStub.today)

        #expect(choice(sut) != nil)
        #expect(sut.errorMessage == "Δεν αποθηκεύτηκε. Δοκίμασε ξανά.")
        #expect(await progress.eventCount == 0)
    }

    @Test("Given saving fails, when saving step 2, then the sheet stays open with an error")
    func stepTwoFailure() async throws {
        let sut = await makeSUT()
        sut.startCapture()
        await sut.captureMoment(firstID: "f1", date: HeroStub.today)
        await progress.failNext()

        await sut.saveMomentDetails(date: HeroStub.today, note: "x", photos: PhotoDrafts())

        #expect(sut.momentCapture?.details != nil)
        #expect(sut.errorMessage == "Δεν αποθηκεύτηκε. Δοκίμασε ξανά.")
    }

    @Test("Given every first captured, when opening step 1, then there is nothing left to choose")
    func nothingLeft() async {
        await progress.seedMoment(photos: [])
        let sut = await makeSUT()
        sut.startCapture()
        #expect(choice(sut)?.options.isEmpty == true)
    }

    @Test("Given step 2, when saving an earlier date, then the card moves to that date")
    func stepTwoSavesTheDate() async throws {
        let sut = await makeSUT()
        sut.startCapture()
        await sut.captureMoment(firstID: "f1", date: HeroStub.today)
        let before = try #require(loadedMoments(sut)?.cards.first?.subtitle)
        let lastWeek = HeroStub.today.addingTimeInterval(-7 * 86_400)

        await sut.saveMomentDetails(date: lastWeek, note: "", photos: PhotoDrafts())

        let after = try #require(loadedMoments(sut)?.cards.first?.subtitle)
        #expect(after != before)
        let editing = try #require(loadedMoments(sut)?.cards.first?.id)
        sut.editMoment(id: editing)
        #expect(sut.momentCapture?.details?.date == lastWeek)
    }

    @Test("Given an edited moment, when deleting it, then the card and its XP are gone and the sheet closes")
    func deletesAnEditedMoment() async throws {
        await progress.seedMoment(photos: [Data([1])])
        let sut = await makeSUT()
        sut.editMoment(id: try #require(loadedMoments(sut)?.cards.first?.id))

        await sut.deleteMoment()

        #expect(sut.momentCapture == nil)
        #expect(loadedMoments(sut)?.cards.isEmpty == true)
        guard case .loaded(let content) = sut.state else { throw StubError.boom }
        #expect(content.dadTitle?.text == "Επίπεδο 1 · Νέος στο ταξίδι")
    }

    @Test("Given step 2 with its undo offer, when another offer's time runs out, then this one stays")
    func otherUndoExpiryIsIgnored() async throws {
        let sut = await makeSUT()
        sut.startCapture()
        await sut.captureMoment(firstID: "f1", date: HeroStub.today)
        let offer = try #require(sut.momentCapture?.details?.undoOffer)

        sut.momentUndoExpired(id: offer.id + 1)

        #expect(sut.momentCapture?.details?.undoOffer == offer)
    }

    @Test("Given step 1 saving slowly, when the dad closes and opens a new capture meanwhile, then the new one stays at step 1")
    func reopenedWhileSaving() async throws {
        let sut = await makeSUT()
        sut.startCapture()
        await progress.slowNext()
        let saving = Task { await sut.captureMoment(firstID: "f1", date: HeroStub.today) }
        while !sut.isCompleting { await Task.yield() }
        sut.dismissSelection()
        sut.startCapture()
        let reopened = try #require(sut.momentCapture?.id)

        await progress.finishSlowSave()
        await saving.value

        #expect(sut.momentCapture?.id == reopened)
        #expect(sut.momentCapture?.details == nil)
        #expect(await progress.eventCount == 1)
    }

    @Test("Given home fails to reload, when step 1 records a first, then step 2 still opens for the saved moment")
    func stepTwoWithoutReload() async throws {
        let sut = await makeSUT()
        sut.startCapture()
        await progress.freezeOverview()

        await sut.captureMoment(firstID: "f1", date: HeroStub.today)

        let details = try #require(sut.momentCapture?.details)
        #expect(details.title == "👣 Βήματα")
        #expect(details.isNew)
        #expect(loadedMoments(sut)?.cards.isEmpty == true)
    }
}
