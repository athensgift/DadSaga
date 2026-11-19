import SwiftUI

/// Widest the main column gets on large screens, so lines stay readable.
let readableWidth: CGFloat = 560

/// From this width on, home shows two columns (iPhone Duo inner display, landscape on large iPhones).
let twoColumnWidth: CGFloat = 600

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
