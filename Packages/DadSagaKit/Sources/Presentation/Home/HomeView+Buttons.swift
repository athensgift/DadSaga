import DesignSystem
import SwiftUI

// MARK: - Header and toolbar buttons

extension HomeView {
    /// The wide layout has no navigation bar, so its title and buttons sit at the top of the hero column.
    func wideHeader(_ content: HomeContent) -> some View {
        HStack {
            Text(content.heroTitle)
                .font(DSFont.largeTitle)
                .foregroundStyle(DSColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            wardrobeButton
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
            settingsButton
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
        }
    }

    var wardrobeButton: some View {
        Button {
            wardrobeViewModel = makeWardrobe()
        } label: {
            Label(wardrobeTitle, systemImage: "tshirt")
        }
    }

    var wardrobeTitle: String {
        if case .loaded(let content) = viewModel.state { content.wardrobeTitle } else { "" }
    }

    var settingsButton: some View {
        Button {
            settingsViewModel = settings.makeSettings()
        } label: {
            Label(settingsTitle, systemImage: "gearshape")
        }
    }

    var settingsTitle: String {
        if case .loaded(let content) = viewModel.state { content.settingsTitle } else { "" }
    }

    func reloadAfterSheet() {
        Task { await viewModel.reload() }
    }
}

// MARK: - Offers

extension HomeView {
    /// At most one offer at a time: the weekly reminder waits while a film is offered (ADR-0037 §5).
    @ViewBuilder var offerCard: some View {
        if let offer = viewModel.sagaOffer {
            OfferCard(offer) { accept in
                Task {
                    guard let request = await viewModel.answerSagaOffer(accept: accept) else { return }
                    sagaFilm = makeSagaFilm(request)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else if let offer = viewModel.reminderOffer {
            OfferCard(offer) { accept in
                Task { await viewModel.answerReminderOffer(accept: accept) }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}
