import DesignSystem
import HeroArt
import SwiftUI

/// Home: the dad's hero and progress, then what he can play today.
/// On wide screens (iPhone Duo inner display, landscape) it splits into two equal columns, so neither column
/// runs across the middle of the display, where the Duo folds like a book. Half-open like a laptop, the fold runs
/// across instead: the hero stands above it and the adventure lies below it (ADR-0043), and the same two panes stay
/// when the Duo is opened flat and held upright (ADR-0045).
public struct HomeView: View {
    @State var viewModel: HomeViewModel
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    /// Set while the app is in the background, so coming back reloads once (not after Control Center or Face ID).
    @State var wasInBackground = false
    /// The app's editors holding changes the dad hasn't saved: a link waits for them. The root screen's, shared with
    /// the timeline; home's own where nothing above provides one (previews, snapshots).
    @Environment(UnsavedWork.self) private var sharedUnsavedWork: UnsavedWork?
    @State private var ownUnsavedWork = UnsavedWork()
    var unsavedWork: UnsavedWork { sharedUnsavedWork ?? ownUnsavedWork }
    @State var width: CGFloat = 0
    @State private var fold: HorizontalFold?
    /// Where the fold runs across home, also while the device lies flat.
    @State private var flatFold: HorizontalFold?
    /// The two-pane header's height, so the hero takes what is left above the fold.
    @State var paneHeaderHeight: CGFloat = 0
    /// The map and Settings' height over the adventure's pane, so its last card scrolls clear of them.
    @State var paneButtonsHeight: CGFloat = 0
    /// What stands under the hero in his pane, or the skills panel below him and his lines above a fold: the hero
    /// yields that height, so the pane fits (ADR-0059 §3).
    @State var underHeroHeight: CGFloat = 0
    /// The hero pane's height inside the safe area, side by side.
    @State var heroPaneHeight: CGFloat = 0
    /// The width the four skills need side by side: beside the hero, his column is at least that wide.
    @State var skillsRowWidth: CGFloat = 0
    @State var settingsViewModel: SettingsViewModel?
    /// The film sheet, opened from the film offer.
    @State var sagaFilm: SagaFilmViewModel?
    /// A moment's photos, full screen.
    @State var photoViewer: PhotoViewerContent?
    let makeSagaFilm: SagaFilmSheet.MakeViewModel
    let settings: SettingsScreens
    let pendingLink: PendingLink?
    let onLinkHandled: @MainActor (PendingLink) -> Void

