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

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let link = response.notification.request.content.userInfo[UserNotificationScheduler.linkKey] as? String,
              let url = URL(string: link)
        else { return }
        await MainActor.run { NotificationInbox.shared.url = url }
    }
}
