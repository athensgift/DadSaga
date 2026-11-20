import Data
import Foundation
import Testing

@Suite("Film sheet choices in UserDefaults")
struct SagaFilmChoicesRepositoryTests {
    let suite = "SagaFilmChoicesRepositoryTests-\(UUID().uuidString)"

    func defaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: suite))
    }

    @Test("Given nothing stored, when reading the switch, then films show their dates")
    func onByDefault() async throws {
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        #expect(await UserDefaultsSagaFilmChoicesRepository(defaults: try defaults()).showsDates())
    }

    @Test("Given the switch turned off, when a new repository reads it, then it stays off under its own key")
    func keepsOff() async throws {
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        await UserDefaultsSagaFilmChoicesRepository(defaults: try defaults()).setShowsDates(false)

        #expect(await !UserDefaultsSagaFilmChoicesRepository(defaults: try defaults()).showsDates())
        #expect(try defaults().object(forKey: "sagaFilm.showsDates") as? Bool == false)
    }

    @Test("Given nothing stored, when reading the music, then no track is chosen")
    func noTrackByDefault() async throws {
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        #expect(await UserDefaultsSagaFilmChoicesRepository(defaults: try defaults()).soundtrackID() == nil)
    }

    @Test("Given a track chosen, when a new repository reads it, then it is kept under its own key, dates untouched")
    func keepsTrack() async throws {
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        await UserDefaultsSagaFilmChoicesRepository(defaults: try defaults()).setSoundtrackID("music-box-lullaby")

        #expect(await UserDefaultsSagaFilmChoicesRepository(defaults: try defaults()).soundtrackID() == "music-box-lullaby")
        #expect(try defaults().string(forKey: "sagaFilm.soundtrackID") == "music-box-lullaby")
        #expect(try defaults().object(forKey: "sagaFilm.showsDates") == nil)
    }
}
