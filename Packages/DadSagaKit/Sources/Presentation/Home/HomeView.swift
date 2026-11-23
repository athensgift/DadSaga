import DesignSystem
import HeroArt
import SwiftUI

/// Home: the dad's hero and progress, then what he can play today, in one column that scrolls as a whole.
/// It splits only around the iPhone Duo's fold while the device is half-open: held upright like a laptop, the hero
/// stands above the fold and the adventure lies below it; on its side like a book, they are two equal columns. Open
/// flat, and on an iPad, it is one column again (ADR-0043, ADR-0066).
/// The map and Settings are tabs of their own.
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
    /// Whether the Duo is half-open like a book on its side, its fold running down home (ADR-0066).
    @State private var foldRunsDown = false
    /// The two-pane header's height, so the hero takes what is left above the fold.
    @State var paneHeaderHeight: CGFloat = 0
    /// What stands under the hero in his pane, or the skills panel below him and his lines above a fold: the hero
    /// yields that height, so the pane fits (ADR-0059 §3).
    @State var underHeroHeight: CGFloat = 0
    /// The hero pane's height inside the safe area, side by side.
    @State var heroPaneHeight: CGFloat = 0
    /// The width the four skills need side by side: beside the hero, his column is at least that wide.
    @State var skillsRowWidth: CGFloat = 0
    /// The film sheet, opened from the film offer.
    @State var sagaFilm: SagaFilmViewModel?
    /// A moment's photos, full screen.
    @State var photoViewer: PhotoViewerContent?
    let makeSagaFilm: SagaFilmSheet.MakeViewModel
    let pendingLink: PendingLink?
    let onLinkHandled: @MainActor (PendingLink) -> Void

    /// - Parameters:
    ///   - makeSagaFilm: builds the film sheet for the film home offers.
    ///   - pendingLink: a link from outside the app (the widget) to open; `onLinkHandled` gets it once it is open.
    public init(
        viewModel: HomeViewModel,
        makeSagaFilm: @escaping SagaFilmSheet.MakeViewModel,
        pendingLink: PendingLink? = nil,
        onLinkHandled: @escaping @MainActor (PendingLink) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeSagaFilm = makeSagaFilm
        self.pendingLink = pendingLink
        self.onLinkHandled = onLinkHandled
    }

    public var body: some View {
        NavigationStack {
            // The Undo bar takes its own room under home rather than floating over it, so it never covers a card's
            // button, such as the title card that comes with it (ADR-0059 §3).
            VStack(spacing: 0) {
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
                undoBar
            }
            .background(DSColor.background)
            .motion(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.undoOffer)
            .navigationTitle(arrangement.hasPanes ? "" : title)
            // Named, not left to the default: with no mode named, iOS 27.2 collapses the large title as soon as the
            // loaded home replaces the spinner (ADR-0058 §7).
            .toolbarTitleDisplayMode(.automatic)
            // One column keeps the bar with its large title and nothing in it. Two panes scroll separately, so their
            // title heads the hero's pane, and they have no bar: above and below a fold it would shift the fold's
            // place (ADR-0043 §3, ADR-0061 §1). With only a large bar or none, the bar comes with new scroll
            // views each time, which is when UIKit sets their insets: one stack serves every arrangement.
            .navigationBarHidden(when: arrangement.hasPanes)
        }
        // Read around the stack, not in it. With two panes home fills the stack, so the fold is in the panes'
        // coordinates.
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onHorizontalFoldChange(minimumAbove: foldPaneMinimum, minimumBelow: foldScrollingPaneMinimum) { fold = $0 }
        .onVerticalFoldChange { foldRunsDown = $0 }
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
        // Last, so the sheets see it too.
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

    var arrangement: HomeArrangement {
        HomeArrangement.make(width: width, fold: fold, foldRunsDown: foldRunsDown)
    }

    @ViewBuilder
    private func loaded(_ content: HomeContent) -> some View {
        if arrangement.hasPanes {
            // Rows above and below a fold or columns beside it, these stay the same two scroll views when the half-open
            // device turns, so each keeps where it was scrolled to. Opening it flat swaps them for the one column
            // (ADR-0066).
            let panes = arrangement.fold.map { AnyLayout(FoldedStackLayout(fold: $0)) }
                ?? AnyLayout(HStackLayout(alignment: .top, spacing: 0))
            panes {
                ScrollView { heroPanel(content).padding(HomeArrangement.panePadding) }
                    // Laid out inside the safe area, so its height is what the dad sees without scrolling.
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heroPaneHeight = $0 }
                    .frame(maxWidth: .infinity)
                    .modifier(celebrationOverlay)
                ScrollView { adventure(content).padding(HomeArrangement.panePadding) }
                    .frame(maxWidth: .infinity)
            }
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
                onUndo: { Task { await viewModel.undoMoment() } },
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
