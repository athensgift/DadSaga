import Application
import Domain
import Foundation
@testable import Presentation
import Testing

/// The film's music: chosen from the bundled tracks, heard before choosing, and remembered (ADR-0046).
@MainActor
@Suite("SagaFilmViewModel: music", .timeLimit(.minutes(1)))
struct SagaFilmMusicTests: SagaFilmSheetTests {
    let renderer = FakeFilmRenderer()
    let previewer = FakeMusicPreviewer()

    /// Starts the chosen track's preview and returns once it sounds.
    func listen(_ sut: SagaFilmViewModel) async {
        var started = previewer.started.makeAsyncIterator()
        sut.listenToMusic()
        _ = await started.next()
    }

    // MARK: Choosing

    @Test("Given the lullaby remembered, when the sheet opens, then it offers every track with its mood, the lullaby chosen",
          arguments: [
            ("el_GR", "Μουσική", [
                SagaFilmMusicChoice(id: "theme", title: "Το θέμα της ιστορίας", mood: "Απαλό και αισιόδοξο"),
                SagaFilmMusicChoice(
                    id: "lullaby", title: "Νανούρισμα για μουσικό κουτί", mood: "Τρυφερό και αργό, για ήσυχες στιγμές"
                )
            ], "Άκουσε τη μουσική"),
            ("en_US", "Music", [
                SagaFilmMusicChoice(id: "theme", title: "Saga Theme", mood: "Gentle and hopeful"),
                SagaFilmMusicChoice(id: "lullaby", title: "Music Box Lullaby", mood: "Tender and slow, for quiet moments")
            ], "Listen to the music")
          ])
    func offersTheTracks(locale: String, label: String, expected: [SagaFilmMusicChoice], listen: String) async throws {
        let getFilm = FakeGetSagaFilm()
        await getFilm.choices.setSoundtrackID("lullaby")
        let sut = makeSUT(getFilm, locale: locale, previewer: previewer)

        await sut.onAppear()

        let music = try #require(choices(sut)?.music)
        #expect(music == SagaFilmMusicSetup(
            label: label, choices: expected, selectedID: "lullaby", isPlaying: false, actionTitle: listen
        ))
        // Nothing plays until the dad asks: the sheet may be next to a sleeping child.
        #expect(previewer.played.isEmpty)
    }

    @Test("Given the lullaby chosen, when making the film, then it plays the lullaby and credits it in the film's language",
          arguments: [("el_GR", "Νανούρισμα για μουσικό κουτί · DadSaga"), ("en_US", "Music Box Lullaby · DadSaga")])
    func chosenTrackInTheFilm(locale: String, credit: String) async throws {
        let sut = makeSUT(locale: locale, previewer: previewer)
        await sut.onAppear()
        await sut.selectMusic(id: "lullaby")?.value

        await sut.makeFilm(reduceMotion: false)

        let script = try #require(await renderer.scripts.first)
        #expect(script.music == FilmStub.lullaby.audioURL)
        guard case .credits(let credits) = script.scenes.last?.card else {
            Issue.record("Expected credits, got \(String(describing: script.scenes.last))")
            return
        }
        #expect(credits.lines.last?.name == credit)
    }

    @Test("Given the lullaby chosen, when the next sheet opens, then it is chosen, and stays so for another child or period")
    func choiceIsRemembered() async throws {
        let getFilm = FakeGetSagaFilm(profile: FilmStub.family)
        let first = makeSUT(getFilm, previewer: previewer)
        await first.onAppear()
        #expect(choices(first)?.music.selectedID == "theme")

        await first.selectMusic(id: "lullaby")?.value
        #expect(choices(first)?.music.selectedID == "lullaby")

        let next = makeSUT(getFilm, previewer: previewer)
        await next.onAppear()
        #expect(choices(next)?.music.selectedID == "lullaby")
        await next.selectPeriod(id: "everything")
        #expect(choices(next)?.music.selectedID == "lullaby")
        await next.selectChild(id: FilmStub.niko.id)
        #expect(choices(next)?.music.selectedID == "lullaby")
    }

    @Test("Given a track that isn't bundled, when choosing it, then nothing changes and nothing is saved")
    func unknownTrack() async throws {
        let getFilm = FakeGetSagaFilm()
        let sut = makeSUT(getFilm, previewer: previewer)
        await sut.onAppear()

        #expect(sut.selectMusic(id: "gone") == nil)
        #expect(sut.selectMusic(id: "theme") == nil)

        #expect(choices(sut)?.music.selectedID == "theme")
        #expect(getFilm.choices.saves.isEmpty)
    }

    @Test("Given dates and music changed at once, when they are saved, then in order, in one queue, the newest kept")
    func savedInOneQueue() async throws {
        let getFilm = FakeGetSagaFilm()
        let sut = makeSUT(getFilm, previewer: previewer)
        await sut.onAppear()

        sut.setShowsDates(false)
        sut.selectMusic(id: "lullaby")
        await sut.setShowsDates(true)?.value

        #expect(getFilm.choices.saves == [.dates(false), .music("lullaby"), .dates(true)])
        #expect(await getFilm.choices.soundtrackID() == "lullaby")
        #expect(await getFilm.choices.showsDates())
    }

    @Test("Given a notice over the choices, when listening, then it stays; when choosing a track, then it goes")
    func choosingClearsTheNotice() async throws {
        let sut = makeSUT(previewer: previewer)
        await sut.onAppear()
        await renderer.end(.failure)
        await sut.makeFilm(reduceMotion: false)
        let notice = try #require(choices(sut)?.notice)

        await listen(sut)
        #expect(choices(sut)?.notice == notice)

        sut.selectMusic(id: "lullaby")
        #expect(choices(sut)?.notice == nil)
        #expect(choices(sut)?.makeTitle == "Φτιάξε την ταινία")
    }

    // MARK: Listening

    @Test("Given the sheet open, when listening and then stopping, then the chosen track plays from its start and stops")
    func listenThenStop() async throws {
        let sut = makeSUT(previewer: previewer)
        await sut.onAppear()
        var returned = previewer.returned.makeAsyncIterator()

        await listen(sut)
        #expect(previewer.sounding == FilmStub.theme.audioURL)
        #expect(choices(sut)?.music.isPlaying == true)
        #expect(choices(sut)?.music.actionTitle == "Σταμάτα τη μουσική")

        sut.stopMusic()
        #expect(choices(sut)?.music.isPlaying == false)
        #expect(choices(sut)?.music.actionTitle == "Άκουσε τη μουσική")
        _ = await returned.next()
        #expect(previewer.sounding == nil)
        #expect(previewer.played == [FilmStub.theme.audioURL])
    }

    @Test("Given a track playing, when choosing another, then the new one plays from its start; with none playing, none does")
    func choosingWhilePlaying() async throws {
        let sut = makeSUT(previewer: previewer)
        await sut.onAppear()
        var started = previewer.started.makeAsyncIterator()
        var returned = previewer.returned.makeAsyncIterator()

        sut.listenToMusic()
        #expect(await started.next() == FilmStub.theme.audioURL)
        sut.selectMusic(id: "lullaby")
        #expect(await started.next() == FilmStub.lullaby.audioURL)
        #expect(await returned.next() == FilmStub.theme.audioURL)
        #expect(previewer.sounding == FilmStub.lullaby.audioURL)
        #expect(choices(sut)?.music.isPlaying == true)

        sut.stopMusic()
        _ = await returned.next()
        sut.selectMusic(id: "theme")
        #expect(choices(sut)?.music.isPlaying == false)
        #expect(previewer.sounding == nil)
        #expect(previewer.played == [FilmStub.theme.audioURL, FilmStub.lullaby.audioURL])
    }

    enum Interruption: CaseIterable, Sendable {
        case makingTheFilm, closing, leavingTheApp, aFilmThatCantLoad
    }

    @Test("Given a track playing, when the film is made, the sheet closes, the app leaves or a film can't load, then it stops",
          arguments: Interruption.allCases)
    func stops(on interruption: Interruption) async throws {
        let getFilm = FakeGetSagaFilm()
        let sut = makeSUT(getFilm, previewer: previewer)
        await sut.onAppear()
        var returned = previewer.returned.makeAsyncIterator()
        await listen(sut)

        switch interruption {
        case .makingTheFilm:
            await sut.makeFilm(reduceMotion: false)
            #expect(finished(sut) != nil)
        case .closing:
            await sut.close()
            #expect(choices(sut)?.music.isPlaying == false)
        case .leavingTheApp:
            sut.appWentToBackground()
            #expect(choices(sut)?.music.isPlaying == false)
        case .aFilmThatCantLoad:
            await getFilm.bundle([])
            await sut.selectPeriod(id: "everything")
            guard case .unavailable = sut.state else {
                Issue.record("Expected the film unavailable, got \(sut.state)")
                return
            }
        }
        _ = await returned.next()
        #expect(previewer.sounding == nil)
        #expect(previewer.played == [FilmStub.theme.audioURL])
    }

    @Test("Given a preview that plays to its end, when it ends, then the button offers listening again")
    func previewEnds() async throws {
        let sut = makeSUT(previewer: previewer)
        await sut.onAppear()
        var returned = previewer.returned.makeAsyncIterator()
        await listen(sut)

        previewer.finish()
        _ = await returned.next()
        await Task.yield()

        #expect(choices(sut)?.music.isPlaying == false)
        await listen(sut)
        #expect(previewer.played == [FilmStub.theme.audioURL, FilmStub.theme.audioURL])
    }

    @Test("Given a preview stopped and another started, when the first ends late, then the second still plays")
    func lateEndDoesNotStopTheNext() async throws {
        let sut = makeSUT(previewer: previewer)
        await sut.onAppear()
        var returned = previewer.returned.makeAsyncIterator()
        await listen(sut)

        sut.stopMusic()
        await listen(sut)
        #expect(await returned.next() == FilmStub.theme.audioURL)
        await Task.yield()

        #expect(choices(sut)?.music.isPlaying == true)
        #expect(previewer.sounding == FilmStub.theme.audioURL)
    }
}
