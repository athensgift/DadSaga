import Presentation
import SwiftUI
import WidgetKit

@main
struct DadSagaApp: App {
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var notificationDelegate
    private let container: AppContainer
    /// Built once; `body` runs again on every scene-phase change and must not rebuild it.
    private let rootViewModel: RootViewModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let container = AppContainer()
        self.container = container
        rootViewModel = container.makeRootViewModel()
        container.discardLeftoverFilms()
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                viewModel: rootViewModel,
                makeOnboarding: { container.makeOnboardingViewModel(onFinished: $0) },
                makeHome: { container.makeHomeViewModel() },
                makeTimeline: { container.makeTimelineViewModel() },
                makeWardrobe: { container.makeWardrobeViewModel() },
                makeSagaFilm: { container.makeSagaFilmViewModel(request: $0) },
                makeSettings: { container.makeSettingsViewModel(preferences: $0, actions: $1) },
                settingsPages: container.settingsPages,
                incomingURL: NotificationInbox.shared.url,
                onIncomingURLHandled: { NotificationInbox.shared.url = nil }
            )
        }
        // One place covers every write, now and later: the widget is only visible once the app leaves the screen,
        // and reloads asked for while the app is in the foreground do not count against the widget's budget.
        // The weekly notifications are rescheduled at the same moment, so a quest done this week drops its note.
        .onChange(of: scenePhase) { old, _ in
            guard old == .active else { return }
            WidgetCenter.shared.reloadAllTimelines()
            let schedule = container.scheduleWeeklyReminders
            // Asks iOS for a little time, so the app is not suspended before the new notifications are in place.
            let application = UIApplication.shared
            let backgroundTask = BackgroundTask(application: application)
            backgroundTask.begin()
            Task {
                await schedule.execute(on: .now)
                backgroundTask.end()
            }
        }
    }
}

/// A little extra time from iOS after the app leaves the screen. Ended once: when the work is done, or when iOS says
/// time is up, so the app is never terminated for holding it too long.
@MainActor
private final class BackgroundTask {
    private let application: UIApplication
    private var identifier = UIBackgroundTaskIdentifier.invalid

    init(application: UIApplication) {
        self.application = application
    }

    func begin() {
        identifier = application.beginBackgroundTask(withName: "Reschedule weekly reminders") { [weak self] in
            MainActor.assumeIsolated { self?.end() }
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        application.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
