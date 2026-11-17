import Presentation
import SwiftUI
import WidgetKit

@main
struct DadSagaApp: App {
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
                makeWardrobe: { container.makeWardrobeViewModel() }
            )
        }
        // One place covers every write, now and later: the widget is only visible once the app leaves the screen,
        // and reloads asked for while the app is in the foreground do not count against the widget's budget.
        .onChange(of: scenePhase) { old, _ in
            if old == .active { WidgetCenter.shared.reloadAllTimelines() }
        }
    }
}
