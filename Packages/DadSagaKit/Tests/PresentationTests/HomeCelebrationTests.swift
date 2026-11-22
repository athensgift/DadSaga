import Domain
import Foundation
import Presentation
import Testing

@MainActor
@Suite("HomeViewModel, celebrations and title cards")
struct HomeCelebrationTests {
    let progress = FakeProgress()

    func makeSUT(profile: PlayerProfile?, film: FakeFilmOffers = FakeFilmOffers()) -> HomeViewModel {
        makeHomeViewModel(profile: profile, progress: progress, film: film)
    }

    @Test("Given a quest, when completing it, then the celebration says which skill grew, with no XP or level")
    func skillGrew() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        #expect(sut.celebration?.skillText == "Η φροντίδα σου μεγάλωσε")
        #expect(sut.celebration?.announcement == "Η φροντίδα σου μεγάλωσε")
        #expect(sut.celebration?.highlight == .quest)
    }

    @Test("Given a boss and a plain quest, when haptics are on, then the boss taps and the plain quest does not")
    func hapticsOn() async throws {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.select(cardID: "b1")
        await sut.defeatSelectedBoss()
        let boss = try #require(sut.celebration)
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        let plain = try #require(sut.celebration)

        #expect(boss.haptic(isEnabled: true) == .heavy)
        #expect(plain.haptic(isEnabled: true) == nil)
    }

    @Test("Given haptics are off, when a boss is celebrated, then nothing taps")
    func hapticsOff() async throws {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.select(cardID: "b1")
        await sut.defeatSelectedBoss()

        #expect(try #require(sut.celebration).haptic(isEnabled: false) == nil)
    }

    @Test("Given the first quest, when it is recorded, then a calm card says the new title and what it brought")
    func titleCardAppears() async throws {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        #expect(sut.titleCard == nil)

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        let card = try #require(sut.titleCard)
        #expect(card.title == "Έγινες «Νέος στο ταξίδι».")
        #expect(card.message == "Πήρες: Πανάκι.")
        #expect(card.close == "Ωραία")
        guard case .loaded(let content) = sut.state else { throw StubError.boom }
        #expect(content.dadTitle == "Νέος στο ταξίδι")
    }

    @Test("Given a title card, when the dad closes it, then it goes at once and stays gone through a reload")
    func titleCardCloses() async throws {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        await sut.closeTitleCard()
        await sut.onAppear()

        #expect(sut.titleCard == nil)
        #expect(await progress.kept.seenTitleID == "t1")
        // A new home, as after a relaunch, reads the seen title from the store.
        let relaunched = makeSUT(profile: HeroStub.profile)
        await relaunched.onAppear()
        #expect(relaunched.titleCard == nil)
    }

    @Test("Given a title card and a film to offer, when home loads, then the film waits until the card is closed")
    func filmWaitsForTheTitleCard() async throws {
        let film = FakeFilmOffers(occasion: HomeSagaOfferTests.birthday)
        let sut = makeSUT(profile: HeroStub.family, film: film)
        await sut.onAppear()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        #expect(sut.titleCard != nil)
        #expect(sut.sagaOffer == nil)

        await sut.closeTitleCard()

        #expect(sut.sagaOffer != nil)
    }

    @Test("Given a title, when the quest that brought it is undone, then the title and its card stay")
    func undoKeepsTheTitle() async throws {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        await sut.undoLastRecord()

        #expect(await progress.eventCount == 0)
        guard case .loaded(let content) = sut.state else { throw StubError.boom }
        #expect(content.dadTitle == "Νέος στο ταξίδι")

        #expect(sut.titleCard?.title == "Έγινες «Νέος στο ταξίδι».")
    }
}
