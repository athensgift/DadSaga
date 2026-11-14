import DesignSystem
import SwiftUI

/// Switches between onboarding and home. The child ViewModels are built by the composition root.
public struct RootView: View {
    public typealias MakeOnboarding = @MainActor (_ onFinished: @escaping @MainActor () -> Void) -> OnboardingViewModel
    public typealias MakeHome = @MainActor () -> HomeViewModel
    public typealias MakeTimeline = @MainActor () -> TimelineViewModel

    @State private var viewModel: RootViewModel
    private let makeOnboarding: MakeOnboarding
    private let makeHome: MakeHome
    private let makeFamily: HomeView.MakeFamily?
    private let makeTimeline: MakeTimeline?

    /// - Parameter makeTimeline: builds the timeline tab; `nil` shows home without tabs.
    public init(
        viewModel: RootViewModel,
        makeOnboarding: @escaping MakeOnboarding,
        makeHome: @escaping MakeHome,
        makeFamily: HomeView.MakeFamily? = nil,
        makeTimeline: MakeTimeline? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeOnboarding = makeOnboarding
        self.makeHome = makeHome
        self.makeFamily = makeFamily
        self.makeTimeline = makeTimeline
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
                MainTabs(
                    tabs: viewModel.tabs,
                    home: HomeView(viewModel: makeHome(), developerMenu: developerMenu, makeFamily: makeFamily),
                    timeline: makeTimeline.map { TimelineView(viewModel: $0()) }
                )
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

/// Adventure and timeline as tabs. The tab bar is Liquid Glass and shrinks while scrolling.
private struct MainTabs: View {
    let tabs: RootTabs
    let home: HomeView
    let timeline: TimelineView?

    var body: some View {
        if let timeline {
            TabView {
                Tab(tabs.adventure, systemImage: "figure.and.child.holdinghands") { home }
                Tab(tabs.timeline, systemImage: "clock.arrow.circlepath") { timeline }
            }
            #if os(iOS)
            .tabBarMinimizeBehavior(.onScrollDown)
            #endif
        } else {
            home
        }
    }
}
