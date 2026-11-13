import Presentation
import SwiftUI

@main
struct DadSagaApp: App {
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView(
                viewModel: container.makeRootViewModel(),
                makeOnboarding: { container.makeOnboardingViewModel(onFinished: $0) },
                makeHome: { container.makeHomeViewModel() }
            )
        }
    }
}
