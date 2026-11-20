import Application
import Domain
import Foundation
@testable import Presentation
import Testing

/// The film's dates and the switch that takes them out (ADR-0041).
@MainActor
@Suite("SagaFilmViewModel: dates", .timeLimit(.minutes(1)))
struct SagaFilmDatesTests: SagaFilmSheetTests {
    let renderer = FakeFilmRenderer()

    @Test("Given the whole saga, when making the film with dates, then the opening spans it and each first and boss has its day",
          arguments: [
            // Foundation writes a range with an en dash; in English with thin spaces around it.
            ("el_GR", ["Μάρτιος 2024 \u{2013} Μάρτιος 2026", "10 Μαΐου 2024", "10 Σεπτεμβρίου 2024", "10 Μαΐου 2025"]),
            ("en_US", ["March 2024\u{2009}\u{2013}\u{2009}March 2026", "May 10, 2024", "September 10, 2024", "May 10, 2025"])
          ])
    func datesInTheFilm(locale: String, expected: [String]) async throws {
        let sut = makeSUT(locale: locale)
        await sut.onAppear()
        await sut.selectPeriod(id: "everything")

        await sut.makeFilm(reduceMotion: false)

        #expect(dates(of: try #require(await renderer.scripts.first)) == expected)
    }

    @Test("Given dates turned off, when a new sheet opens, then they stay off, and another period keeps them off")
    func datesSwitchIsRemembered() async throws {
        let getFilm = FakeGetSagaFilm()
        let first = makeSUT(getFilm)
        await first.onAppear()
        #expect(choices(first)?.showsDates == true)
        #expect(choices(first)?.datesLabel == "Ημερομηνίες στην ταινία")

        await first.setShowsDates(false)?.value
        #expect(choices(first)?.showsDates == false)
        #expect(getFilm.choices.saves == [.dates(false)])

        let next = makeSUT(getFilm)
        await next.onAppear()
        #expect(choices(next)?.showsDates == false)
        await next.selectPeriod(id: "everything")
        #expect(choices(next)?.showsDates == false)

        await next.makeFilm(reduceMotion: false)
        #expect(dates(of: try #require(await renderer.scripts.first)).isEmpty)
    }

    @Test("Given dates turned off, when another child is chosen, then they stay off")
    func datesSwitchKeptAcrossChildren() async throws {
        let sut = makeSUT(FakeGetSagaFilm(profile: FilmStub.family))
        await sut.onAppear()
        sut.setShowsDates(false)

        await sut.selectChild(id: FilmStub.niko.id)

        #expect(choices(sut)?.selectedChildID == FilmStub.niko.id)
        #expect(choices(sut)?.showsDates == false)
    }

    @Test("Given the switch turned off and on at once, when both are saved, then they are saved in order and on is kept")
    func datesSavedInOrder() async throws {
        let getFilm = FakeGetSagaFilm()
        let sut = makeSUT(getFilm)
        await sut.onAppear()

        sut.setShowsDates(false)
        await sut.setShowsDates(true)?.value

        #expect(getFilm.choices.saves == [.dates(false), .dates(true)])
        #expect(await getFilm.choices.showsDates())
        #expect(choices(sut)?.showsDates == true)
    }
}
