import Data
import Domain
import Foundation
import Testing

@Suite("Reminder settings in UserDefaults")
struct ReminderSettingsRepositoryTests {
    let suite = "ReminderSettingsRepositoryTests-\(UUID().uuidString)"

    func makeRepository() throws -> UserDefaultsReminderSettingsRepository {
        UserDefaultsReminderSettingsRepository(defaults: try #require(UserDefaults(suiteName: suite)))
    }

    @Test("Given nothing saved, when fetching, then it is off on Saturday at 10:00 and not offered")
    func defaults() async throws {
        #expect(try await makeRepository().fetch() == .default)
    }

    @Test("Given saved settings, when a new repository reads them, then they come back; after delete, the default")
    func roundTrip() async throws {
        let reminder = WeeklyReminder(isEnabled: true, weekday: 1, hour: 18, minute: 30, wasOffered: true)
        try await makeRepository().save(reminder)

        #expect(try await makeRepository().fetch() == reminder)

        try await makeRepository().deleteAll()
        #expect(try await makeRepository().fetch() == .default)
        UserDefaults().removePersistentDomain(forName: suite)
    }
}