    /// - Parameters:
    ///   - settings: builds Settings, behind its toolbar button.
    ///   - makeSagaFilm: builds the film sheet for the film home offers.
    ///   - pendingLink: a link from outside the app (the widget) to open; `onLinkHandled` gets it once it is open.
    public init(
        viewModel: HomeViewModel,
        makeSagaFilm: @escaping SagaFilmSheet.MakeViewModel,
        settings: SettingsScreens,
        pendingLink: PendingLink? = nil,
        onLinkHandled: @escaping @MainActor (PendingLink) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeSagaFilm = makeSagaFilm
        self.settings = settings
        self.pendingLink = pendingLink
        self.onLinkHandled = onLinkHandled
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView()
                case .loaded(let content):
                    loaded(content)
                case .failed(let message):
                    ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColor.background)
            .safeAreaInset(edge: .bottom) { undoBar }
            .motion(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.undoOffer)
            .navigationTitle(arrangement.buttons.showsTitleInBar ? title : "")
            // Named, not left to the default: with no mode named, iOS 27.2 collapses the large title as soon as the
            // loaded home replaces the spinner.
            .toolbarTitleDisplayMode(arrangement.buttons.showsTitleInBar ? .automatic : .inline)
            // Two panes scroll separately, so their title lives in the hero pane. Side by side the bar stays, with no
            // title, for the system to place the map and Settings by the tab bar (ADR-0058). Above and below a fold
            // a bar would shift the fold's place, so there is none (ADR-0043).
            .navigationBarHidden(when: !arrangement.buttons.hasNavigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { worldMapButton }
                ToolbarItem(placement: .primaryAction) { settingsButton }
            }
        }
        // A stack of its own for each bar: large title, inline or none (ADR-0058). UIKit sets scrolling content
        // against a bar when its screen appears. Under a bar that changes on a screen that stays, an inline bar turned
        // large keeps its title collapsed, and a pane brought up from below the fold stays scrolled past its top by
        // the safe area it was moved under. Folding keeps the bar, so it keeps the stack and where each pane was.
        .id(arrangement.buttons)
        // Read around the stack, not in it: a stack built for what was read must not start the reading again. Home
        // fills the stack while it has no bar, which is whenever a fold splits it, so the fold is in the panes'
        // coordinates.
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onHorizontalFoldChange(minimumAbove: foldPaneMinimum, minimumBelow: foldScrollingPaneMinimum) { fold = $0 }
        .onHorizontalFoldChange(
            minimumAbove: foldPaneMinimum, minimumBelow: foldScrollingPaneMinimum, whileFlat: true
        ) { flatFold = $0 }
        .sheet(item: worldMapBinding) { map in
            WorldMapSheet(map: map) { id in
                Task { await viewModel.showWorld(id: id) }
            } onClose: {
                viewModel.closeMap()
            }
        }
        .sheet(item: $settingsViewModel, onDismiss: settingsDismissed) { settingsModel in
            SettingsView(viewModel: settingsModel, pages: settings.pages) { settingsViewModel = nil }
                .environment(\.unsavedScope, UnsavedScope.settings)
        }
        .sagaFilmSheet($sagaFilm)
        .task { await viewModel.onAppear() }
        .onChange(of: scenePhase) { _, phase in scenePhaseChanged(to: phase) }
        .task(id: pendingLink) { await openPendingLink() }
        .task(id: viewModel.celebration?.id) { await celebrationTime() }
        .onChange(of: viewModel.titleCard) { _, card in announce(card) }
        .sheet(item: activeSheet, onDismiss: homeSheetDismissed) { sheet in
            sheetContent(sheet)
                .environment(\.unsavedScope, UnsavedScope.homeSheet)
        }
        .photoViewer($photoViewer, loader: { await viewModel.photoData(id: $0, maxPixelSize: $1) })
        // Last, so the sheets and Settings' pages see it too.
        .environment(unsavedWork)
    }

    private var title: String {
        if case .loaded(let content) = viewModel.state { content.heroTitle } else { "" }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: HomeSheet) -> some View {
        switch sheet {
        case .quest(let quest):
            questSheet(quest)
        case .boss(let boss):
            bossSheet(boss)
        case .moment(let capture):
            momentSheet(capture)
        }
    }

    private var activeSheet: Binding<HomeSheet?> {
        Binding(
            get: {
                viewModel.selectedQuest.map(HomeSheet.quest)
                    ?? viewModel.selectedBoss.map(HomeSheet.boss)
                    ?? viewModel.momentCapture.map(HomeSheet.moment)
            },
            set: { if $0 == nil { viewModel.dismissSelection() } }
        )
    }

    var worldMapBinding: Binding<WorldMapContent?> {
        Binding(get: { viewModel.worldMap }, set: { if $0 == nil { viewModel.closeMap() } })
    }

    var arrangement: HomeArrangement {
        HomeArrangement.make(width: width, fold: fold, flatFold: flatFold)
    }

    @ViewBuilder
    private func loaded(_ content: HomeContent) -> some View {
        if arrangement.hasPanes {
            // Above and below a fold these stay the same two scroll views as it opens and closes, so folding keeps
            // where each was scrolled to and a celebration in flight. Side by side is another stack (see `body`).
            let panes = arrangement.fold.map { AnyLayout(FoldedStackLayout(fold: $0)) }
                ?? AnyLayout(HStackLayout(alignment: .top, spacing: 0))
            panes {
                ScrollView { heroPanel(content).padding(HomeArrangement.panePadding) }
                    // Laid out inside the safe area, so its height is what the dad sees without scrolling.
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heroPaneHeight = $0 }
                    .frame(maxWidth: .infinity)
                    .modifier(celebrationOverlay)
                ScrollView { adventure(content).padding(HomeArrangement.panePadding) }
                    // The last card scrolls clear of the map and Settings.
                    .contentMargins(
                        .bottom, arrangement.buttons.isFloating ? paneButtonsHeight : 0, for: .scrollContent
                    )
                    .frame(maxWidth: .infinity)
            }
            // Over the adventure's pane, just above the tab bar: within the dad's reach, wherever home is scrolled.
            .overlay(alignment: .bottomTrailing) {
                if arrangement.buttons.isFloating { paneButtons }
            }
            // Above and below a fold, VoiceOver reads the floating map and Settings first, as when they stood by the title.
            .accessibilityElement(children: .contain)
            .motion(.smooth, value: arrangement)
        } else {
            ScrollView {
                VStack(spacing: DSSpacing.l) {
                    heroPanel(content)
                    adventure(content)
                }
                .frame(maxWidth: readableWidth)
                .padding(DSSpacing.m)
                .frame(maxWidth: .infinity)
            }
            .modifier(celebrationOverlay)
        }
    }

    /// Fixed over the scroll view, not scrolled with the hero, so a dad who completes a card further down still sees it.
    /// With two panes it stays in the hero's, away from the Duo's fold.
    private var celebrationOverlay: CelebrationOverlay {
        CelebrationOverlay(celebration: viewModel.celebration)
    }

    private func adventure(_ content: HomeContent) -> some View {
        LazyVStack(alignment: .leading, spacing: DSSpacing.s) {
            if !content.childTabs.isEmpty {
                ChildPicker(content: content) { id in Task { await viewModel.selectChild(id: id) } }
            }
            offerCard
            WorldHeader(content: content) {
                Task { await viewModel.showWorld(id: nil) }
            }
            if let emptyMessage = content.emptyMessage {
                // With no world to show, the arrival line goes with the message, centred under it.
                VStack(spacing: DSSpacing.xs) {
                    ContentUnavailableView(emptyMessage, systemImage: "map")
                    if let arrivalLine = content.arrivalLine, content.worldTitle == nil {
                        ArrivalLine(text: arrivalLine)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, DSSpacing.l)
            }
            ForEach(content.cards) { card in
                cardButton(card)
            }
            if let situational = content.situational {
                // Closed again when home is opened or shows another child or world; open through a save.
                SituationalRow(cards: situational) { cardButton($0) }
                    .id(situational.id)
            }
            MomentsSectionView(
                section: content.moments,
                loader: { await viewModel.photoData(id: $0, maxPixelSize: $1) },
                onAdd: { viewModel.startCapture() },
                onEdit: { viewModel.editMoment(id: $0) },
                onShowPhotos: { card in
                    photoViewer = content.moments.viewer.content(
                        entry: card.title, photos: card.photoIDs.map(PhotoSource.stored)
                    )
                }
            )
                .padding(.top, DSSpacing.l)
        }
        .motion(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.reminderOffer)
        .motion(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.sagaOffer)
        .motion(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.titleCard)
    }
}

