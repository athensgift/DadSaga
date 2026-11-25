import Data
import Domain
import Foundation
import Testing

@Suite("Film offer answers in UserDefaults")
struct SagaOfferRepositoryTests {
    let suite = "SagaOfferRepositoryTests-\(UUID().uuidString)"

    func defaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: suite))
    }

    func makeRepository() throws -> UserDefaultsSagaOfferRepository {
        UserDefaultsSagaOfferRepository(defaults: try defaults())
    }

    func cleanUp() {
        UserDefaults().removePersistentDomain(forName: suite)
    }

    @Test("Given nothing answered, when reading, then no occasion is answered")
    func nothingAnswered() async throws {
        defer { cleanUp() }
        #expect(try await makeRepository().answeredOccasionIDs().isEmpty)
    }

    @Test("Given two answered occasions, when a new repository reads them, then both come back with their ids intact")
    func survivesANewRepository() async throws {
        defer { cleanUp() }
        let birthday = "\(UUID().uuidString)/birthday/2"
        let world = "\(UUID().uuidString)/world/w1-newborn.cave"
        try await makeRepository().markAnswered(birthday)
        try await makeRepository().markAnswered(world)
        try await makeRepository().markAnswered(birthday)

        #expect(try await makeRepository().answeredOccasionIDs() == [birthday, world])
    }

    @Test("Given forty answers saved at the same moment, when reading, then every one is kept")
    func concurrentAnswers() async throws {
        defer { cleanUp() }
        let repository = try makeRepository()
        let ids = (1...40).map { "child/birthday/\($0)" }

        await withTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask { await repository.markAnswered(id) }
            }
        }

        #expect(await repository.answeredOccasionIDs() == Set(ids))
    }

    @Test("Given two children's answers, when one child is forgotten, then only the other's are left, for a new repository too")
    func forgetsOneChild() async throws {
        defer { cleanUp() }
        let gone = UUID()
        let stays = UUID()
        let kept: Set = ["\(stays.uuidString)/birthday/1", "\(stays.uuidString)/world/w1"]
        for id in kept.union(["\(gone.uuidString)/birthday/2", "\(gone.uuidString)/world/w2"]) {
            try await makeRepository().markAnswered(id)
        }

        try await makeRepository().forget(childID: gone)

        #expect(try await makeRepository().answeredOccasionIDs() == kept)
    }

    @Test("Given answers, the reminder and preferences in the same defaults, when deleting all, then only the answers go")
    func deleteAllKeepsTheRest() async throws {
        defer { cleanUp() }
        let preferences = UserDefaultsPreferencesRepository(defaults: try defaults())
        await preferences.save(Preferences(appearance: .dark, hapticsEnabled: false))
        let reminder = WeeklyReminder(isEnabled: true, weekday: 1, hour: 18, minute: 30, wasOffered: true)
        let reminders = UserDefaultsReminderSettingsRepository(defaults: try defaults())
        await reminders.save(reminder)
        try await makeRepository().markAnswered("child/birthday/1")
        try await makeRepository().markAnswered("child/world/w1")

        try await makeRepository().deleteAll()

        #expect(try await makeRepository().answeredOccasionIDs().isEmpty)
        #expect(await preferences.fetch() == Preferences(appearance: .dark, hapticsEnabled: false))
        #expect(await reminders.fetch() == reminder)
    }
}
