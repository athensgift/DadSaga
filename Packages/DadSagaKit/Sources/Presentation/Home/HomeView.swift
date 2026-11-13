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
        .sheet(item: selectedQuest) { quest in
            QuestSheet(quest: quest, errorMessage: viewModel.errorMessage, isCompleting: viewModel.isCompleting) {
                Task { await viewModel.completeSelectedQuest() }
            } onCancel: {
                viewModel.dismissSelection()
            }
            .presentationDetents([.medium])
        }
    }

    private var selectedQuest: Binding<QuestDetail?> {
        Binding(
            get: { viewModel.selectedQuest },
            set: { if $0 == nil { viewModel.dismissSelection() } }
        )
    }

    private func loadedView(_ content: HomeContent) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSSpacing.m) {
                heroStage(content)
                VStack(alignment: .trailing, spacing: DSSpacing.xs) {
                    XPBar(level: content.level, fraction: content.levelFraction)
                    Text(content.xpLine)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: content.levelFraction)
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
                    cardView(card)
                }
            }
            .padding(DSSpacing.m)
        }
    }

    @ViewBuilder
    private func cardView(_ card: CardModel) -> some View {
        let questCard = QuestCard(
            title: card.title,
            subtitle: card.subtitle,
            badge: card.badge,
            style: card.kind.cardStyle,
            footnote: card.footnote
        )
        if card.kind == .quest {
            Button { viewModel.select(cardID: card.id) } label: { questCard }
                .buttonStyle(.plain)
        } else {
            questCard
        }
    }

    private func heroStage(_ content: HomeContent) -> some View {
        let style = content.heroLook.avatarStyle
        return VStack(spacing: DSSpacing.s) {
            HeroAvatar(style: style, size: 230, cheerTrigger: viewModel.celebration?.id ?? 0)
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
                .overlay(alignment: .top) { celebrationBadge }
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
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: viewModel.celebration)
    }

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
            }
            .padding(.horizontal, DSSpacing.m)
            .padding(.vertical, DSSpacing.s)
            .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card))
            .offset(y: -DSSpacing.s)
            .transition(.scale(scale: 0.5).combined(with: .opacity).combined(with: .move(edge: .bottom)))
            .task(id: celebration.id) {
                try? await Task.sleep(for: .seconds(2.2))
                viewModel.celebrationFinished()
            }
        }
    }
}

private struct QuestSheet: View {
    let quest: QuestDetail
    let errorMessage: String?
    let isCompleting: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.m) {
            Text(quest.reward)
                .font(DSFont.caption)
                .padding(.horizontal, DSSpacing.s)
                .padding(.vertical, DSSpacing.xs)
                .background(DSColor.accent.opacity(0.15), in: Capsule())
                .foregroundStyle(DSColor.accent)
            Text(quest.title)
                .font(DSFont.title)
                .foregroundStyle(DSColor.textPrimary)
            Text(quest.description)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
            Spacer(minLength: 0)
            if let errorMessage {
                Text(errorMessage)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.boss)
            }
            Button(quest.confirmTitle, action: onConfirm)
                .buttonStyle(.dsPrimary)
                .disabled(isCompleting)
            Button(quest.cancelTitle, action: onCancel)
                .font(DSFont.body)
                .tint(DSColor.textSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(DSSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
    }
}
