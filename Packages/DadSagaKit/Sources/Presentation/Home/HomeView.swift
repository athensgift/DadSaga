import DesignSystem
import SwiftUI

/// Home: the dad's hero and progress, then what he can play today.
/// On wide screens (iPhone Duo inner display, landscape) it splits into two equal columns, so neither column
/// runs across the middle of the display, where the Duo folds.
public struct HomeView: View {
    @State private var viewModel: HomeViewModel
    @State private var isWide = false
    private let developerMenu: DeveloperMenu?

    public init(viewModel: HomeViewModel, developerMenu: DeveloperMenu? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.developerMenu = developerMenu
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
            .toolbar { DeveloperMenuToolbar(menu: developerMenu) }
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
            HeroAvatar(style: style, size: isWide ? 260 : 210, cheerTrigger: viewModel.celebration?.id ?? 0)
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
                .overlay(alignment: .top) { celebrationBadge }
                .accessibilityLabel(content.heroTitle)
            VStack(spacing: DSSpacing.xs) {
                Text(content.companionLine)
                    .font(DSFont.headline)
                    .foregroundStyle(style.tint)
                Text(content.heroTagline)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .multilineTextAlignment(.center)
            levelPanel(content)
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.celebration)
    }

    private func levelPanel(_ content: HomeContent) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(content.levelTitle)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                Text(content.xpLine)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            XPBar(fraction: content.levelFraction)
        }
        .padding(DSSpacing.m)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: content.levelFraction)
        .accessibilityElement(children: .combine)
    }

    private func adventure(_ content: HomeContent) -> some View {
        LazyVStack(alignment: .leading, spacing: DSSpacing.s) {
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

    /// Floating, transient feedback: the one place on this screen where Liquid Glass sits over content.
    @ViewBuilder private var celebrationBadge: some View {
        if let celebration = viewModel.celebration {
            VStack(spacing: DSSpacing.xs) {
                Text(celebration.xpText)
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.xp)
                if let levelUpText = celebration.levelUpText {
                    Label(levelUpText, systemImage: "star.fill")
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.legendary)
                }
                if let badgeText = celebration.badgeText {
                    Label(badgeText, systemImage: "rosette")
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.boss)
                }
            }
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, DSSpacing.l)
            .padding(.vertical, DSSpacing.m)
            .glassEffect(.regular, in: .rect(cornerRadius: DSRadius.card))
            .offset(y: -DSSpacing.l)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
            .task(id: celebration.id) {
                try? await Task.sleep(for: .seconds(2.2))
                viewModel.celebrationFinished()
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
