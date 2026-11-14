import SwiftUI

/// Debug-only actions offered from the navigation bar. `nil` in release builds, so nothing is shown.
public struct DeveloperMenu {
    let restartFromOnboarding: () -> Void

    public init(restartFromOnboarding: @escaping () -> Void) {
        self.restartFromOnboarding = restartFromOnboarding
    }
}

/// The developer menu as a toolbar item, so it sits in the system's glass navigation bar.
/// Its labels are not localised: it only exists in development builds.
struct DeveloperMenuToolbar: ToolbarContent {
    let menu: DeveloperMenu?

    var body: some ToolbarContent {
        if let menu {
            ToolbarItem(placement: .primaryAction) { DeveloperMenuButton(menu: menu) }
        }
    }
}

/// The developer menu's button on its own, for screens that hide the navigation bar.
struct DeveloperMenuButton: View {
    let menu: DeveloperMenu

    var body: some View {
        Menu {
            Button("Restart from onboarding", systemImage: "arrow.counterclockwise", role: .destructive) {
                menu.restartFromOnboarding()
            }
        } label: {
            Label("Developer menu", systemImage: "ladybug")
        }
    }
}

/// Widest the main column gets on large screens, so lines stay readable.
let readableWidth: CGFloat = 560

/// From this width on, home shows two columns (iPhone Duo inner display, landscape on large iPhones).
let twoColumnWidth: CGFloat = 600
