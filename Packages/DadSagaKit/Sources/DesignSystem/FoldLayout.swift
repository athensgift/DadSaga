import SwiftUI

/// A fold that runs across a view, as on an iPhone Duo half-open like a laptop: one pane stands above it, the
/// other lies below it (ADR-0043). In the view's own coordinates.
public struct HorizontalFold: Equatable, Sendable {
    /// Where the pane above the fold ends.
    public let top: CGFloat
    /// Where the pane below the fold starts.
    public let bottom: CGFloat

    public init(top: CGFloat, bottom: CGFloat) {
        self.top = top
        self.bottom = bottom
    }

    /// The fold that runs across a view of this size, or `nil` when none does or when it leaves less than
    /// `minimumAbove` above it (a short sheet) or `minimumBelow` below it (the keyboard over the lower half).
    /// - Parameter divisions: the display's active folds, in the view's coordinates. They may reach past the view.
    public static func across(
        _ size: CGSize, divisions: [CGRect], minimumAbove: CGFloat, minimumBelow: CGFloat
    ) -> HorizontalFold? {
        let bounds = CGRect(origin: .zero, size: size)
        for division in divisions {
            let part = division.intersection(bounds)
            guard !part.isNull, part.width > part.height else { continue }
            guard part.minX <= 0.5, part.maxX >= size.width - 0.5 else { continue }
            guard part.minY >= minimumAbove, size.height - part.maxY >= minimumBelow else { continue }
            return HorizontalFold(top: part.minY, bottom: part.maxY)
        }
        return nil
    }

    /// The folds to look for: the active ones while the device is half-open; otherwise, `whileFlat`, every fold
    /// drawn as the line down its middle. The system reports a fold that lies flat with the hinge's thickness, but
    /// there is nothing to keep clear on a flat display: two panes split there meet at the line (ADR-0045).
    /// - Parameters:
    ///   - active: the folds of a partly open device.
    ///   - all: the folds also while the device lies flat (`.includeInactive`).
    public static func divisions(active: [CGRect], all: [CGRect], whileFlat: Bool) -> [CGRect] {
        guard whileFlat, active.isEmpty else { return active }
        return all.map { region in
            region.width >= region.height
                ? CGRect(x: region.minX, y: region.midY, width: region.width, height: 0)
                : CGRect(x: region.midX, y: region.minY, width: 0, height: region.height)
        }
    }
}

/// Its first view above the fold and its second below it, each as wide as the container; nothing in the fold.
/// It places two views: give it exactly two.
/// Switch to it with `AnyLayout` around the same views, so they keep their state when the device folds.
public struct FoldedStackLayout: Layout {
    private let fold: HorizontalFold

    public init(fold: HorizontalFold) {
        self.fold = fold
    }

    /// The two panes of a container of this size, from its top leading corner.
    public static func paneFrames(in size: CGSize, fold: HorizontalFold) -> (top: CGRect, bottom: CGRect) {
        (
            CGRect(x: 0, y: 0, width: size.width, height: fold.top),
            CGRect(x: 0, y: fold.bottom, width: size.width, height: max(0, size.height - fold.bottom))
        )
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let panes = Self.paneFrames(in: bounds.size, fold: fold)
        for (subview, pane) in zip(subviews, [panes.top, panes.bottom]) {
            subview.place(
                at: CGPoint(x: bounds.minX + pane.midX, y: bounds.minY + pane.midY),
                anchor: .center,
                proposal: ProposedViewSize(pane.size)
            )
        }
    }
}

/// Its second view fills the container and its first gets no room: what a view split at a fold becomes while the
/// keyboard covers the lower half. The first view stays in the tree, so it is the same view when the keyboard goes.
/// Hide it (opacity, accessibility) while this layout is in use.
public struct LowerPaneLayout: Layout {
    public init() {}

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: .zero)
        subviews.dropFirst().first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

