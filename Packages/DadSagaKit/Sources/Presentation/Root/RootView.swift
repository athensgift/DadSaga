import DesignSystem
import SwiftUI

/// Switches between onboarding and home. The child ViewModels are built by the composition root, once each time their
/// screen appears, never on every redraw.
public struct RootView: View {
    public typealias MakeOnboarding = @MainActor (_ onFinished: @escaping @MainActor () -> Void) -> OnboardingViewModel
    public typealias MakeHome = @MainActor () -> HomeViewModel
    public typealias MakeTimeline = @MainActor () -> TimelineViewModel

    @State private var viewModel: RootViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var onboarding: OnboardingViewModel?
    @State private var home: HomeViewModel?
    @State private var timeline: TimelineViewModel?
    private let makeOnboarding: MakeOnboarding
    private let makeHome: MakeHome
    private let makeFamily: HomeView.MakeFamily
    private let makeTimeline: MakeTimeline
    private let makeWardrobe: HomeView.MakeWardrobe
    private let makeReminderSettings: HomeView.MakeReminderSettings
    private let incomingURL: URL?
    private let onIncomingURLHandled: @MainActor () -> Void

    /// - Parameters:
    ///   - incomingURL: a link handed over by the app itself, e.g. from a tapped notification; `onIncomingURLHandled`
    ///     runs once it was passed on.
    public init(
        viewModel: RootViewModel,
        makeOnboarding: @escaping MakeOnboarding,
        makeHome: @escaping MakeHome,
        makeFamily: @escaping HomeView.MakeFamily,
        makeTimeline: @escaping MakeTimeline,
        makeWardrobe: @escaping HomeView.MakeWardrobe,
        makeReminderSettings: @escaping HomeView.MakeReminderSettings,
        incomingURL: URL? = nil,
        onIncomingURLHandled: @escaping @MainActor () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeOnboarding = makeOnboarding
        self.makeHome = makeHome
        self.makeFamily = makeFamily
        self.makeTimeline = makeTimeline
        self.makeWardrobe = makeWardrobe
        self.makeReminderSettings = makeReminderSettings
        self.incomingURL = incomingURL
        self.onIncomingURLHandled = onIncomingURLHandled
    }

    public var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .unavailable:
                StoreUnavailableView(content: viewModel.unavailable) { Task { await viewModel.retry() } }
                    .transition(.opacity)
            case .onboarding:
                if let onboarding {
                    OnboardingView(viewModel: onboarding, developerMenu: developerMenu)
                        .transition(.opacity)
                } else {
                    ProgressView()
                }
            case .home:
                if let home, let timeline {
                    MainTabs(
                        tabs: viewModel.tabs,
                        selection: $viewModel.selectedTab,
                        home: HomeView(
                            viewModel: home,
                            developerMenu: developerMenu,
                            makeFamily: makeFamily,
                            makeWardrobe: makeWardrobe,
                            makeReminderSettings: makeReminderSettings,
                            pendingLink: viewModel.pendingLink,
                            onLinkHandled: { viewModel.linkHandled() }
                        ),
                        timeline: TimelineView(viewModel: timeline, isOpeningLink: viewModel.pendingLink != nil)
                    )
                    .transition(.opacity)
                } else {
                    ProgressView()
                }
            }
        }
        .onChange(of: viewModel.state, initial: true) { _, state in prepareScreen(for: state) }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
        .tint(DSColor.accent)
        .animation(.easeInOut(duration: 0.35), value: viewModel.state)
        .task {
            await viewModel.onAppear()
            openIncomingURL()
        }
        .onOpenURL { viewModel.open(url: $0) }
        // Back in the app after freeing space, say: try the store again.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, viewModel.state == .unavailable else { return }
            Task { await viewModel.retry() }
        }
        .onChange(of: incomingURL) { openIncomingURL() }
    }

    /// Builds the screen's ViewModel when it appears and lets go of the other screen's.
    private func prepareScreen(for state: RootViewModel.State) {
        switch state {
        case .loading, .unavailable:
            break
        case .onboarding:
            home = nil
            timeline = nil
            if onboarding == nil { onboarding = makeOnboarding { viewModel.onboardingFinished() } }
        case .home:
            onboarding = nil
            if home == nil {
                home = makeHome()
                timeline = makeTimeline()
            }
        }
    }

    /// Waits until the app knows whether there is a family, so a cold-launch link is not dropped while loading.
    private func openIncomingURL() {
        guard let incomingURL, viewModel.state != .loading else { return }
        viewModel.open(url: incomingURL)
        onIncomingURLHandled()
    }

    private var developerMenu: DeveloperMenu? {
        guard viewModel.hasDeveloperMenu, viewModel.state != .unavailable else { return nil }
        return DeveloperMenu { Task { await viewModel.restartFromOnboarding() } }
    }
}

/// Adventure and timeline as tabs. The tab bar is Liquid Glass and shrinks while scrolling.
private struct MainTabs: View {
    let tabs: RootTabs
    @Binding var selection: RootTab
    let home: HomeView
    let timeline: TimelineView

    var body: some View {
        TabView(selection: $selection) {
            Tab(tabs.adventure, systemImage: "figure.and.child.holdinghands", value: RootTab.adventure) { home }
            Tab(tabs.timeline, systemImage: "clock.arrow.circlepath", value: RootTab.timeline) { timeline }
        }
        #if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
    }
}
