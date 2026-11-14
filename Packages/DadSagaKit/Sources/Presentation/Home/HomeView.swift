import DesignSystem
import SwiftUI

/// Home: the dad's hero and progress, then what he can play today.
/// On wide screens (iPhone Duo inner display, landscape) it splits into two equal columns, so neither column
/// runs across the middle of the display, where the Duo folds.
public struct HomeView: View {
    public typealias MakeFamily = @MainActor (_ onSaved: @escaping @MainActor () -> Void) -> FamilyViewModel

    @State private var viewModel: HomeViewModel
    @State private var isWide = false
    @State private var familyViewModel: FamilyViewModel?
    private let developerMenu: DeveloperMenu?
    private let makeFamily: MakeFamily?

    /// - Parameter makeFamily: builds the "My family" screen; `nil` hides its button.
    public init(viewModel: HomeViewModel, developerMenu: DeveloperMenu? = nil, makeFamily: MakeFamily? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.developerMenu = developerMenu
        self.makeFamily = makeFamily
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
            .navigationTitle(title)
            // Two columns scroll separately. A navigation bar collapses or hides with whichever column scrolls and
            // shifts the other, so the wide layout has no bar: its title lives in the hero column.
            .navigationBarHidden(when: isWide)
            .toolbar {
                if makeFamily != nil {
                    ToolbarItem(placement: .primaryAction) { familyButton }
                }
                DeveloperMenuToolbar(menu: developerMenu)
            }
        }
        .sheet(item: $familyViewModel) { family in
            FamilyView(viewModel: family) { familyViewModel = nil }
        }
        .onGeometryChange(for: Bool.self) { $0.size.width >= twoColumnWidth } action: { isWide = $0 }
        .task { await viewModel.onAppear() }
        .sheet(item: activeSheet) { sheet in
            switch sheet {
            case .quest(let quest):
                QuestSheet(quest: quest, errorMessage: viewModel.errorMessage, isCompleting: viewModel.isCompleting) {
                    Task { await viewModel.completeSelectedQuest() }
                } onClose: {
                    viewModel.dismissSelection()
                }
                .presentationDetents([.medium])
            case .boss(let boss):
                BossSheet(boss: boss, errorMessage: viewModel.errorMessage, isCompleting: viewModel.isCompleting) {
                    Task { await viewModel.defeatSelectedBoss() }
                } onClose: {
                    viewModel.dismissSelection()
                }
            }
        }
    }

    private var familyButton: some View {
        Button {
            openFamily()
        } label: {
            Label(familyTitle, systemImage: "person.2")
        }
    }

    private var familyTitle: String {
        if case .loaded(let content) = viewModel.state { content.familyTitle } else { "" }
    }

    private func openFamily() {
        familyViewModel = makeFamily? {
            familyViewModel = nil
            Task { await viewModel.reload() }
        }
    }

    private var title: String {
        if case .loaded(let content) = viewModel.state { content.heroTitle } else { "" }
    }

    private var activeSheet: Binding<HomeSheet?> {
        Binding(
            get: { viewModel.selectedQuest.map(HomeSheet.quest) ?? viewModel.selectedBoss.map(HomeSheet.boss) },
            set: { if $0 == nil { viewModel.dismissSelection() } }
        )
    }

    @ViewBuilder
    private func loaded(_ content: HomeContent) -> some View {
        if isWide {
            HStack(alignment: .top, spacing: 0) {
                ScrollView { heroPanel(content).padding(DSSpacing.l) }
                    .frame(maxWidth: .infinity)
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
        }
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
            .overlay(alignment: .top) {
                if let celebration = viewModel.celebration {
                    CelebrationBadge(celebration: celebration) { viewModel.celebrationFinished() }
                }
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
            LevelPanel(title: content.levelTitle, xpLine: content.xpLine, fraction: content.levelFraction)
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.celebration)
    }

    /// The wide layout has no navigation bar, so its title and buttons sit at the top of the hero column.
    private func wideHeader(_ content: HomeContent) -> some View {
        HStack {
            Text(content.heroTitle)
                .font(DSFont.largeTitle)
                .foregroundStyle(DSColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
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
            if let worldTitle = content.worldTitle {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(worldTitle)
                        .font(DSFont.title)
                        .foregroundStyle(DSColor.textPrimary)
                    if let worldTagline = content.worldTagline {
                        Text(worldTagline)
                            .font(DSFont.subheadline)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }
                .padding(.bottom, DSSpacing.s)
                .accessibilityAddTraits(.isHeader)
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
                        footnote: card.footnote
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// The one sheet the home screen can show at a time.
private enum HomeSheet: Identifiable {
    case quest(QuestDetail)
    case boss(BossDetail)

    var id: String {
        switch self {
        case .quest(let quest): "quest-" + quest.id
        case .boss(let boss): "boss-" + boss.id
        }
    }
}