extension HomeView {
    /// A quest or boss card; a tap opens its sheet.
    func cardButton(_ card: CardModel) -> some View {
        Button {
            viewModel.select(cardID: card.id)
        } label: {
            QuestCard(
                title: card.title,
                subtitle: card.subtitle,
                badge: card.badge,
                symbol: card.symbol,
                style: card.kind.cardStyle,
                footnote: card.footnote,
                hint: card.hint,
                skill: card.skill
            )
        }
        .buttonStyle(.plain)
    }
}

/// The one sheet the home screen can show at a time.
private enum HomeSheet: Identifiable {
    case quest(QuestDetail)
    case boss(BossDetail)
    case moment(MomentCapture)

    var id: String {
        switch self {
        case .quest(let quest): "quest-" + quest.id
        case .boss(let boss): "boss-" + boss.id
        case .moment(let capture): "moment-" + capture.id.uuidString
        }
    }
}

extension HomeView {
    @ViewBuilder var undoBar: some View {
        if let offer = viewModel.undoOffer {
            UndoBar(offer: offer) {
                Task { await viewModel.undoLastRecord() }
            } onExpire: {
                viewModel.undoOfferExpired(id: offer.id)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    func questSheet(_ quest: QuestDetail) -> some View {
        QuestSheet(
            quest: quest,
            errorMessage: viewModel.errorMessage,
            isCompleting: viewModel.isCompleting,
            loader: { await viewModel.photoData(id: $0, maxPixelSize: $1) },
            onConfirm: { note, photos in Task { await viewModel.completeSelectedQuest(note: note, photos: photos) } },
            onClose: { viewModel.dismissSelection() }
        )
    }

    func momentSheet(_ capture: MomentCapture) -> some View {
        MomentSheet(
            capture: capture,
            errorMessage: viewModel.errorMessage,
            isSaving: viewModel.isCompleting,
            loader: { await viewModel.photoData(id: $0, maxPixelSize: $1) },
            actions: MomentSheet.Actions(
                onCapture: { id, date in Task { await viewModel.captureMoment(firstID: id, date: date) } },
                onSave: { date, note, photos in
                    Task { await viewModel.saveMomentDetails(date: date, note: note, photos: photos) }
                },
                onDelete: { Task { await viewModel.deleteMoment() } },
                onUndoExpired: { viewModel.momentUndoExpired(id: $0) },
                onClose: { viewModel.dismissSelection() }
            )
        )
    }

    func bossSheet(_ boss: BossDetail) -> some View {
        BossSheet(
            boss: boss,
            errorMessage: viewModel.errorMessage,
            isCompleting: viewModel.isCompleting,
            loader: { await viewModel.photoData(id: $0, maxPixelSize: $1) },
            onConfirm: { note, photos in Task { await viewModel.defeatSelectedBoss(note: note, photos: photos) } },
            onClose: { viewModel.dismissSelection() }
        )
    }
}
