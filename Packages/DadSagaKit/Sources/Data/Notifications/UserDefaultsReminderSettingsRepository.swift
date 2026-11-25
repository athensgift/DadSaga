import Application
import Domain
import Foundation

/// Keeps the weekly reminder settings, and when its notes are due, in the app's own defaults. Only the app reads them
/// (ADR-0024).
public struct UserDefaultsReminderSettingsRepository: ReminderSettingsRepository, @unchecked Sendable {
    // UserDefaults is thread-safe; it is just not marked Sendable.
    private let defaults: UserDefaults
    private let key: String
    private var noteTimesKey: String { key + "NoteTimes" }

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

    public func noteTimes() async -> [DateComponents] {
        guard let data = defaults.data(forKey: noteTimesKey),
              let dtos = try? JSONDecoder().decode([NoteTimeDTO].self, from: data)
        else { return [] }
        return dtos.map(\.time)
    }

    public func saveNoteTimes(_ times: [DateComponents]) async {
        defaults.set(try? JSONEncoder().encode(times.map(NoteTimeDTO.init)), forKey: noteTimesKey)
    }

    public func deleteAll() async {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: noteTimesKey)
    }
}

private struct WeeklyReminderDTO: Codable {
    let isEnabled: Bool
    let weekday: Int
    let hour: Int
    let minute: Int
    let wasOffered: Bool
}

private struct NoteTimeDTO: Codable {
    let year: Int?
    let month: Int?
    let day: Int?
    let hour: Int?
    let minute: Int?

    init(_ time: DateComponents) {
        year = time.year
        month = time.month
        day = time.day
        hour = time.hour
        minute = time.minute
    }

    var time: DateComponents {
        DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    }
}
