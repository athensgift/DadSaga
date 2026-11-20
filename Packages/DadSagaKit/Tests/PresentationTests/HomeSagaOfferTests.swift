import Application
import Domain
import Foundation
@testable import Presentation
import Testing

/// The film offer as home's query would find it, and the dad's answers to it.
actor FakeFilmOffers: AnswerSagaOfferUseCase {
    private let occasion: SagaOccasion?
    /// `false` stands for an answer still on its way to the store: the query goes on finding the occasion.
    private let remembers: Bool
    private(set) var answered: [String] = []

    init(occasion: SagaOccasion? = nil, remembers: Bool = true) {
        self.occasion = occasion
        self.remembers = remembers
    }

    /// The occasion to offer, unless the dad has answered it.
    var pending: SagaOccasion? {
        guard let occasion, !(remembers && answered.contains(occasion.id)) else { return nil }
        return occasion
    }

    func execute(occasionID: String) async {
        answered.append(occasionID)
    }
}

@MainActor
@Suite("The film offer on home")
struct HomeSagaOfferTests {
    let progress = FakeProgress()

    static let birthday = SagaOccasion(
        id: "eleni/birthday/1", kind: .birthday(years: 1), childID: HeroStub.eleni.id, date: HeroStub.today, period: .year(1)
    )

    static var newWorld: SagaOccasion {
        let world = HeroStub.catalog.worlds[0]
        return SagaOccasion(
            id: "niko/world/w1", kind: .newWorld(left: world), childID: HeroStub.niko.id, date: HeroStub.today,
            period: .world(id: world.id)
        )
    }

    func makeHome(
        _ film: FakeFilmOffers, locale: String = "el_GR", reminder: ReminderUseCases = .neverOffered
    ) -> HomeViewModel {
        makeHomeViewModel(profile: HeroStub.family, progress: progress, locale: locale, reminder: reminder, film: film)
    }

    @Test("Given no occasion, when home opens, then no film is offered")
    func nothingToOffer() async {
        let sut = makeHome(FakeFilmOffers())
        await sut.onAppear()
        #expect(sut.sagaOffer == nil)
    }

    @Test("Given Eleni's first birthday, when home opens on Niko, then the card names her and the year, and nothing else")
    func birthdayCard() async throws {
        let sut = makeHome(FakeFilmOffers(occasion: Self.birthday))
        await sut.onAppear()

        let offer = try #require(sut.sagaOffer)
        #expect(offer.title == "Μια μικρή ταινία;")
        #expect(offer.childLine == "Ελένη · 1ος χρόνος")
        #expect(offer.message.hasPrefix("Οι φωτογραφίες, οι πρώτες φορές και οι σημειώσεις σου"))
        #expect(offer.accept == "Φτιάξε την ταινία")
        #expect(offer.decline == "Όχι τώρα")
        // No count, no day and no XP anywhere on the card (ADR-0006): the year's name holds its only digit.
        let words = [offer.title, offer.message, offer.accept, offer.decline].joined(separator: " ")
        let hasDigit = words.contains { $0.isNumber }
        #expect(!hasDigit)
        #expect(!words.contains("XP"))
    }

    @Test("Given a world Niko grew out of, when home opens in English, then the card names him and the world")
    func worldCardInEnglish() async throws {
        let sut = makeHome(FakeFilmOffers(occasion: Self.newWorld), locale: "en_US")
        await sut.onAppear()

        let offer = try #require(sut.sagaOffer)
        #expect(offer.title == "A short film?")
        #expect(offer.childLine == "Νίκος · World")
        #expect(offer.message == "Your photos, firsts and notes from it, as a film with music. Made on this iPhone.")
        #expect(offer.accept == "Make the film")
        #expect(offer.decline == "Not now")
    }

    @Test("Given the offer, when the dad says not now, then it is gone for good and the answer is kept")
    func notNowIsFinal() async {
        let film = FakeFilmOffers(occasion: Self.birthday)
        let sut = makeHome(film)
        await sut.onAppear()

        let request = await sut.answerSagaOffer(accept: false)
        #expect(request == nil)
        #expect(sut.sagaOffer == nil)

        await sut.reload()
        #expect(sut.sagaOffer == nil)
        #expect(await film.answered == ["eleni/birthday/1"])
    }

    @Test("Given an answer still being saved, when home loads again, then the card does not come back")
    func answeredAtTheTap() async {
        let sut = makeHome(FakeFilmOffers(occasion: Self.birthday, remembers: false))
        await sut.onAppear()

        _ = await sut.answerSagaOffer(accept: false)
        await sut.reload()

        #expect(sut.sagaOffer == nil)
    }

    @Test("Given the offer, when the dad makes the film, then it is that child's and that period's, and the card is gone")
    func makeTheFilm() async {
        let film = FakeFilmOffers(occasion: Self.birthday)
        let sut = makeHome(film)
        await sut.onAppear()

        let request = await sut.answerSagaOffer(accept: true)

        #expect(request == SagaFilmRequest(childID: HeroStub.eleni.id, period: .year(1)))
        #expect(sut.sagaOffer == nil)
        #expect(await film.answered == ["eleni/birthday/1"])
        await sut.reload()
        #expect(sut.sagaOffer == nil)
    }

    @Test("Given no offer on screen, when an answer arrives, then nothing is stored and no film opens")
    func answerWithoutAnOffer() async {
        let film = FakeFilmOffers()
        let sut = makeHome(film)
        await sut.onAppear()

        #expect(await sut.answerSagaOffer(accept: true) == nil)
        #expect(await film.answered.isEmpty)
    }

    @Test("Given a film and the weekly reminder to offer, when home opens, then only the film card shows; later, the reminder")
    func oneOfferAtATime() async {
        await progress.seed(times: 1)
        let reminder = FakeReminder()
        let sut = makeHome(
            FakeFilmOffers(occasion: Self.birthday), reminder: ReminderUseCases(get: reminder, update: reminder)
        )
        await sut.onAppear()
        #expect(sut.sagaOffer != nil)
        #expect(sut.reminderOffer == nil)

        _ = await sut.answerSagaOffer(accept: false)
        #expect(sut.sagaOffer == nil)
        #expect(sut.reminderOffer == nil)

        await sut.reload()
        #expect(sut.sagaOffer == nil)
        #expect(sut.reminderOffer?.title == "Μια υπενθύμιση την εβδομάδα;")
    }
}
