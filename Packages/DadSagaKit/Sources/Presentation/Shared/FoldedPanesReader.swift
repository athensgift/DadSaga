import DesignSystem
import SwiftUI

/// Keeps a sheet's `FoldedPanes` up to date: split at the fold, one column on a flat display, and the lower part
/// alone while the keyboard covers the lower half (ADR-0043).
struct FoldedPanesReader: ViewModifier {
    @Binding var panes: FoldedPanes
    @State private var sizeWhenSplit = CGSize.zero
    /// The least room the lower part needs below the fold, more at larger text sizes.
    @ScaledMetric(relativeTo: .body) private var minimumBelow: CGFloat = 160

    func body(content: Content) -> some View {
        // Read where the panes are placed, so the fold is in their coordinates.
        content.onFoldGeometryChange(minimumAbove: foldPaneMinimum, minimumBelow: minimumBelow) { geometry in
            panes = panes.next(geometry, sizeWhenSplit: sizeWhenSplit)
            if geometry.fold != nil { sizeWhenSplit = geometry.size }
        }
    }
}

extension FoldedPanes {
    /// The layout for two views: above and below the fold, the second alone, or one under the other.
    var layout: AnyLayout {
        switch self {
        case .flat: AnyLayout(VStackLayout(spacing: 0))
        case .split(let fold): AnyLayout(FoldedStackLayout(fold: fold))
        case .lowerOnly: AnyLayout(LowerPaneLayout())
        }
    }
}

extension View {
    /// The upper part while the keyboard has its room: in the tree, so it comes back as it was, but not seen,
    /// touched or read.
    func hiddenUpperPane(_ panes: FoldedPanes) -> some View {
        opacity(panes == .lowerOnly ? 0 : 1)
            .allowsHitTesting(panes != .lowerOnly)
            .accessibilityHidden(panes == .lowerOnly)
    }
}
