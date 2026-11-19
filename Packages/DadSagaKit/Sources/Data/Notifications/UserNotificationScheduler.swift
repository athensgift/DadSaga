import Application
import Foundation
import UserNotifications

/// Local notifications through `UNUserNotificationCenter` (ADR-0024). Nothing leaves the device.
public struct UserNotificationScheduler: NotificationScheduler {
    /// Where a delivered notification keeps the link a tap opens.
    public static let linkKey = "link"
    static let idPrefix = "weekly-quest-"

    public init() {}

    private var center: UNUserNotificationCenter { .current() }

    public func authorization() async -> NotificationAuthorization {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .authorized, .provisional, .ephemeral: .allowed
        default: .denied
        }
    }

    public func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    public func replacePending(with reminders: [PendingReminder]) async {
        let old = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)
        for (index, reminder) in reminders.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.userInfo = [Self.linkKey: reminder.link.url.absoluteString]
            let request = UNNotificationRequest(
                identifier: Self.idPrefix + String(index),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: reminder.time, repeats: false)
            )
            try? await center.add(request)
        }
    }

    public func removeDelivered() async {
        let shown = await center.deliveredNotifications().map(\.request.identifier).filter { $0.hasPrefix(Self.idPrefix) }
        center.removeDeliveredNotifications(withIdentifiers: shown)
    }
}
