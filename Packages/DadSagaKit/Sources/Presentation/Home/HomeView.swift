import DesignSystem
import SwiftUI

/// Home: the dad's hero and progress, then what he can play today.
/// On wide screens (iPhone Duo inner display, landscape) it splits into two equal columns, so neither column
/// runs across the middle of the display, where the Duo folds.
public struct HomeView: View {
    public typealias MakeFamily = @MainActor (_ onSaved: @escaping @MainActor () -> Void) -> FamilyViewModel
    public typealias MakeWardrobe = @MainActor () -> WardrobeViewModel

    @State var viewModel: HomeViewModel
    @State private var isWide = false
    @State var familyViewModel: FamilyViewModel?
    @State var wardrobeViewModel: WardrobeViewModel?
    private let developerMenu: DeveloperMenu?
    let makeFamily: MakeFamily?
    let makeWardrobe: MakeWardrobe?

    /// - Parameters:
    ///   - makeFamily: builds the "My family" screen; `nil` hides its button.
    ///   - makeWardrobe: builds the wardrobe; `nil` hides its button.
    public init(
        viewModel: HomeViewModel,
        developerMenu: DeveloperMenu? = nil,
        makeFamily: MakeFamily? = nil,
        makeWardrobe: MakeWardrobe? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.developerMenu = developerMenu
        self.makeFamily = makeFamily
        self.makeWardrobe = makeWardrobe
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
                if makeWardrobe != nil {
                    ToolbarItem(placement: .primaryAction) { wardrobeButton }
                }
                if makeFamily != nil {
                    ToolbarItem(placement: .primaryAction) { familyButton }
                }
                DeveloperMenuToolbar(menu: developerMenu)
            }
        }
        .sheet(item: $familyViewModel) { family in
            FamilyView(viewModel: family) { familyViewModel = nil }
        }
        .sheet(item: worldMapBinding) { map in
            WorldMapSheet(map: map) { id in
                Task { await viewModel.showWorld(id: id) }
            } onClose: {
                viewModel.closeMap()
            }
        }
        .sheet(item: $wardrobeViewModel, onDismiss: reloadAfterWardrobe) { wardrobe in
            WardrobeView(viewModel: wardrobe) { wardrobeViewModel = nil }
        }
        .onGeometryChange(for: Bool.self) { $0.size.width >= twoColumnWidth } action: { isWide = $0 }
        .task { await viewModel.onAppear() }
        .sheet(item: activeSheet) { sheet in
            switch sheet {
            case .quest(let quest):
                questSheet(quest)
            case .boss(let boss):
                bossSheet(boss)
            case .moment(let capture):
                MomentSheet(
                    capture: capture,
                    errorMessage: viewModel.errorMessage,
                    isSaving: viewModel.isCompleting,
                    loader: { await viewModel.photoData(id: $0) },
                    onSave: { id, date, note, photo in
                        Task { await viewModel.saveMoment(firstID: id, date: date, note: note, photo: photo) }
                    },
                    onDelete: { Task { await viewModel.deleteMoment() } },
                    onClose: { viewModel.dismissSelection() }
                )
            }
        }
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
                Text(content.companionLine)
                    .font(DSFont.headline)
                    .foregroundStyle(style.tint)
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

    /// The wide layout has no navigation bar, so its title and buttons sit at the top of the hero column.
    private func wideHeader(_ content: HomeContent) -> some View {
        HStack {
            Text(content.heroTitle)
                .font(DSFont.largeTitle)
                .foregroundStyle(DSColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if makeWardrobe != nil {
                wardrobeButton
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
            }
            if makeFamily != nil {
                familyButton
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
            }
            if let developerMenu {
                DeveloperMenuButton(menu: developerMenu)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
            }
        }
    }

    private func adventure(_ content: HomeContent) -> some View {
        LazyVStack(alignment: .leading, spacing: DSSpacing.s) {
            if !content.childTabs.isEmpty {
                ChildPicker(content: content) { id in Task { await viewModel.selectChild(id: id) } }
            }
            WorldHeader(content: content) {
                viewModel.openMap()
            } onBack: {
                Task { await viewModel.showWorld(id: nil) }
            }
            if let emptyMessage = content.emptyMessage {
                ContentUnavailableView(emptyMessage, systemImage: "flag.checkered")
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
                loader: { await viewModel.photoData(id: $0) },
                onAdd: { viewModel.startCapture() },
                onEdit: { viewModel.editMoment(id: $0) }
            )
                .padding(.top, DSSpacing.l)
        }
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

// MARK: - Family and wardrobe buttons

extension HomeView {
    var wardrobeButton: some View {
        Button {
            wardrobeViewModel = makeWardrobe?()
        } label: {
            Label(wardrobeTitle, systemImage: "tshirt")
        }
    }

    var wardrobeTitle: String {
        if case .loaded(let content) = viewModel.state { content.wardrobeTitle } else { "" }
    }

    var familyTitle: String {
        if case .loaded(let content) = viewModel.state { content.familyTitle } else { "" }
    }

    func openFamily() {
        familyViewModel = makeFamily? {
            familyViewModel = nil
            Task { await viewModel.reload() }
        }
    }

    func reloadAfterWardrobe() {
        Task { await viewModel.reload() }
    }
}

extension HomeView {
    private var familyButton: some View {
        Button {
            openFamily()
        } label: {
            Label(familyTitle, systemImage: "person.2")
        }
    }

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
            loader: { await viewModel.photoData(id: $0) },
            onConfirm: { note, photo in Task { await viewModel.completeSelectedQuest(note: note, photo: photo) } },
            onClose: { viewModel.dismissSelection() }
        )
        .presentationDetents([.medium, .large])
    }

    func bossSheet(_ boss: BossDetail) -> some View {
        BossSheet(
            boss: boss,
            errorMessage: viewModel.errorMessage,
            isCompleting: viewModel.isCompleting,
            loader: { await viewModel.photoData(id: $0) },
            onConfirm: { note, photo in Task { await viewModel.defeatSelectedBoss(note: note, photo: photo) } },
            onClose: { viewModel.dismissSelection() }
        )
    }
}
