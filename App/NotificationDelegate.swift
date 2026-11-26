import Data
import Observation
import UIKit
import UserNotifications

/// A link from a tapped notification, waiting for the app's screen. On a cold launch the tap arrives before the scene
/// exists, so it is kept here instead of being sent back through the URL scheme, where it could be dropped.
@MainActor
@Observable
final class NotificationInbox {
    static let shared = NotificationInbox()
    var url: URL?
}

/// Opens the quest of a tapped weekly notification through the app's own link (ADR-0024), the same link the widget
/// uses, and still shows the notification if it arrives while the app is open.
final class NotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // The completion-handler forms, each handler called on the main thread. The `async` forms finished on a background
    // thread, where UIKit's snapshot after a tap asserts: a tap with the app closed crashed it (device, 2026-11-26).

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in completionHandler([.banner, .list, .sound]) }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let link = response.notification.request.content.userInfo[UserNotificationScheduler.linkKey] as? String
        Task { @MainActor in
            if let link, let url = URL(string: link) { NotificationInbox.shared.url = url }
            completionHandler()
        }
    }
}
