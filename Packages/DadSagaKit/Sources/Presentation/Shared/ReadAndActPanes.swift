import DesignSystem
import SwiftUI

/// A sheet's scrolling column in two parts: what the dad reads, then what he does. On an iPhone Duo half-open like a
/// laptop, the reading stands above the fold and the doing lies below it, each scrolling on its own (ADR-0043).
/// Everywhere else, and for a sheet with nothing to do, it is one column as before.
///
/// The doing keeps its place in the view tree in every layout, so a fold keeps the note's focus, an open picker and
/// photos still loading. With the keyboard up there is no room below the fold: the doing alone shows above the
/// keyboard, where it was, and the reading comes back when the keyboard goes.
struct ReadAndActPanes<Reading: View, Acting: View, Column: ViewModifier>: View {
    private let alignment: HorizontalAlignment
    private let spacing: CGFloat
    private let splits: Bool
    private let flatTitle: ToolbarTitleDisplayMode
    private let column: Column
    private let reading: Reading
    private let acting: Acting
    @State private var foldedPanes = FoldedPanes.flat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - alignment, spacing: how both parts line up in the column, and the space between their views.
    ///   - splits: `false` when there is nothing to do, so nothing is worth a pane of its own.
    ///   - flatTitle: the sheet's title on a flat display. Split, it is inline: a large title collapses as a pane
    ///     scrolls and would move the fold's place in both.
    ///   - column: the column's width, padding and text alignment, applied to each pane's column.
    init(
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat = DSSpacing.m,
        splits: Bool = true,
        flatTitle: ToolbarTitleDisplayMode = .automatic,
        column: Column,
        @ViewBuilder reading: () -> Reading,
        @ViewBuilder acting: () -> Acting
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.splits = splits
        self.flatTitle = flatTitle
        self.column = column
        self.reading = reading()
        self.acting = acting()
    }

    var body: some View {
        let panes = splits ? foldedPanes : .flat
        panes.layout {
            if panes != .flat {
                ScrollView {
                    VStack(alignment: alignment, spacing: spacing) { reading }
                        .modifier(column)
                }
                .hiddenUpperPane(panes)
            }
            ScrollView {
                VStack(alignment: alignment, spacing: spacing) {
                    if panes == .flat { reading }
                    acting
                }
                .modifier(column)
                // Clear of the fold.
                .padding(.top, panes == .flat ? 0 : DSSpacing.m)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(FoldedPanesReader(panes: $foldedPanes))
        .toolbarTitleDisplayMode(panes == .flat ? flatTitle : .inline)
        .animation(reduceMotion ? nil : .smooth, value: panes)
    }
}
