import Application
import Data
import Foundation

/// Everything the app keeps on the device: the saga's store, the photos, its own defaults and the notifications.
/// The app runs on the dad's own (`live`); UI tests run on a set of their own, so they never change his saga, photos,
/// preferences or reminders (ADR-0033).
struct DeviceData {
    let store: LocalStore
    let photoDirectory: URL
    let defaults: UserDefaults
    let notificationScheduler: any NotificationScheduler

    /// In the folder the app shares with the widget (ADR-0023), and the app's own defaults.
    static func live() -> DeviceData {
        DeviceData(
            store: LocalStore.live(in: SharedContainer.directory()),
            photoDirectory: SharedContainer.directory(),
            defaults: .standard,
            notificationScheduler: UserNotificationScheduler()
        )
    }

    /// `DadSagaUITests` launches the app with this argument.
    static let uiTestingArgument = "-uiTesting"

    static func forLaunch(arguments: [String] = CommandLine.arguments) -> DeviceData {
        #if DEBUG
        if arguments.contains(uiTestingArgument) { return uiTesting() }
        #endif
        return live()
    }

    #if DEBUG
    /// Empty and thrown away: a store in memory, photos in a fresh temporary folder, cleared defaults of its own and
    /// no notifications at all. Only in debug builds, so a release build has one way to open its data.
    private static func uiTesting() -> DeviceData {
        let suite = "com.athinodoros.dadsaga.uitesting"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return DeviceData(
            store: LocalStore.inMemory(),
            photoDirectory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString),
            defaults: defaults,
            notificationScheduler: SilentNotificationScheduler()
        )
    }
    #endif
}

#if DEBUG
/// Schedules nothing and never shows the iOS prompt.
private struct SilentNotificationScheduler: NotificationScheduler {
    func authorization() async -> NotificationAuthorization { .denied }
    func requestAuthorization() async -> Bool { false }
    func replacePending(with reminders: [PendingReminder]) async {}
    func removeDelivered() async {}
}
#endif
