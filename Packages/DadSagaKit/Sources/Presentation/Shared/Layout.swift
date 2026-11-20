import SwiftUI

/// Widest the main column gets on large screens, so lines stay readable.
let readableWidth: CGFloat = 560

/// From this width on, home shows two columns (iPhone Duo's inner display on its side, flat or half-open like a
/// book; landscape on large iPhones). Upright, the inner display is split where it folds instead (ADR-0045).
let twoColumnWidth: CGFloat = 600

/// The least height a pane above a fold needs for a screen to split at the fold (ADR-0043).
let foldPaneMinimum: CGFloat = 200

/// The least height a scrolling pane below a fold needs: little, so a bar that comes and goes at the bottom (home's
/// undo bar) doesn't unfold the screen.
let foldScrollingPaneMinimum: CGFloat = 120

extension View {
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
