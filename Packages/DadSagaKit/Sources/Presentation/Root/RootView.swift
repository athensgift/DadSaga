import DesignSystem
import SwiftUI

/// Switches between onboarding and home. The child ViewModels are built by the composition root, once each time their
/// screen appears, never on every redraw.
public struct RootView: View {
    public typealias MakeOnboarding = @MainActor (_ onFinished: @escaping @MainActor () -> Void) -> OnboardingViewModel
    public typealias MakeHome = @MainActor () -> HomeViewModel
    public typealias MakeTimeline = @MainActor () -> TimelineViewModel
    public typealias MakeSettings = @MainActor (PreferencesChoice, SettingsActions) -> SettingsViewModel
    /// The import on onboarding's first step; it calls back once the imported saga is on this iPhone.
    public typealias MakeDataImport = @MainActor (_ onImported: @escaping @MainActor () -> Void) -> DataImportViewModel

    @State private var viewModel: RootViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var onboarding: OnboardingViewModel?
    @State private var home: HomeViewModel?
    @State private var timeline: TimelineViewModel?
    private let makeOnboarding: MakeOnboarding
    private let makeHome: MakeHome
    private let makeTimeline: MakeTimeline
    private let makeSagaFilm: SagaFilmSheet.MakeViewModel
    private let makeSettings: MakeSettings
    private let makeDataImport: MakeDataImport
    private let settingsPages: SettingsPages
    private let incomingURL: URL?
    private let onIncomingURLHandled: @MainActor () -> Void

    /// - Parameters:
    ///   - incomingURL: a link handed over by the app itself, e.g. from a tapped notification; `onIncomingURLHandled`
    ///     runs once it was passed on.
    public init(
        viewModel: RootViewModel,
        makeOnboarding: @escaping MakeOnboarding,
        makeHome: @escaping MakeHome,
        makeTimeline: @escaping MakeTimeline,
        makeSagaFilm: @escaping SagaFilmSheet.MakeViewModel,
        makeSettings: @escaping MakeSettings,
        makeDataImport: @escaping MakeDataImport,
        settingsPages: SettingsPages,
        incomingURL: URL? = nil,
        onIncomingURLHandled: @escaping @MainActor () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeOnboarding = makeOnboarding
        self.makeHome = makeHome
        self.makeTimeline = makeTimeline
        self.makeSagaFilm = makeSagaFilm
        self.makeSettings = makeSettings
        self.makeDataImport = makeDataImport
        self.settingsPages = settingsPages
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
                    OnboardingView(viewModel: onboarding) {
                        makeDataImport { viewModel.sagaImported() }
                    }
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
                            makeSagaFilm: makeSagaFilm,
                            settings: settingsScreens,
                            pendingLink: viewModel.pendingLink,
                            onLinkHandled: { viewModel.linkHandled($0) }
                        ),
                        timeline: TimelineView(
                            viewModel: timeline,
                            makeSagaFilm: makeSagaFilm,
                            isOpeningLink: viewModel.pendingLink != nil
                        )
                    )
                    .environment(viewModel.unsavedWork)
                    // A new saga is a new home: its sheets, Settings included, close with the old one.
                    .id(viewModel.sagaGeneration)
                    .transition(.opacity)
                } else {
                    ProgressView()
                }
            }
        }
        .onChange(of: viewModel.state, initial: true) { _, state in prepareScreen(for: state) }
        .onChange(of: viewModel.sagaGeneration) { rebuildHome() }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
        .tint(DSColor.accent)
        .windowAppearance(viewModel.preferences.appearance)
        .environment(\.isHapticsEnabled, viewModel.preferences.isHapticsEnabled)
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

    /// An imported saga took the place of the one home and the timeline were showing.
    private func rebuildHome() {
        guard viewModel.state == .home else { return }
        home = makeHome()
        timeline = makeTimeline()
    }

    /// Waits until the app knows whether there is a family, so a cold-launch link is not dropped while loading.
    private func openIncomingURL() {
        guard let incomingURL, viewModel.state != .loading else { return }
        viewModel.open(url: incomingURL)
        onIncomingURLHandled()
    }

    private var settingsScreens: SettingsScreens {
        let actions = SettingsActions(
            onPreferencesChanged: { viewModel.preferencesChanged($0) },
            onStartedOver: { viewModel.startedOver() },
            onSagaImported: { viewModel.sagaImported() }
        )
        return SettingsScreens(makeSettings: { makeSettings(viewModel.preferences, actions) }, pages: settingsPages)
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
