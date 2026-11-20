import Application
import Domain
import Foundation
@testable import Presentation
import Synchronization
import Testing

/// What both suites of the film sheet's tests share: a sheet over the fake renderer, and its state by name.
@MainActor
protocol SagaFilmSheetTests {
    var renderer: FakeFilmRenderer { get }
}

extension SagaFilmSheetTests {
    func makeSUT(
        _ getFilm: FakeGetSagaFilm = FakeGetSagaFilm(),
        childID: UUID? = nil,
        locale: String = "el_GR",
        now: @escaping @Sendable () -> Date = { FilmStub.today }
    ) -> SagaFilmViewModel {
        SagaFilmViewModel(
            request: SagaFilmRequest(childID: childID),
            getFilm: getFilm,
            renderer: renderer,
            locale: Locale(identifier: locale),
            now: now
        )
    }

    func choices(_ sut: SagaFilmViewModel) -> SagaFilmSetup? {
        guard case .ready(let setup) = sut.state else {
            Issue.record("Expected the choices, got \(sut.state)")
            return nil
        }
        return setup
    }

    func finished(_ sut: SagaFilmViewModel) -> SagaFilmMade? {
        guard case .made(let made) = sut.state else {
            Issue.record("Expected a made film, got \(sut.state)")
            return nil
        }
        return made
    }

    func inProgress(_ sut: SagaFilmViewModel) -> SagaFilmMaking? {
        guard case .making(let making) = sut.state else {
            Issue.record("Expected a film being made, got \(sut.state)")
            return nil
        }
        return making
    }

    /// Starts a film that waits after its progress, and returns once that progress has been shown.
    func startFilm(_ sut: SagaFilmViewModel, reporting steps: [Double] = [0.5]) async -> Task<Void, Never> {
        await renderer.end(.wait, reporting: steps)
        let film = Task { await sut.makeFilm(reduceMotion: false) }
        var reported = renderer.reported.makeAsyncIterator()
        _ = await reported.next()
        return film
    }

    /// Every word a film shows.
    func words(of script: SagaFilmScript) -> [String] {
        script.scenes.flatMap { scene -> [String] in
            switch scene.card {
            case .opening(let name, let period, _): [name, period]
            case .chapter(let heading, let title, let tagline): [heading, title, tagline]
            case .first(let emoji, let title, let note, _): [emoji, title, note ?? ""]
            case .boss(let badge, let title, _): [badge, title]
            case .photo: []
            case .credits(let credits): credits.lines.flatMap { [$0.role, $0.name] } + [credits.signature]
            }
        }
    }
}

extension SagaFilmCard {
    func isOpening(period expected: String) -> Bool {
        if case .opening(_, let period, _) = self { period == expected } else { false }
    }
}

/// A clock the test moves by hand.
final class FilmClock: Sendable {
    private let time = Mutex(FilmStub.today)

    var now: Date { time.withLock(\.self) }

    func advance(seconds: Double) {
        time.withLock { $0 += seconds }
    }
}
