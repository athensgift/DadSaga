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
            if makeReminderSettings != nil {
                reminderButton
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

    var reminderButton: some View {
        Button {
            reminderViewModel = makeReminderSettings?()
        } label: {
            Label(reminderTitle, systemImage: "bell")
        }
    }

    var reminderTitle: String {
        if case .loaded(let content) = viewModel.state { content.reminderTitle } else { "" }
    }

    func reloadAfterSheet() {
        Task { await viewModel.reload() }
    }

    var familyButton: some View {
        Button {
            openFamily()
        } label: {
            Label(familyTitle, systemImage: "person.2")
        }
    }
}
