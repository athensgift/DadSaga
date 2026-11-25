import Application
import Domain
import Foundation
@testable import Presentation
import Testing

@MainActor
@Suite("SagaFilmViewModel: making, watching and leaving", .timeLimit(.minutes(1)))
struct SagaFilmMakingTests: SagaFilmSheetTests {
    let renderer = FakeFilmRenderer()

    // MARK: Making

    @Test("Given a film being made, when progress comes in as 20%, 60% and then 40%, then the sheet stays at 60%")
    func progressNeverGoesBack() async throws {
        let sut = makeSUT()
        await sut.onAppear()

        let film = await startFilm(sut, reporting: [0.2, 0.6, 0.4])

        let making = try #require(inProgress(sut))
        #expect(making.title == "Η ταινία σου φτιάχνεται…")
        #expect(making.progress == 0.6)
        #expect(making.progressText == "60%")
        #expect(making.note == "Κράτα το DadSaga ανοιχτό όσο φτιάχνεται.")
        #expect(making.cancelTitle == "Άκυρο")
        renderer.letGo()
        await film.value
    }

    @Test("Given a period still loading, when the dad makes the film, then it is the film on screen, and it isn't interrupted")
    func makingWhileAChoiceLoads() async throws {
        let getFilm = FakeGetSagaFilm()
        let sut = makeSUT(getFilm)
        await sut.onAppear()
        await getFilm.holdNext()
        let choosing = Task { await sut.selectPeriod(id: "everything") }
        var reached = getFilm.reached.makeAsyncIterator()
        _ = await reached.next()

        let film = await startFilm(sut)
        getFilm.letGo()
        await choosing.value

        #expect(inProgress(sut) != nil)
        renderer.letGo()
        await film.value
        #expect(finished(sut) != nil)
        #expect(await renderer.scripts.first?.scenes.first?.card.isOpening(period: "2ος χρόνος") == true)
    }

    @Test("Given a film being made, when it is done, then the sheet holds the film's file and offers to share it")
    func made() async throws {
        let sut = makeSUT()
        await sut.onAppear()

        await sut.makeFilm(reduceMotion: false)

        let made = try #require(finished(sut))
        #expect(renderer.films.map(\.path) == [made.url.resolvingSymlinksInPath().path])
        #expect(made.url.lastPathComponent == "Άννα – DadSaga.mp4")
        #expect(made.title == "Άννα – DadSaga")
        #expect(made.format == .vertical)
        #expect(made.shareTitle == "Μοιράσου ή αποθήκευσε")
        #expect(made.anotherTitle == "Φτιάξε άλλη")
        #expect(made.note.contains("Δεν κρατιέται"))
    }

    @Test("Given a film being made, when the dad cancels, then the choices come back without a word and no film is left")
    func cancelling() async throws {
        let sut = makeSUT()
        await sut.onAppear()
        let film = await startFilm(sut)

        sut.cancel()
        await film.value

        let setup = try #require(choices(sut))
        #expect(setup.notice == nil)
        #expect(setup.makeTitle == "Φτιάξε την ταινία")
        #expect(setup.selectedPeriodID == "year-2")
        #expect(renderer.films.isEmpty)
    }

    @Test("Given a film being made, when the app goes to the background, then it stops and offers to make it again")
    func leavingTheApp() async throws {
        let sut = makeSUT()
        await sut.onAppear()
        sut.selectFormat(.wide)
        let film = await startFilm(sut)

        sut.appWentToBackground()
        await film.value

        let setup = try #require(choices(sut))
        #expect(setup.notice == "Η ταινία σταμάτησε όταν βγήκες από το DadSaga.")
        #expect(setup.makeTitle == "Φτιάξ' την ξανά")
        #expect(setup.selectedFormat == .wide)
        #expect(renderer.films.isEmpty)

        await renderer.end(.film)
        await sut.makeFilm(reduceMotion: false)

        let scripts = await renderer.scripts
        #expect(scripts.count == 2)
        #expect(scripts.first == scripts.last)
        #expect(finished(sut)?.format == .wide)
    }

    @Test("Given the choices, when the app goes to the background and comes back, then nothing has changed")
    func leavingTheAppWhileChoosing() async throws {
        let sut = makeSUT()
        await sut.onAppear()
        let before = sut.state

        sut.appWentToBackground()

        #expect(sut.state == before)
    }

    @Test("Given the renderer fails, when making the film, then the choices say so and offer to make it again")
    func failing() async throws {
        let sut = makeSUT()
        await sut.onAppear()
        await renderer.end(.failure)

        await sut.makeFilm(reduceMotion: false)

        let setup = try #require(choices(sut))
        #expect(setup.notice == "Δεν φτιάχτηκε η ταινία. Δοκίμασε ξανά.")
        #expect(setup.makeTitle == "Φτιάξ' την ξανά")

        sut.selectFormat(.wide)
        #expect(choices(sut)?.notice == nil)
        #expect(choices(sut)?.makeTitle == "Φτιάξε την ταινία")
    }

