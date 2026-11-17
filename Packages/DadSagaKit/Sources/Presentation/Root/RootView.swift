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
    private let makeWardrobe: HomeView.MakeWardrobe?
    private let makeReminderSettings: HomeView.MakeReminderSettings?
    private let incomingURL: URL?
    private let onIncomingURLHandled: @MainActor () -> Void

    /// - Parameters:
    ///   - makeTimeline: builds the timeline tab; `nil` shows home without tabs.
    ///   - incomingURL: a link handed over by the app itself, e.g. from a tapped notification; `onIncomingURLHandled`
    ///     runs once it was passed on.
    public init(
        viewModel: RootViewModel,
        makeOnboarding: @escaping MakeOnboarding,
        makeHome: @escaping MakeHome,
        makeFamily: HomeView.MakeFamily? = nil,
        makeTimeline: MakeTimeline? = nil,
        makeWardrobe: HomeView.MakeWardrobe? = nil,
        makeReminderSettings: HomeView.MakeReminderSettings? = nil,
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
            case .onboarding:
                OnboardingView(
                    viewModel: makeOnboarding { viewModel.onboardingFinished() },
                    developerMenu: developerMenu
                )
                .transition(.opacity)
            case .home:
                MainTabs(
                    tabs: viewModel.tabs,
                    selection: $viewModel.selectedTab,
                    home: HomeView(
                        viewModel: makeHome(),
                        developerMenu: developerMenu,
                        makeFamily: makeFamily,
                        makeWardrobe: makeWardrobe,
                        makeReminderSettings: makeReminderSettings,
                        pendingLink: viewModel.pendingLink,
                        onLinkHandled: { viewModel.linkHandled() }
                    ),
                    timeline: makeTimeline.map { TimelineView(viewModel: $0(), isOpeningLink: viewModel.pendingLink != nil) }
                )
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
        .tint(DSColor.accent)
        .animation(.easeInOut(duration: 0.35), value: viewModel.state)
        .task {
            await viewModel.onAppear()
            openIncomingURL()
        }
        .onOpenURL { viewModel.open(url: $0) }
        .onChange(of: incomingURL) { openIncomingURL() }
    }

    /// Waits until the app knows whether there is a family, so a cold-launch link is not dropped while loading.
    private func openIncomingURL() {
        guard let incomingURL, viewModel.state != .loading else { return }
        viewModel.open(url: incomingURL)
        onIncomingURLHandled()
    }

    private var developerMenu: DeveloperMenu? {
        guard viewModel.hasDeveloperMenu else { return nil }
        return DeveloperMenu { Task { await viewModel.restartFromOnboarding() } }
    }
}

/// Adventure and timeline as tabs. The tab bar is Liquid Glass and shrinks while scrolling.
private struct MainTabs: View {
    let tabs: RootTabs
    @Binding var selection: RootTab
    let home: HomeView
    let timeline: TimelineView?

    var body: some View {
        if let timeline {
            TabView(selection: $selection) {
                Tab(tabs.adventure, systemImage: "figure.and.child.holdinghands", value: RootTab.adventure) { home }
                Tab(tabs.timeline, systemImage: "clock.arrow.circlepath", value: RootTab.timeline) { timeline }
            }
            #if os(iOS)
            .tabBarMinimizeBehavior(.onScrollDown)
            #endif
        } else {
            home
        }
    }
}
