import DesignSystem
import SwiftUI

/// Switches between onboarding and home. The child ViewModels are built by the composition root.
public struct RootView: View {
    public typealias MakeOnboarding = @MainActor (_ onFinished: @escaping @MainActor () -> Void) -> OnboardingViewModel
    public typealias MakeHome = @MainActor () -> HomeViewModel

    @State private var viewModel: RootViewModel
    private let makeOnboarding: MakeOnboarding
    private let makeHome: MakeHome

    public init(viewModel: RootViewModel, makeOnboarding: @escaping MakeOnboarding, makeHome: @escaping MakeHome) {
        _viewModel = State(initialValue: viewModel)
        self.makeOnboarding = makeOnboarding
        self.makeHome = makeHome
    }

    public var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .onboarding:
                OnboardingView(
                    viewModel: makeOnboarding { viewModel.onboardingFinished() },
                    developerMenu: developerMenu
                )
                .transition(.opacity)
            case .home:
                HomeView(viewModel: makeHome(), developerMenu: developerMenu)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
        .tint(DSColor.accent)
        .animation(.easeInOut(duration: 0.35), value: viewModel.state)
        .task { await viewModel.onAppear() }
    }

    private var developerMenu: DeveloperMenu? {
        guard viewModel.hasDeveloperMenu else { return nil }
        return DeveloperMenu { Task { await viewModel.restartFromOnboarding() } }
    }
}
