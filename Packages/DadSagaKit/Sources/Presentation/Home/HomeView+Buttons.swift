import DesignSystem
import SwiftUI

// MARK: - Header and toolbar buttons

extension HomeView {
    /// With two panes the navigation bar shows no title (or there is none), so it sits at the top of the hero pane.
    func paneHeader(_ content: HomeContent) -> some View {
        Text(content.heroTitle)
            .font(DSFont.largeTitle)
            .foregroundStyle(DSColor.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { paneHeaderHeight = $0 }
    }

    /// The map and Settings above and below a fold: one glass capsule by the tab bar, at the trailing edge, as they
    /// are in the side bar the system draws on the Duo's cover display (ADR-0056, ADR-0058).
    var paneButtons: some View {
        HStack(spacing: 0) {
            paneButton(worldMapTitle, systemImage: "map", action: openMap)
            paneButton(settingsTitle, systemImage: "gearshape", action: openSettings)
        }
        .padding(.horizontal, DSSpacing.xs)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(DSSpacing.m)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { paneButtonsHeight = $0 }
        .accessibilitySortPriority(1)
    }

    private func paneButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(DSFont.symbol)
                .frame(width: 48, height: 48)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
    }

    var worldMapButton: some View {
        Button(action: openMap) {
            Label(worldMapTitle, systemImage: "map")
        }
    }

    func openMap() {
        viewModel.openMap()
    }

    var worldMapTitle: String {
        if case .loaded(let content) = viewModel.state { content.mapTitle } else { "" }
    }

    var settingsButton: some View {
        Button(action: openSettings) {
            Label(settingsTitle, systemImage: "gearshape")
        }
    }

    func openSettings() {
        settingsViewModel = settings.makeSettings()
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

// MARK: - The stage

extension HomeView {
    /// Above a fold the pane is wider than tall: the hero stands beside his lines and title, unless the text is too
    /// large for half the width.
    var isHeroBesideTitle: Bool {
        arrangement.fold != nil && !dynamicTypeSize.isAccessibilitySize
    }

    /// The dad and his children, on the glow of his colour.
    func heroStage(_ content: HomeContent) -> some View {
        let style = content.heroLook.avatarStyle
        return FamilyStage(
            heroStyle: style,
            heroSkin: content.heroSkin.avatarSkin,
            heroFeatures: content.heroAppearance.avatarFeatures,
            heroGear: content.heroGear.map(\.heroItem),
            medals: content.medalCount,
            heroTitle: content.heroTitle,
            companions: content.companions,
            selectedChildID: content.selectedChildID,
            maxHeroSize: arrangement.maxHeroSize(headerHeight: paneHeaderHeight, besideTitle: isHeroBesideTitle),
            cheerTrigger: viewModel.celebration?.id ?? 0
        ) { id in
            Task { await viewModel.selectChild(id: id) }
        }
        .padding(.top, HomeArrangement.stageTopPadding)
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
    }
}

// MARK: - Offers

extension HomeView {
    /// At most one card at a time: a new title first, then a film, then the weekly reminder (ADR-0055 §6, ADR-0037 §5).
    @ViewBuilder var offerCard: some View {
        if let card = viewModel.titleCard {
            OfferCard(card) { Task { await viewModel.closeTitleCard() } }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else if let offer = viewModel.sagaOffer {
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
