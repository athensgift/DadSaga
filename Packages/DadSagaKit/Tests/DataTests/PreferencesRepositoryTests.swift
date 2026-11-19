import Data
import Domain
import Foundation
import Testing

@Suite("Preferences in UserDefaults")
struct PreferencesRepositoryTests {
    let suite = "PreferencesRepositoryTests-\(UUID().uuidString)"

    func defaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: suite))
    }

    func makeRepository() throws -> UserDefaultsPreferencesRepository {
        UserDefaultsPreferencesRepository(defaults: try defaults())
    }

    func cleanUp() {
        UserDefaults().removePersistentDomain(forName: suite)
    }

    @Test("Given nothing saved, when fetching, then it follows the iPhone with haptics on")
    func nothingSaved() async throws {
        defer { cleanUp() }
        #expect(try await makeRepository().fetch() == .default)
    }

    @Test("Given each appearance with haptics off, when a new repository reads it, then it comes back")
    func roundTrip() async throws {
        defer { cleanUp() }
        for appearance in Appearance.allCases {
            let preferences = Preferences(appearance: appearance, hapticsEnabled: false)
            try await makeRepository().save(preferences)
            #expect(try await makeRepository().fetch() == preferences)
        }
    }

    @Test("Given an unknown stored appearance, when fetching, then it reads as Automatic and haptics are kept")
    func unknownValue() async throws {
        defer { cleanUp() }
        try defaults().set("sepia", forKey: "preferences.appearance")
        try defaults().set(false, forKey: "preferences.haptics")

        #expect(try await makeRepository().fetch() == Preferences(appearance: .system, hapticsEnabled: false))
    }

    @Test("Given only an appearance was ever stored, when fetching, then haptics are on")
    func fieldAddedLater() async throws {
        defer { cleanUp() }
        try defaults().set("dark", forKey: "preferences.appearance")

        #expect(try await makeRepository().fetch() == Preferences(appearance: .dark, hapticsEnabled: true))
    }
}
