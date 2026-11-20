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
    private let reading: (_ isSplit: Bool) -> Reading
    private let acting: (_ isSplit: Bool) -> Acting
    @State private var foldedPanes = FoldedPanes.flat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - alignment, spacing: how both parts line up in the column, and the space between their views.
    ///   - splits: `false` when there is nothing to do, so nothing is worth a pane of its own.
    ///   - flatTitle: the sheet's title on a flat display. Split, it is inline: a large title collapses as a pane
    ///     scrolls and would move the fold's place in both.
    ///   - column: the column's width, padding and text alignment, applied to each pane's column.
    ///   - reading, acting: the two parts; `isSplit` is `true` while each has a pane of its own, for a view that
    ///     belongs to one part when split and to the other in one column (an entry's cover).
    init(
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat = DSSpacing.m,
        splits: Bool = true,
        flatTitle: ToolbarTitleDisplayMode = .automatic,
        column: Column,
        @ViewBuilder reading: @escaping (_ isSplit: Bool) -> Reading,
        @ViewBuilder acting: @escaping (_ isSplit: Bool) -> Acting
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.splits = splits
        self.flatTitle = flatTitle
        self.column = column
        self.reading = reading
        self.acting = acting
    }

    var body: some View {
        let panes = splits ? foldedPanes : .flat
        let isSplit = panes != .flat
        return panes.layout {
            if isSplit {
                ScrollView {
                    VStack(alignment: alignment, spacing: spacing) { reading(true) }
                        .modifier(column)
                }
                .hiddenUpperPane(panes)
            }
            // Split, the doing sits at the bottom of its pane: buttons near the hands, not against the fold.
            BottomAlignedScrollView(alignsBottom: isSplit) {
                VStack(alignment: alignment, spacing: spacing) {
                    if !isSplit { reading(false) }
                    acting(isSplit)
                }
                .modifier(column)
                // Clear of the fold.
                .padding(.top, isSplit ? DSSpacing.m : 0)
                // Clear of the button over the keyboard, which floats over the pane's bottom corner.
                .padding(.bottom, panes == .lowerOnly ? DSSpacing.xl + DSSpacing.l : 0)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(FoldedPanesReader(panes: $foldedPanes))
        .toolbarTitleDisplayMode(panes == .flat ? flatTitle : .inline)
        .animation(reduceMotion ? nil : .smooth, value: panes)
    }
}
