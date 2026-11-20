import Application
import Domain
import Foundation
@testable import Presentation
import Testing

@MainActor
@Suite("SagaFilmViewModel: the choices and the script", .timeLimit(.minutes(1)))
struct SagaFilmViewModelTests: SagaFilmSheetTests {
    let renderer = FakeFilmRenderer()

    // MARK: Choices

    @Test("Given a second birthday five days ago, when the sheet opens, then it offers each period with year two chosen")
    func offersPeriods() async throws {
        let greek = makeSUT()
        await greek.onAppear()
        let english = makeSUT(locale: "en_US")
        await english.onAppear()

        let setup = try #require(choices(greek))
        #expect(greek.title == "Ταινία της ιστορίας")
        #expect(setup.periods.map(\.title) == ["1ος χρόνος", "2ος χρόνος", "Σπηλιά", "Πεδιάδες", "Όλη η ιστορία"])
        #expect(setup.periods.map(\.id) == ["year-1", "year-2", "world-w1", "world-w2", "everything"])
        #expect(setup.selectedPeriodID == "year-2")
        #expect(setup.formats.map(\.title) == ["Κάθετη", "Οριζόντια"])
        #expect(setup.selectedFormat == .vertical)
        #expect(setup.makeTitle == "Φτιάξε την ταινία")
        #expect(setup.notice == nil)
        #expect(setup.emptyMessage == nil)
        #expect(choices(english)?.periods.map(\.title) == ["Year 1", "Year 2", "Cave", "Plains", "The whole saga"])
        #expect(choices(english)?.makeTitle == "Make the film")
    }

    @Test("Given one child, when the sheet opens, then there is no child to choose")
    func oneChild() async throws {
        let sut = makeSUT()
        await sut.onAppear()

        let setup = try #require(choices(sut))
        #expect(setup.children.isEmpty)
        #expect(setup.selectedChildID == FilmStub.anna.id)
    }

    @Test("Given two children, when the sheet opens for the second, then both names show and the second is chosen")
    func siblings() async throws {
        let sut = makeSUT(FakeGetSagaFilm(profile: FilmStub.family), childID: FilmStub.niko.id)
        await sut.onAppear()

        let setup = try #require(choices(sut))
        #expect(setup.children.map(\.name) == ["Άννα", "Νίκος"])
        #expect(setup.selectedChildID == FilmStub.niko.id)
    }

    @Test("Given two children, when choosing the other, then the choices are hers, with the period her day suggests")
    func choosingAChild() async throws {
        let getFilm = FakeGetSagaFilm(profile: FilmStub.family)
        let sut = makeSUT(getFilm, childID: FilmStub.niko.id)
        await sut.onAppear()

        await sut.selectChild(id: FilmStub.anna.id)

        let setup = try #require(choices(sut))
        #expect(setup.selectedChildID == FilmStub.anna.id)
        #expect(setup.selectedPeriodID == "year-2")
        #expect(setup.makeTitle == "Φτιάξε την ταινία")
        #expect(await getFilm.asked == [nil, nil])
    }

    @Test("Given two periods chosen one after the other, when the first is answered last, then the sheet shows the second")
    func aLateAnswerDoesNotWin() async throws {
        let getFilm = FakeGetSagaFilm()
        let sut = makeSUT(getFilm)
        await sut.onAppear()
        await getFilm.holdNext()
        let first = Task { await sut.selectPeriod(id: "year-1") }
        var reached = getFilm.reached.makeAsyncIterator()
        _ = await reached.next()

        await sut.selectPeriod(id: "everything")
        getFilm.letGo()
        await first.value

        #expect(choices(sut)?.selectedPeriodID == "everything")
    }

    @Test("Given a child with nothing captured yet, when the sheet opens, then a calm line stands where the button would")
    func nothingToMake() async throws {
        let sut = makeSUT(FakeGetSagaFilm(profile: FilmStub.family), childID: FilmStub.niko.id)
        await sut.onAppear()

        let setup = try #require(choices(sut))
        #expect(setup.makeTitle == nil)
        #expect(setup.emptyMessage == "Οι φωτογραφίες και οι στιγμές που καταγράφεις θα γίνουν εδώ ταινία.")
        #expect(setup.emptyMessage?.localizedCaseInsensitiveContains("δεν") == false)
        #expect(setup.periods.map(\.id) == ["everything"])

        await sut.makeFilm(reduceMotion: false)
        #expect(await renderer.scripts.isEmpty)
        #expect(choices(sut) == setup)
    }

