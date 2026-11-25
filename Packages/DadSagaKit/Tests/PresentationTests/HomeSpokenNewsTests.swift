import Domain
import Foundation
import Presentation
import Testing

/// What VoiceOver hears on home: a celebration and a new title's card, each once and together when they come together
/// (ADR-0055 §6, ADR-0059 §1).
@MainActor
@Suite("HomeViewModel, what VoiceOver hears")
struct HomeSpokenNewsTests {
    let progress = FakeProgress()
    let title = "Έγινες «Νέος στο ταξίδι». Επίπεδο 1. Πήρες: Πανάκι."

    func makeSUT() async -> HomeViewModel {
        let sut = makeHomeViewModel(profile: HeroStub.profile, progress: progress)
        await sut.onAppear()
        return sut
    }

    @Test("Given nothing new, when home loads, then VoiceOver has nothing to hear")
    func nothingNew() async {
        #expect(await makeSUT().spokenNews == nil)
    }

    @Test("Given a quest that brings a title, when it is recorded, then one announcement says both, once")
    func celebrationAndTitleTogether() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        let news = try #require(sut.spokenNews)
        #expect(news.text == "Η φροντίδα σου μεγάλωσε. " + title)

        sut.spoke(news)
        #expect(sut.spokenNews == nil)
        // Neither its time starting again, as home comes back from another tab, nor a reload says it twice.
        await sut.reload()
        #expect(sut.spokenNews == nil)
    }

    @Test("Given a title's card heard, when the next quest brings no title, then only its celebration is heard")
    func onlyTheCelebration() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        sut.spoke(try #require(sut.spokenNews))

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        #expect(sut.spokenNews?.text == "Η φροντίδα σου μεγάλωσε")
    }

    @Test("Given a title's card still open from before, when home loads, then the card alone is heard")
    func onlyTheCard() async {
        await progress.seed(times: 1)
        #expect(await makeSUT().spokenNews?.text == title)
    }

    @Test("Given a first that brings a title, when its sheet is open or still closing, then both wait for home")
    func waitsForTheSheet() async throws {
        let sut = await makeSUT()
        sut.startCapture()
        await sut.captureMoment(firstID: "f1", date: HeroStub.today)
        #expect(sut.titleCard != nil)
        #expect(sut.spokenNews == nil)

        sut.dismissSelection()
        #expect(sut.spokenNews == nil)

        sut.sheetDismissed()
        #expect(sut.spokenNews?.text == "👣 Βήματα. " + title)
    }

    @Test("Given a quest's sheet opened before the news was heard, when it closes, then what is still there is heard")
    func waitsForAnySheet() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        let celebration = try #require(sut.celebration)
        sut.select(cardID: "q1")
        #expect(sut.spokenNews == nil)

        sut.celebrationFinished(id: celebration.id)
        sut.dismissSelection()

        #expect(sut.spokenNews?.text == title)
    }

    @Test("Given a title taken back by an Undo, when a card reaches it again, then it is heard again")
    func heardAgainAfterAnUndo() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        sut.spoke(try #require(sut.spokenNews))
        await sut.undoLastRecord()
        #expect(sut.spokenNews == nil)

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        #expect(sut.spokenNews?.text == "Η φροντίδα σου μεγάλωσε. " + title)
    }
}
