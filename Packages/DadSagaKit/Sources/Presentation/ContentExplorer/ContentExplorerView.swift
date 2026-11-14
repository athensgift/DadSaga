import DesignSystem
import SwiftUI

/// Phase 1 placeholder screen: proves the Data → Use Case → Presenter → View pipeline end to end.
/// Replaced by onboarding and the world map in Phase 2.
public struct ContentExplorerView: View {
    @State private var viewModel: ContentExplorerViewModel

    public init(viewModel: ContentExplorerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
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
            .navigationTitle("DadSaga")
        }
        .task { await viewModel.onAppear() }
    }

    private func loadedView(_ content: ContentExplorerContent) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSSpacing.m) {
                XPBar(level: content.level, fraction: content.levelFraction)
                ForEach(content.worlds) { world in
                    sectionHeader(title: world.title, subtitle: world.tagline)
                    cards(world.cards)
                }
                sectionHeader(title: content.firstsTitle, subtitle: nil)
                cards(content.firsts)
            }
            .padding(DSSpacing.m)
        }
    }

    private func sectionHeader(title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title).font(DSFont.title).foregroundStyle(DSColor.textPrimary)
            if let subtitle {
                Text(subtitle).font(DSFont.body).foregroundStyle(DSColor.textSecondary)
            }
        }
        .padding(.top, DSSpacing.s)
    }

    private func cards(_ cards: [CardModel]) -> some View {
        ForEach(cards) { card in
            QuestCard(
                title: card.title,
                subtitle: card.subtitle,
                badge: card.badge,
                symbol: card.symbol,
                style: card.kind.cardStyle
            )
        }
    }
}
