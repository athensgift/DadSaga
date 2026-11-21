import Application
import Data
import Foundation

/// Everything the app keeps on the device: the saga's store, the photos, its own defaults and the notifications.
/// The app runs on the dad's own (`live`); UI and snapshot tests run on a set of their own, so they never change his
/// saga, photos, preferences or reminders (ADR-0033, ADR-0034).
struct DeviceData {
    let store: LocalStore
    let photos: FilePhotoStore
    let defaults: UserDefaults
    let notificationScheduler: any NotificationScheduler

    /// In the folder the app shares with the widget (ADR-0023), and the app's own defaults. Without the App Group a
    /// release build opens nothing, and the app shows its "couldn't open" screen (ADR-0048).
    static func live() -> DeviceData {
        DeviceData(
            store: LocalStore.shared(),
            photos: FilePhotoStore.sharedMoments(),
            defaults: .standard,
            notificationScheduler: UserNotificationScheduler()
        )
    }

    /// `DadSagaUITests` launches the app with this argument.
    static let uiTestingArgument = "-uiTesting"

    /// The test data for UI tests, and while the app hosts `DadSagaSnapshotTests` (ADR-0034): XCTest sets
    /// `XCTestConfigurationFilePath` in the process it injects tests into.
    static func forLaunch(
        arguments: [String] = CommandLine.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DeviceData {
        #if DEBUG
        if arguments.contains(uiTestingArgument) || environment["XCTestConfigurationFilePath"] != nil {
            return uiTesting()
        }
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
            photos: FilePhotoStore.moments(in: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)),
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