    @Test("Given no bundled music, when the sheet opens, then it says so calmly, and trying again loads the choices")
    func noMusic() async throws {
        let getFilm = FakeGetSagaFilm(soundtrack: nil)
        let sut = makeSUT(getFilm)
        await sut.onAppear()

        let notice = SagaFilmNotice(message: "Η ταινία δεν μπορεί να φτιαχτεί τώρα.", actionTitle: "Δοκίμασε ξανά")
        #expect(sut.state == .unavailable(notice))

        await getFilm.bundle(FilmStub.theme)
        await sut.reload()
        #expect(choices(sut)?.selectedPeriodID == "year-2")
    }

    // MARK: The script

    @Test("Given the whole saga, when making the film, then the renderer gets its scenes in order, in the dad's words")
    func scriptOfTheWholeSaga() async throws {
        let sut = makeSUT()
        await sut.onAppear()
        await sut.selectPeriod(id: "everything")

        await sut.makeFilm(reduceMotion: false)

        let script = try #require(await renderer.scripts.first)
        guard case .opening(let name, let period, let drawn) = script.scenes.first?.card else {
            Issue.record("Expected an opening, got \(String(describing: script.scenes.first))")
            return
        }
        #expect(name == "Άννα")
        #expect(period == "Όλη η ιστορία")
        #expect(drawn.hero == .cool)
        #expect(drawn.heroSkin == .mediumDark)
        #expect(drawn.heroGear == [.burpCloth])
        #expect(drawn.medals == 1)
        #expect(drawn.child.name == "Άννα")
        #expect(drawn.child.stage == .toddler)
        #expect(drawn.child.traits == [.smile, .walks])
        #expect(script.scenes.dropFirst().map(\.card) == [
            .chapter(heading: "Κεφάλαιο 1", title: "Σπηλιά", tagline: "Οι πρώτες μέρες"),
            .first(emoji: "😊", title: "Πρώτο χαμόγελο", note: "Χαμογέλασε στον παππού", photoID: "p-smile"),
            .photo(photoID: "p-walk-1"),
            .boss(badge: "Πυρετομάχος", title: "Πρώτος πυρετός", photoID: nil),
            .chapter(heading: "Κεφάλαιο 2", title: "Πεδιάδες", tagline: "Όλα κινούνται"),
            .first(emoji: "👣", title: "Πρώτα βήματα", note: nil, photoID: nil),
            .photo(photoID: "p-walk-2"),
            .credits(SagaFilmCredits(
                lines: [
                    SagaFilmCreditLine(role: "Πρωταγωνιστεί", name: "Άννα"),
                    SagaFilmCreditLine(role: "Ο ήρωας", name: "Cool Μπαμπάς"),
                    SagaFilmCreditLine(role: "Μαζί", name: "4 αποστολές · 1 αφεντικό"),
                    SagaFilmCreditLine(role: "Μουσική", name: "Saga Theme · DadSaga")
                ],
                signature: "Φτιαγμένο με το DadSaga"
            ))
        ])
        #expect(script.scenes.map(\.seconds) == [3.5, 2.5, 4.5, 2.5, 3.5, 2.5, 3, 2.5, 6])
        #expect(script.music == FilmStub.theme.audioURL)
        #expect(script.title == "Άννα – DadSaga")
    }

    @Test("Given year two with quests and no boss, when making the film, then its credits count the quests alone")
    func creditsLeaveOutZero() async throws {
        let sut = makeSUT(locale: "en_US")
        await sut.onAppear()

        await sut.makeFilm(reduceMotion: false)

        let script = try #require(await renderer.scripts.first)
        guard case .credits(let credits) = script.scenes.last?.card else {
            Issue.record("Expected credits, got \(String(describing: script.scenes.last))")
            return
        }
        #expect(credits.lines.map(\.role) == ["Starring", "The hero", "Together", "Music"])
        #expect(credits.lines.map(\.name) == ["Άννα", "Cool Dad", "2 quests", "Saga Theme · DadSaga"])
        #expect(credits.signature == "Made with DadSaga")
        #expect(script.scenes.first?.card.isOpening(period: "Year 2") == true)
    }

    @Test("Given a public-domain track, when making the film, then the credits say so after its title and artist")
    func creditsOfAPublicDomainTrack() async throws {
        let track = Soundtrack(
            id: "cc0", title: "Lullaby", artist: "A. Composer", licence: .cc0, audioURL: FilmStub.theme.audioURL
        )
        let sut = makeSUT(FakeGetSagaFilm(soundtrack: track))
        await sut.onAppear()

        await sut.makeFilm(reduceMotion: false)

        guard case .credits(let credits) = await renderer.scripts.first?.scenes.last?.card else {
            Issue.record("Expected credits")
            return
        }
        #expect(credits.lines.last == SagaFilmCreditLine(role: "Μουσική", name: "Lullaby · A. Composer · Κοινό κτήμα (CC0)"))
    }

    @Test(
        "Given a saga with XP, levels, ages and dates, and a sibling, when making the film, then none of them is in it",
        arguments: ["el_GR", "en_US"]
    )
    func noPressureInTheFilm(locale: String) async throws {
        let brother = ProgressEvent(kind: .first(id: "f-smile"), childID: FilmStub.niko.id, date: FilmStub.today, note: "Νίκος")
        let sut = makeSUT(FakeGetSagaFilm(profile: FilmStub.family, events: FilmStub.annasSaga + [brother]), locale: locale)
        await sut.onAppear()
        await sut.selectPeriod(id: "everything")

        await sut.makeFilm(reduceMotion: false)

        let words = words(of: try #require(await renderer.scripts.first))
        #expect(words.count > 20)
        let months = ["el_GR", "en_US"].flatMap { identifier -> [String] in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: identifier)
            return (formatter.monthSymbols ?? []) + (formatter.standaloneMonthSymbols ?? [])
        }
        #expect(months.count == 48)
        let forbidden = ["XP", "Level", "Επίπεδο", "Lv", "months", "μηνών", "μήνες", "years old", "ετών", "Νίκος"] + months
        for word in words {
            #expect(!forbidden.contains { word.localizedCaseInsensitiveContains($0) }, "\(word)")
            // No year, no XP value (20, 30, 40, 100) and no age in months: the only numbers are small counts.
            #expect(word.matches(of: /\d{2,}/).isEmpty, "\(word)")
        }
    }

    @Test("Given a name with a slash and a colon, when making the film, then its file name is one safe component")
    func fileName() async throws {
        let child = Child(id: FilmStub.anna.id, name: "Άννα/Μαρία: η μικρή", birthDate: FilmStub.birth)
        let profile = PlayerProfile(children: [child], heroClassID: "h-cool")
        let sut = makeSUT(FakeGetSagaFilm(profile: profile))
        await sut.onAppear()

        await sut.makeFilm(reduceMotion: false)

        #expect(await renderer.scripts.first?.title == "Άννα-Μαρία- η μικρή – DadSaga")
        #expect(finished(sut)?.url.lastPathComponent == "Άννα-Μαρία- η μικρή – DadSaga.mp4")
    }

    @Test("Given a name longer than a file name can be, when making the film, then its file name still fits and ends the same")
    func longFileName() async throws {
        let child = Child(id: FilmStub.anna.id, name: String(repeating: "Άννα ", count: 60), birthDate: FilmStub.birth)
        let profile = PlayerProfile(children: [child], heroClassID: "h-cool")
        let sut = makeSUT(FakeGetSagaFilm(profile: profile))
        await sut.onAppear()

        await sut.makeFilm(reduceMotion: false)

        let name = try #require(finished(sut)?.url.lastPathComponent)
        #expect(name.utf8.count <= 255)
        #expect(name.hasPrefix("Άννα Άννα"))
        #expect(name.hasSuffix(" – DadSaga.mp4"))
    }

    @Test("Given Reduce Motion, when making the film, then the script asks for still photos", arguments: [true, false])
    func reduceMotion(isOn: Bool) async throws {
        let sut = makeSUT()
        await sut.onAppear()

        await sut.makeFilm(reduceMotion: isOn)

        #expect(await renderer.scripts.first?.reduceMotion == isOn)
    }

    @Test("Given the wide format chosen, when making the film, then the script and the made film are wide")
    func wide() async throws {
        let sut = makeSUT()
        await sut.onAppear()

        sut.selectFormat(.wide)
        #expect(choices(sut)?.selectedFormat == .wide)
        await sut.makeFilm(reduceMotion: false)

        #expect(await renderer.scripts.first?.format == .wide)
        #expect(finished(sut)?.format == .wide)
    }
}