/// A view's size and the fold across it, read in one layout pass.
public struct FoldGeometry: Equatable, Sendable {
    public let fold: HorizontalFold?
    public let size: CGSize

    public init(fold: HorizontalFold?, size: CGSize) {
        self.fold = fold
        self.size = size
    }
}

/// How a view that splits at a fold shows its two parts.
public enum FoldedPanes: Equatable, Sendable {
    /// No fold: one column.
    case flat
    /// The first part above the fold, the second below it.
    case split(HorizontalFold)
    /// Split, but the keyboard has taken the room below the fold: only the second part shows, above the keyboard.
    case lowerOnly

    /// What the view shows after its geometry changed.
    ///
    /// Losing the fold has two causes that look alike from inside the view. If the view got shorter at the same
    /// width since it was last split, the keyboard came up: the second part alone stays, where the dad is typing.
    /// Otherwise the device was opened flat or turned.
    public func next(_ geometry: FoldGeometry, sizeWhenSplit: CGSize) -> FoldedPanes {
        if let fold = geometry.fold { return .split(fold) }
        guard self != .flat else { return .flat }
        let isSameWidth = abs(geometry.size.width - sizeWhenSplit.width) < 1
        return isSameWidth && geometry.size.height < sizeWhenSplit.height - 1 ? .lowerOnly : .flat
    }
}

extension View {
    /// Reports the fold that runs across this view, and `nil` when there is none: on a flat display (unless
    /// `whileFlat`), when the fold runs down the view (the device on its side),
    /// or before iOS 27.1. Read it on the view that places the panes,
    /// so the fold is in their coordinates.
    /// - Parameters:
    ///   - minimumAbove, minimumBelow: the least height each pane needs for the view to split at the fold.
    ///   - whileFlat: also report where the fold is while the device lies flat, with no thickness: for a screen
    ///     that keeps the same two panes open and half-open, so folding only opens a gap between them.
    public func onHorizontalFoldChange(
        minimumAbove: CGFloat,
        minimumBelow: CGFloat,
        whileFlat: Bool = false,
        _ action: @escaping (HorizontalFold?) -> Void
    ) -> some View {
        onGeometryChange(for: HorizontalFold?.self) { proxy in
            HorizontalFold.across(
                proxy.size,
                divisions: proxy.divisions(whileFlat: whileFlat),
                minimumAbove: minimumAbove,
                minimumBelow: minimumBelow
            )
        } action: { fold in
            action(fold)
        }
    }

    /// Like `onHorizontalFoldChange`, with the view's size from the same layout pass: for a view that has to tell
    /// the keyboard from the device unfolding (`FoldedPanes`). It also reports a change of size alone.
    public func onFoldGeometryChange(
        minimumAbove: CGFloat, minimumBelow: CGFloat, _ action: @escaping (FoldGeometry) -> Void
    ) -> some View {
        onGeometryChange(for: FoldGeometry.self) { proxy in
            FoldGeometry(
                fold: HorizontalFold.across(
                    proxy.size,
                    divisions: proxy.divisions(whileFlat: false),
                    minimumAbove: minimumAbove,
                    minimumBelow: minimumBelow
                ),
                size: proxy.size
            )
        } action: { geometry in
            action(geometry)
        }
    }
}

extension GeometryProxy {
    /// The display's folds in the view's coordinates: while the device is half-open, or also while it lies flat,
    /// as a line with no thickness. The only availability check of the fold layouts: `macOS` is named because the
    /// package also builds there to run its tests.
    fileprivate func divisions(whileFlat: Bool) -> [CGRect] {
        if #available(iOS 27.1, macOS 27.1, *) {
            HorizontalFold.divisions(
                active: reservedRegions(kind: .division).map(\.frame),
                all: whileFlat ? reservedRegions(kind: .division, options: .includeInactive).map(\.frame) : [],
                whileFlat: whileFlat
            )
        } else {
            []
        }
    }
}
