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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var width: CGFloat = 0
    @State private var fold: HorizontalFold?
    /// Where the fold runs across home, also while the device lies flat.
    @State private var flatFold: HorizontalFold?
    @State var settingsViewModel: SettingsViewModel?
    /// The film sheet, opened from the film offer.
    @State var sagaFilm: SagaFilmViewModel?
    /// A moment's photos, full screen.
    @State var photoViewer: PhotoViewerContent?
    let makeSagaFilm: SagaFilmSheet.MakeViewModel
    let settings: SettingsScreens
    let pendingLink: PendingLink?
    let onLinkHandled: @MainActor () -> Void

    /// - Parameters:
    ///   - settings: builds Settings, behind its toolbar button.
    ///   - makeSagaFilm: builds the film sheet for the film home offers.
    ///   - pendingLink: a link from outside the app (the widget) to open; `onLinkHandled` runs once it is open.
    public init(
        viewModel: HomeViewModel,
        makeSagaFilm: @escaping SagaFilmSheet.MakeViewModel,
        settings: SettingsScreens,
        pendingLink: PendingLink? = nil,
        onLinkHandled: @escaping @MainActor () -> Void = {}
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
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.undoOffer)
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
        .sheet(item: $settingsViewModel, onDismiss: reloadAfterSheet) { settingsModel in
            SettingsView(viewModel: settingsModel, pages: settings.pages) { settingsViewModel = nil }
        }
        .sagaFilmSheet($sagaFilm)
        .task { await viewModel.onAppear() }
        .task(id: pendingLink) { await openPendingLink() }
        .sheet(item: activeSheet, onDismiss: viewModel.sheetDismissed, content: sheetContent)
        .photoViewer($photoViewer, loader: { await viewModel.photoData(id: $0, maxPixelSize: $1) })
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

    private var arrangement: HomeArrangement {
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
                ScrollView { heroPanel(content).padding(DSSpacing.l) }
                    .frame(maxWidth: .infinity)
                    .modifier(celebrationOverlay)
                ScrollView { adventure(content).padding(DSSpacing.l) }
                    .frame(maxWidth: .infinity)
            }
            .animation(reduceMotion ? nil : .smooth, value: arrangement)
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
        CelebrationOverlay(celebration: viewModel.celebration) { viewModel.celebrationFinished() }
    }

    private func heroPanel(_ content: HomeContent) -> some View {
        // Above a fold the pane is wider than tall: the hero stands beside his lines and level, unless the text
        // is too large for half the width.
        let isBeside = arrangement.fold != nil && !dynamicTypeSize.isAccessibilitySize
        let stageAndLevel = isBeside
            ? AnyLayout(HStackLayout(spacing: DSSpacing.l))
            : AnyLayout(VStackLayout(spacing: DSSpacing.m))
        return VStack(spacing: DSSpacing.m) {
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
                        Text(content.heroTagline)
                            .font(DSFont.subheadline)
                            .foregroundStyle(DSColor.textSecondary)
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

    /// The dad and his children, on the glow of his colour.
    private func heroStage(_ content: HomeContent) -> some View {
        let style = content.heroLook.avatarStyle
        return FamilyStage(
            heroStyle: style,
            heroSkin: content.heroSkin.avatarSkin,
            heroFeatures: content.heroAppearance.avatarFeatures,
            heroGear: content.heroGear.map(\.heroItem),
            medals: content.medalCount,
            heroTitle: content.heroTitle,
            companions: content.companions,
            selectedChildID: content.selectedChildID,
            maxHeroSize: arrangement.maxHeroSize,
            cheerTrigger: viewModel.celebration?.id ?? 0
        ) { id in
            Task { await viewModel.selectChild(id: id) }
        }
        .padding(.top, DSSpacing.xl)
        .background {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [style.tint.opacity(0.28), style.tint.opacity(0)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
        }
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
                ContentUnavailableView(emptyMessage, systemImage: "map")
                    .padding(.vertical, DSSpacing.l)
            }
            ForEach(content.cards) { card in
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
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.reminderOffer)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.sagaOffer)
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

// MARK: - Links from outside the app

extension HomeView {
    /// Closes this screen's own sheets, then lets the presenter open the link (ADR-0023).
    func openPendingLink() async {
        guard let pendingLink else { return }
        let hadSheet = settingsViewModel != nil || sagaFilm != nil
            || viewModel.worldMap != nil || photoViewer != nil
        settingsViewModel = nil
        sagaFilm = nil
        photoViewer = nil
        viewModel.closeMap()
        // A new sheet cannot appear while the old one is still sliding away.
        if hadSheet { try? await Task.sleep(for: .milliseconds(450)) }
        // A newer link replaced this one while the sheets closed; its own task opens it.
        guard !Task.isCancelled else { return }
        await viewModel.open(pendingLink)
        onLinkHandled()
    }
}
