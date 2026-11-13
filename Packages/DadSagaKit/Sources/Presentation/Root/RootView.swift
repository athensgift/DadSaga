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
                OnboardingView(viewModel: makeOnboarding { viewModel.onboardingFinished() })
                    .transition(.opacity)
            case .home:
                HomeView(viewModel: makeHome())
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
        .overlay(alignment: .topTrailing) {
            if viewModel.hasDeveloperMenu { developerMenu }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.state)
        .task { await viewModel.onAppear() }
    }

    /// Development builds only, so its labels are not localised.
    private var developerMenu: some View {
        Menu {
            Button("Restart from onboarding", systemImage: "arrow.counterclockwise", role: .destructive) {
                Task { await viewModel.restartFromOnboarding() }
            }
        } label: {
            Image(systemName: "ladybug.fill")
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textSecondary)
                .padding(DSSpacing.s)
                .background(DSColor.surface, in: Circle())
        }
        .padding(.trailing, DSSpacing.m)
        .accessibilityLabel("Developer menu")
    }
}
