import SwiftUI

/// Widest the main column gets on large screens, so lines stay readable.
let readableWidth: CGFloat = 560

/// From this width on, home shows two columns (iPhone Duo inner display flat or half-open like a book, landscape
/// on large iPhones).
let twoColumnWidth: CGFloat = 600

/// The least height a pane above or below a fold needs for a screen to split at the fold (ADR-0043).
let foldPaneMinimum: CGFloat = 200

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
