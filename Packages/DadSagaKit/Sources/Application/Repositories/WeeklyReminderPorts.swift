import Domain
import Foundation

/// Port for the dad's weekly reminder settings (ADR-0024).
public protocol ReminderSettingsRepository: Sendable {
    /// `WeeklyReminder.default` until something was saved.
    func fetch() async -> WeeklyReminder
    func save(_ reminder: WeeklyReminder) async
    /// Only the developer reset uses this.
    func deleteAll() async
}

/// What iOS currently allows.
public enum NotificationAuthorization: Hashable, Sendable {
    /// iOS has never asked the dad.
    case notDetermined
    case denied
    case allowed
}

/// One notification waiting to be delivered.
public struct PendingReminder: Hashable, Sendable {
    /// The wall-clock day and time it is due (year, month, day, hour, minute), with no time zone, so it arrives at
    /// that time on the phone's clock wherever the dad is, even if he travels before it fires.
    public let time: DateComponents
    public let title: String
    public let body: String
    /// What a tap opens.
    public let link: AppLink

    public init(time: DateComponents, title: String, body: String, link: AppLink) {
        self.time = time
        self.title = title
        self.body = body
        self.link = link
    }
}

/// Port for the system's local notifications. Nothing leaves the device (ADR-0004).
public protocol NotificationScheduler: Sendable {
    func authorization() async -> NotificationAuthorization
    /// Shows the iOS prompt. `true` if the dad allowed notifications.
    func requestAuthorization() async -> Bool
    /// Removes every DadSaga notification still waiting and schedules these instead.
    func replacePending(with reminders: [PendingReminder]) async
}

/// Port for the words of the weekly notification, in the dad's language. Presentation implements it.
public protocol ReminderTextProvider: Sendable {
    func title() -> String
    /// - Parameter childName: only when there are several children.
    func body(questTitle: LocalizedText, childName: String?) -> String
}
