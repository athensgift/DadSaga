import DesignSystem
import SwiftUI

// MARK: - Header and toolbar buttons

extension HomeView {
    /// The two-pane layouts have no navigation bar, so their title and buttons sit at the top of the hero pane.
    func paneHeader(_ content: HomeContent) -> some View {
        HStack {
            Text(content.heroTitle)
                .font(DSFont.largeTitle)
                .foregroundStyle(DSColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            worldMapButton
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
            settingsButton
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
        }
    }

    var worldMapButton: some View {
        Button {
            viewModel.openMap()
        } label: {
            Label(worldMapTitle, systemImage: "map")
        }
    }

    var worldMapTitle: String {
        if case .loaded(let content) = viewModel.state { content.mapTitle } else { "" }
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

    /// Settings closed: what "My family" or "Your hero" changed shows on home, and nothing in them holds a link back.
    func settingsDismissed() {
        unsavedWork.end(scope: UnsavedScope.settings)
        Task { await viewModel.reload() }
    }

    /// A quest, boss or moment sheet closed, recorded or not: nothing in it holds a link back any more (ADR-0050).
    func homeSheetDismissed() {
        unsavedWork.end(scope: UnsavedScope.homeSheet)
        viewModel.sheetDismissed()
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
