import DesignSystem
import SwiftUI

/// A page that is one `Form`, with something to look at above the fold on an iPhone Duo half-open like a laptop
/// (ADR-0061 §4). A form is one scroll view, so it can't keep a row off the fold: it goes whole into the half on the
/// table, where every control is near the hands, and scrolls on its own. On a flat display the form alone shows.
///
/// The form is the second view in every layout and never inside a scroll view, so a fold keeps where it was scrolled
/// to and a menu that is open.
struct FormBelowFold<Upper: View, Lower: View>: View {
    private let upper: () -> Upper
    private let lower: () -> Lower
    @State private var fold: HorizontalFold?
    /// The least room the form needs below the fold, more at larger text sizes.
    @ScaledMetric(relativeTo: .body) private var minimumBelow = foldActingPaneMinimum

    /// Split, the title is inline: a large title collapses as the form scrolls and would move the fold's place.
    /// - Parameters:
    ///   - upper: what stands above the fold.
    ///   - lower: the form.
    init(
        @ViewBuilder upper: @escaping () -> Upper,
        @ViewBuilder lower: @escaping () -> Lower
    ) {
        self.upper = upper
        self.lower = lower
    }

    var body: some View {
        let panes = fold.map { AnyLayout(FoldedStackLayout(fold: $0)) } ?? AnyLayout(VStackLayout(spacing: 0))
        return panes {
            if fold != nil {
                upper()
            }
            lower()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Read where the panes are placed, so the fold is in their coordinates.
        .onHorizontalFoldChange(minimumAbove: foldPaneMinimum, minimumBelow: minimumBelow) { fold = $0 }
        .toolbarTitleDisplayMode(fold == nil ? .automatic : .inline)
        .motion(.smooth, value: fold)
    }
}
