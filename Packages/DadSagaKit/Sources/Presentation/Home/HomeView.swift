import DesignSystem
import HeroArt
import SwiftUI

/// Home: the dad's hero and progress, then what he can play today.
/// On wide screens (iPhone Duo inner display, landscape) it splits into two equal columns, so neither column
/// runs across the middle of the display, where the Duo folds.
public struct HomeView: View {
    public typealias MakeWardrobe = @MainActor () -> WardrobeViewModel

    @State var viewModel: HomeViewModel
    @State private var isWide = false
    @State var wardrobeViewModel: WardrobeViewModel?
    @State var settingsViewModel: SettingsViewModel?
    /// The film sheet, opened from the film offer.
    @State var sagaFilm: SagaFilmViewModel?
    /// A moment's photos, full screen.
    @State var photoViewer: PhotoViewerContent?
    let makeWardrobe: MakeWardrobe
    let makeSagaFilm: SagaFilmSheet.MakeViewModel
    let settings: SettingsScreens
    let pendingLink: PendingLink?
    let onLinkHandled: @MainActor () -> Void

    /// - Parameters:
    ///   - makeWardrobe, settings: build the screens behind the toolbar buttons.
    ///   - makeSagaFilm: builds the film sheet for the film home offers.
    ///   - pendingLink: a link from outside the app (the widget) to open; `onLinkHandled` runs once it is open.
    public init(
        viewModel: HomeViewModel,
        makeWardrobe: @escaping MakeWardrobe,
        makeSagaFilm: @escaping SagaFilmSheet.MakeViewModel,
        settings: SettingsScreens,
        pendingLink: PendingLink? = nil,
        onLinkHandled: @escaping @MainActor () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeWardrobe = makeWardrobe
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
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.undoOffer)
            .navigationTitle(title)
            // Two columns scroll separately. A navigation bar collapses or hides with whichever column scrolls and
            // shifts the other, so the wide layout has no bar: its title lives in the hero column.
            .navigationBarHidden(when: isWide)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { wardrobeButton }
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
        .sheet(item: $wardrobeViewModel, onDismiss: reloadAfterSheet) { wardrobe in
            WardrobeView(viewModel: wardrobe) { wardrobeViewModel = nil }
        }
        .sheet(item: $settingsViewModel, onDismiss: reloadAfterSheet) { settingsModel in
            SettingsView(viewModel: settingsModel, pages: settings.pages) { settingsViewModel = nil }
        }
        .sagaFilmSheet($sagaFilm)
        .onGeometryChange(for: Bool.self) { $0.size.width >= twoColumnWidth } action: { isWide = $0 }
        .task { await viewModel.onAppear() }
        .task(id: pendingLink) { await openPendingLink() }
        .sheet(item: activeSheet) { sheet in
            switch sheet {
            case .quest(let quest):
                questSheet(quest)
            case .boss(let boss):
                bossSheet(boss)
            case .moment(let capture):
                momentSheet(capture)
            }
        }
        .photoViewer($photoViewer, loader: { await viewModel.photoData(id: $0, maxPixelSize: $1) })
    }

    private var title: String {
        if case .loaded(let content) = viewModel.state { content.heroTitle } else { "" }
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

    @ViewBuilder
    private func loaded(_ content: HomeContent) -> some View {
        if isWide {
            HStack(alignment: .top, spacing: 0) {
                ScrollView { heroPanel(content).padding(DSSpacing.l) }
                    .frame(maxWidth: .infinity)
                    .modifier(celebrationOverlay)
                ScrollView { adventure(content).padding(DSSpacing.l) }
                    .frame(maxWidth: .infinity)
            }
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
    /// On wide screens it stays in the hero column, away from the Duo's fold.
    private var celebrationOverlay: CelebrationOverlay {
        CelebrationOverlay(celebration: viewModel.celebration) { viewModel.celebrationFinished() }
    }

    private func heroPanel(_ content: HomeContent) -> some View {
        let style = content.heroLook.avatarStyle
        return VStack(spacing: DSSpacing.m) {
            if isWide {
                wideHeader(content)
            }
            FamilyStage(
                heroStyle: style,
                heroSkin: content.heroSkin.avatarSkin,
                heroGear: content.heroGear.map(\.heroItem),
                medals: content.medalCount,
                heroTitle: content.heroTitle,
                companions: content.companions,
                selectedChildID: content.selectedChildID,
                maxHeroSize: isWide ? 260 : 210,
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
        .frame(maxWidth: .infinity)
    }

    private func adventure(_ content: HomeContent) -> some View {
        LazyVStack(alignment: .leading, spacing: DSSpacing.s) {
            if !content.childTabs.isEmpty {
                ChildPicker(content: content) { id in Task { await viewModel.selectChild(id: id) } }
            }
            offerCard
            WorldHeader(content: content) {
                viewModel.openMap()
            } onBack: {
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
                onCelebrationFinished: { viewModel.momentCelebrationFinished() },
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
        let hadSheet = wardrobeViewModel != nil || settingsViewModel != nil || sagaFilm != nil
            || viewModel.worldMap != nil || photoViewer != nil
        wardrobeViewModel = nil
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
