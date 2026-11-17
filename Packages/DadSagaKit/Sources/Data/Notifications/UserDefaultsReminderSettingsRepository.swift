import Application
import Domain
import Foundation

/// Keeps the weekly reminder settings in the app's own defaults. Only the app reads them (ADR-0024).
public struct UserDefaultsReminderSettingsRepository: ReminderSettingsRepository, @unchecked Sendable {
    // UserDefaults is thread-safe; it is just not marked Sendable.
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "weeklyReminder") {
        self.defaults = defaults
        self.key = key
    }

    public func fetch() async -> WeeklyReminder {
        guard let data = defaults.data(forKey: key),
              let dto = try? JSONDecoder().decode(WeeklyReminderDTO.self, from: data)
        else { return .default }
        return WeeklyReminder(
            isEnabled: dto.isEnabled,
            weekday: dto.weekday,
            hour: dto.hour,
            minute: dto.minute,
            wasOffered: dto.wasOffered
        )
    }

    public func save(_ reminder: WeeklyReminder) async {
        let dto = WeeklyReminderDTO(
            isEnabled: reminder.isEnabled,
            weekday: reminder.weekday,
            hour: reminder.hour,
            minute: reminder.minute,
            wasOffered: reminder.wasOffered
        )
        defaults.set(try? JSONEncoder().encode(dto), forKey: key)
    }

    public func deleteAll() async {
        defaults.removeObject(forKey: key)
    }
}

private struct WeeklyReminderDTO: Codable {
    let isEnabled: Bool
    let weekday: Int
    let hour: Int
    let minute: Int
    let wasOffered: Bool
}
