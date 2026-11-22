import SwiftUI

/// Widest the main column gets on large screens, so lines stay readable.
let readableWidth: CGFloat = 560

/// From this width on, home shows two columns (the iPhone Duo's inner display open flat, upright or on its side, or
/// half-open like a book; landscape on large iPhones). Half-open like a laptop, it is split at the fold instead
/// (ADR-0061 §1).
let twoColumnWidth: CGFloat = 600

/// The least height a pane above a fold needs for a screen to split at the fold (ADR-0043).
let foldPaneMinimum: CGFloat = 200

/// The least height a pane the dad acts in needs below a fold, at the default text size, for a screen to split.
let foldActingPaneMinimum: CGFloat = 160

/// The least height a scrolling pane below a fold needs: little, so a bar that comes and goes at the bottom (home's
/// undo bar) doesn't unfold the screen.
let foldScrollingPaneMinimum: CGFloat = 120

extension View {
    /// Hides the tab bar on iOS. A no-op on macOS, where the package is only built to run its tests.
    @ViewBuilder
    func tabBarHidden(when isHidden: Bool) -> some View {
        #if os(iOS)
        toolbar(isHidden ? .hidden : .automatic, for: .tabBar)
        #else
        self
        #endif
    }

    /// Hides the navigation bar on iOS. A no-op on macOS, where the package is only built to run its tests.
    @ViewBuilder
    func navigationBarHidden(when isHidden: Bool) -> some View {
        #if os(iOS)
        toolbar(isHidden ? .hidden : .automatic, for: .navigationBar)
        #else
        self
        #endif
    }
}
