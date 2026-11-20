import Data
import Foundation
import Testing

@Suite("Film dates switch in UserDefaults")
struct SagaFilmDatesRepositoryTests {
    let suite = "SagaFilmDatesRepositoryTests-\(UUID().uuidString)"

    func defaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: suite))
    }

    @Test("Given nothing stored, when reading the switch, then films show their dates")
    func onByDefault() async throws {
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        #expect(await UserDefaultsSagaFilmDatesRepository(defaults: try defaults()).showsDates())
    }

    @Test("Given the switch turned off, when a new repository reads it, then it stays off under its own key")
    func keepsOff() async throws {
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        await UserDefaultsSagaFilmDatesRepository(defaults: try defaults()).setShowsDates(false)

        #expect(await !UserDefaultsSagaFilmDatesRepository(defaults: try defaults()).showsDates())
        #expect(try defaults().object(forKey: "sagaFilm.showsDates") as? Bool == false)
    }
}
