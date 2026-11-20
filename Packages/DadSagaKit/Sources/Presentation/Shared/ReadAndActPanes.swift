import DesignSystem
import SwiftUI

/// A sheet's scrolling column in two parts: what the dad reads, then what he does. On an iPhone Duo half-open like a
/// laptop, the reading stands above the fold and the doing lies below it, each scrolling on its own (ADR-0043).
/// Everywhere else, and for a sheet with nothing to do, it is one column as before.
///
/// The doing keeps its place in the view tree in both layouts, so a fold keeps the note's focus, an open picker and
/// photos still loading. With the keyboard up there is no room below the fold: the column is one again, and what the
/// dad writes stays in view above the keyboard.
struct ReadAndActPanes<Reading: View, Acting: View, Column: ViewModifier>: View {
    private let alignment: HorizontalAlignment
    private let spacing: CGFloat
    private let splits: Bool
    private let column: Column
    private let reading: Reading
    private let acting: Acting
    @State private var fold: HorizontalFold?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The least room the doing needs below the fold, more at larger text sizes.
    @ScaledMetric(relativeTo: .body) private var minimumBelow: CGFloat = 160

    /// - Parameters:
    ///   - alignment, spacing: how both parts line up in the column, and the space between their views.
    ///   - splits: `false` when there is nothing to do, so nothing is worth a pane of its own.
    ///   - column: the column's width, padding and text alignment, applied to each pane's column.
    init(
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat = DSSpacing.m,
        splits: Bool = true,
        column: Column,
        @ViewBuilder reading: () -> Reading,
        @ViewBuilder acting: () -> Acting
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.splits = splits
        self.column = column
        self.reading = reading()
        self.acting = acting()
    }

    var body: some View {
        let fold = splits ? fold : nil
        let panes = fold.map { AnyLayout(FoldedStackLayout(fold: $0)) } ?? AnyLayout(VStackLayout(spacing: 0))
        panes {
            if fold != nil {
                ScrollView {
                    VStack(alignment: alignment, spacing: spacing) { reading }
                        .modifier(column)
                }
            }
            ScrollView {
                VStack(alignment: alignment, spacing: spacing) {
                    if fold == nil { reading }
                    acting
                }
                .modifier(column)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Read where the panes are placed, so the fold is in their coordinates.
        .onHorizontalFoldChange(minimumAbove: foldPaneMinimum, minimumBelow: minimumBelow) { self.fold = $0 }
        .animation(reduceMotion ? nil : .smooth, value: fold)
    }
}
