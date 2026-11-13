import DesignSystem
import SwiftUI

/// Home: the dad's hero on stage, his companion, and today's quests.
public struct HomeView: View {
    @State private var viewModel: HomeViewModel

    public init(viewModel: HomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .loaded(let content):
                loadedView(content)
            case .failed(let message):
                ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
        .task { await viewModel.onAppear() }
    }

    private func loadedView(_ content: HomeContent) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSSpacing.m) {
                heroStage(content)
                XPBar(level: content.level, fraction: content.levelFraction)
                if let worldTitle = content.worldTitle {
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        Text(worldTitle).font(DSFont.title).foregroundStyle(DSColor.textPrimary)
                        if let worldTagline = content.worldTagline {
                            Text(worldTagline).font(DSFont.body).foregroundStyle(DSColor.textSecondary)
                        }
                    }
                    .padding(.top, DSSpacing.s)
                }
                ForEach(content.cards) { card in
                    QuestCard(title: card.title, subtitle: card.subtitle, badge: card.badge, style: card.kind.cardStyle)
                }
            }
            .padding(DSSpacing.m)
        }
    }

    private func heroStage(_ content: HomeContent) -> some View {
        let style = content.heroLook.avatarStyle
        return VStack(spacing: DSSpacing.s) {
            HeroAvatar(style: style, size: 230)
                .background {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [style.tint.opacity(0.35), style.tint.opacity(0)],
                                center: .center,
                                startRadius: 10,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                }
                .accessibilityLabel(content.heroTitle)
            Text(content.heroTitle)
                .font(DSFont.title)
                .foregroundStyle(DSColor.textPrimary)
            Text(content.companionLine)
                .font(DSFont.headline)
                .foregroundStyle(style.tint)
            Text(content.heroTagline)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.m)
    }
}
