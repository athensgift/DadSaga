import DesignSystem
import SwiftUI

// MARK: - Header and toolbar buttons

extension HomeView {
    /// The two-pane layouts have no navigation bar, so their title sits at the top of the hero pane.
    func paneHeader(_ content: HomeContent) -> some View {
        Text(content.heroTitle)
            .font(DSFont.largeTitle)
            .foregroundStyle(DSColor.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { paneHeaderHeight = $0 }
    }

    /// The map and Settings in the two-pane layouts: by the tab bar, at the trailing edge, as they are in the side
    /// bar the system draws on the Duo's cover display (ADR-0056).
    /// Room under the adventure's last card for the map and Settings over it.
    static let paneButtonsClearance: CGFloat = 72

    var paneButtons: some View {
        GlassEffectContainer(spacing: DSSpacing.s) {
            HStack(spacing: DSSpacing.s) {
                worldMapButton
                settingsButton
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .controlSize(.large)
        }
        .padding(DSSpacing.m)
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