    @Test("Given a phone with no room left, when making the film, then the choices say to free up space, also after leaving the app")
    func failingOnAFullDisk() async throws {
        let sut = makeSUT()
        await sut.onAppear()
        await renderer.end(.noSpace)

        await sut.makeFilm(reduceMotion: false)

        let notice = "Δεν υπάρχει αρκετός ελεύθερος χώρος σε αυτό το iPhone. Ελευθέρωσε λίγο χώρο και δοκίμασε ξανά."
        #expect(choices(sut)?.notice == notice)
        sut.appWentToBackground()
        #expect(choices(sut)?.notice == notice)
    }

    @Test("Given the film fails as the dad leaves, when the app is in the background a moment later, then it says he left")
    func failingJustBeforeTheBackground() async throws {
        let clock = FilmClock()
        let sut = makeSUT(now: { clock.now })
        await sut.onAppear()
        // iOS refused the encoder its drawing before the sheet heard that the app had left.
        await renderer.end(.failure)
        await sut.makeFilm(reduceMotion: false)

        clock.advance(seconds: 0.5)
        sut.appWentToBackground()

        let setup = try #require(choices(sut))
        #expect(setup.notice == "Η ταινία σταμάτησε όταν βγήκες από το DadSaga.")
        #expect(setup.makeTitle == "Φτιάξ' την ξανά")
    }

    @Test("Given a film that failed a while ago, when the dad leaves the app, then the choices still say it wasn't made")
    func failingLongBeforeTheBackground() async throws {
        let clock = FilmClock()
        let sut = makeSUT(now: { clock.now })
        await sut.onAppear()
        await renderer.end(.failure)
        await sut.makeFilm(reduceMotion: false)

        clock.advance(seconds: 60)
        sut.appWentToBackground()

        #expect(choices(sut)?.notice == "Δεν φτιάχτηκε η ταινία. Δοκίμασε ξανά.")
    }

    @Test("Given a failed film and then another choice, when the app goes to the background, then no notice comes back")
    func choosingAfterAFailure() async throws {
        let sut = makeSUT()
        await sut.onAppear()
        await renderer.end(.failure)
        await sut.makeFilm(reduceMotion: false)
        sut.selectFormat(.wide)

        sut.appWentToBackground()

        #expect(choices(sut)?.notice == nil)
    }

    // MARK: Leaving

    @Test("Given a made film, when the sheet closes, then its file is gone")
    func closingDeletesTheFilm() async throws {
        let sut = makeSUT()
        await sut.onAppear()
        await sut.makeFilm(reduceMotion: false)
        let url = try #require(finished(sut)?.url)
        #expect(FileManager.default.fileExists(atPath: url.path))

        await sut.close()
        await sut.close()

        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(renderer.films.isEmpty)
        #expect(choices(sut) != nil)
    }

    @Test("Given a film being made, when the sheet closes, then the film has stopped and nothing is left once it returns")
    func closingWhileMaking() async throws {
        let sut = makeSUT()
        await sut.onAppear()
        let film = await startFilm(sut)

        await sut.close()

        #expect(renderer.films.isEmpty)
        #expect(choices(sut)?.notice == nil)
        await film.value
        #expect(choices(sut)?.notice == nil)
    }

    @Test("Given a made film, when the dad makes another, then the earlier file is gone and the choices show")
    func makingAnother() async throws {
        let sut = makeSUT()
        await sut.onAppear()
        await sut.makeFilm(reduceMotion: false)
        let url = try #require(finished(sut)?.url)

        await sut.makeAnother()

        #expect(!FileManager.default.fileExists(atPath: url.path))
        let setup = try #require(choices(sut))
        #expect(setup.notice == nil)
        #expect(setup.makeTitle == "Φτιάξε την ταινία")
        #expect(setup.selectedPeriodID == "year-2")
    }

    @Test("Given a made film, when the sheet appears again from under the share sheet, then the film is still there")
    func appearingAgainKeepsTheFilm() async throws {
        let getFilm = FakeGetSagaFilm()
        let sut = makeSUT(getFilm)
        await sut.onAppear()
        await sut.makeFilm(reduceMotion: false)
        let film = try #require(finished(sut))

        await sut.onAppear()

        #expect(finished(sut) == film)
        #expect(FileManager.default.fileExists(atPath: film.url.path))
        #expect(await getFilm.asked.count == 1)
    }
}
