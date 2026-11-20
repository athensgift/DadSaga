import DesignSystem
import SwiftUI

/// How home lays out the hero and today's adventure (ADR-0011, ADR-0043).
enum HomeArrangement: Equatable, Sendable {
    /// One scrolling column: iPhones in portrait, the iPhone Duo's cover display.
    case column
    /// Two columns side by side: wide and flat, or half-open like a book, where the fold runs between them.
    case columns
    /// The hero above the fold and the adventure below it: half-open like a laptop.
    case stacked(HorizontalFold)

    /// - Parameters:
    ///   - width: the width home has.
    ///   - fold: the fold that runs across home, if any.
    static func make(width: CGFloat, fold: HorizontalFold?) -> HomeArrangement {
        if let fold { return .stacked(fold) }
        return width >= twoColumnWidth ? .columns : .column
    }

    /// Two panes that scroll separately.
    var hasPanes: Bool { self != .column }

    var fold: HorizontalFold? {
        if case .stacked(let fold) = self { fold } else { nil }
    }

    /// The tallest the hero is drawn. Above a fold he stands beside his level, in what the header leaves of the
    /// upper pane.
    var maxHeroSize: CGFloat {
        switch self {
        case .column: 210
        case .columns: Self.widestHero
        case .stacked(let fold): min(Self.widestHero, max(120, fold.top - Self.headerAndPadding))
        }
    }

    private static let widestHero: CGFloat = 260
    /// The pane's header, its padding and the space above the stage.
    private static let headerAndPadding: CGFloat = 180
}
