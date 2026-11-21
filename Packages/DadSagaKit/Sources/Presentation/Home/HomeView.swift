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
    @State private var width: CGFloat = 0
    @State private var fold: HorizontalFold?
    /// Where the fold runs across home, also while the device lies flat.
    @State private var flatFold: HorizontalFold?
    /// The two-pane header's height, so the hero takes what is left above the fold.
    @State var paneHeaderHeight: CGFloat = 0
    /// The map and Settings' height over the adventure's pane, so its last card scrolls clear of them.
    @State var paneButtonsHeight: CGFloat = 0
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
            // Read where the panes are placed, so the fold is in their coordinates.
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .onHorizontalFoldChange(minimumAbove: foldPaneMinimum, minimumBelow: foldScrollingPaneMinimum) { fold = $0 }
            .onHorizontalFoldChange(
                minimumAbove: foldPaneMinimum, minimumBelow: foldScrollingPaneMinimum, whileFlat: true
            ) { flatFold = $0 }
            .background(DSColor.background)
            .safeAreaInset(edge: .bottom) { undoBar }
            .motion(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.undoOffer)
            .navigationTitle(title)
            // Two panes scroll separately. A navigation bar collapses or hides with whichever pane scrolls and
            // shifts the other, so the two-pane layouts have no bar: their title lives in the hero pane.
            .navigationBarHidden(when: arrangement.hasPanes)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { worldMapButton }
                ToolbarItem(placement: .primaryAction) { settingsButton }
            }
        }
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
            // The same two scroll views side by side or above and below the fold, so folding keeps where each
            // was scrolled to and a celebration in flight.
            let panes = arrangement.fold.map { AnyLayout(FoldedStackLayout(fold: $0)) }
                ?? AnyLayout(HStackLayout(alignment: .top, spacing: 0))
            panes {
                ScrollView { heroPanel(content).padding(HomeArrangement.panePadding) }
                    .frame(maxWidth: .infinity)
                    .modifier(celebrationOverlay)
                ScrollView { adventure(content).padding(HomeArrangement.panePadding) }
                    // The last card scrolls clear of the map and Settings.
                    .contentMargins(.bottom, paneButtonsHeight, for: .scrollContent)
                    .frame(maxWidth: .infinity)
            }
            // Over the adventure's pane, just above the tab bar: within the dad's reach, wherever home is scrolled.
            .overlay(alignment: .bottomTrailing) { paneButtons }
            // VoiceOver reads the map and Settings first, as it did when they stood by the title.
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

    private func heroPanel(_ content: HomeContent) -> some View {
        let stageAndLevel = isHeroBesideLevel
            ? AnyLayout(HStackLayout(spacing: DSSpacing.l))
            : AnyLayout(VStackLayout(spacing: DSSpacing.m))
        return VStack(spacing: HomeArrangement.headerSpacing) {
            if arrangement.hasPanes {
                paneHeader(content)
            }
            stageAndLevel {
                heroStage(content)
                VStack(spacing: DSSpacing.m) {
                    VStack(spacing: DSSpacing.xs) {
                        // Text in the primary colour: several hero colours are below 3:1 as text (ADR-0033).
                        Text(content.companionLine)
                            .font(DSFont.headline)
                            .foregroundStyle(DSColor.textPrimary)
                        if let tagline = content.heroTagline {
                            Text(tagline)
                                .font(DSFont.subheadline)
                                .foregroundStyle(DSColor.textSecondary)
                        }
                    }
                    .multilineTextAlignment(.center)
                    LevelPanel(
                        title: content.levelTitle,
                        xpLine: content.xpLine,
                        fraction: content.levelFraction,
                        levelUpID: viewModel.celebration.flatMap { $0.highlight == .levelUp ? $0.id : nil }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
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
