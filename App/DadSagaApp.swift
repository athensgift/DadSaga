import Presentation
import SwiftUI
import WidgetKit

@main
struct DadSagaApp: App {
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var notificationDelegate
    private let container = AppContainer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(
                viewModel: container.makeRootViewModel(),
                makeOnboarding: { container.makeOnboardingViewModel(onFinished: $0) },
                makeHome: { container.makeHomeViewModel() },
                makeFamily: { container.makeFamilyViewModel(onSaved: $0) },
                makeTimeline: { container.makeTimelineViewModel() },
                makeWardrobe: { container.makeWardrobeViewModel() },
                makeReminderSettings: { container.makeReminderSettingsViewModel() },
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
            Task { await schedule.execute(on: .now) }
        }
    }
}
