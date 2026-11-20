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

extension View {
    /// Reports the fold that runs across this view, and `nil` when there is none: on a flat display, when the fold
    /// runs down the view (half-open like a book), or before iOS 27.1. Read it on the view that places the panes,
    /// so the fold is in their coordinates.
    /// - Parameters:
    ///   - minimumAbove, minimumBelow: the least height each pane needs for the view to split at the fold.
    public func onHorizontalFoldChange(
        minimumAbove: CGFloat, minimumBelow: CGFloat, _ action: @escaping (HorizontalFold?) -> Void
    ) -> some View {
        onGeometryChange(for: HorizontalFold?.self) { proxy in
            HorizontalFold.across(
                proxy.size, divisions: proxy.activeDivisions, minimumAbove: minimumAbove, minimumBelow: minimumBelow
            )
        } action: { fold in
            action(fold)
        }
    }
}

extension GeometryProxy {
    /// The display's folds while the device is half-open, in the view's coordinates. The only availability check
    /// of the fold layouts: `macOS` is named because the package also builds there to run its tests.
    fileprivate var activeDivisions: [CGRect] {
        if #available(iOS 27.1, macOS 27.1, *) {
            reservedRegions(kind: .division).map(\.frame)
        } else {
            []
        }
    }
}
