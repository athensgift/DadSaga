import DesignSystem
import SwiftUI

/// How home lays out the hero and today's adventure (ADR-0011, ADR-0043, ADR-0061 §1).
enum HomeArrangement: Equatable, Sendable {
    /// One scrolling column: iPhones in portrait, the iPhone Duo's cover display.
    case column
    /// Two columns side by side: 600 pt and wider with no fold across (the iPhone Duo open flat, upright or on its
    /// side, or half-open like a book; large iPhones in landscape).
    case columns
    /// The hero above the fold and the adventure below it: the iPhone Duo half-open like a laptop.
    case stacked(HorizontalFold)

    /// - Parameters:
    ///   - width: the width home has.
    ///   - fold: the fold that runs across home while the device is half-open, if any.
    static func make(width: CGFloat, fold: HorizontalFold?) -> HomeArrangement {
        if let fold { return .stacked(fold) }
        return width >= twoColumnWidth ? .columns : .column
    }

    /// Two panes that scroll separately. They have no navigation bar: the title heads the hero's pane, and above a
    /// fold a bar would move the fold's place (ADR-0043 §3). One column keeps the bar with its large title.
    var hasPanes: Bool { self != .column }

    var fold: HorizontalFold? {
        if case .stacked(let fold) = self { fold } else { nil }
    }

    /// The tallest the hero is drawn. Above a fold, standing beside his level, he takes what the pane's header
    /// leaves of the upper pane, so the stage reaches down to the fold. Stacked over his level (the accessibility text
    /// sizes) he is no taller than in one column, so the level follows him and the pane scrolls. Side by side he
    /// yields what stands under him, so his pane fits without scrolling while he can stay recognisable (ADR-0059 §3).
    /// - Parameters:
    ///   - headerHeight: the height the pane's title is drawn at.
    ///   - besideTitle: whether the hero stands beside his lines and title rather than above them.
    ///   - under: the height of his lines, level and skills under him.
    ///   - paneHeight: his pane's height inside the safe area; 0 until it is known.
    func maxHeroSize(headerHeight: CGFloat, besideTitle: Bool, under: CGFloat = 0, paneHeight: CGFloat = 0) -> CGFloat {
        switch self {
        case .column: Self.columnHero
        case .columns where paneHeight > 0:
            min(
                Self.widestHero,
                max(Self.smallestHero, paneHeight - headerHeight - under - Self.upperPaneSpacing - DSSpacing.m)
            )
        case .columns: Self.widestHero
        case .stacked(let fold):
            min(
                besideTitle ? Self.widestHero : Self.columnHero,
                max(Self.smallestHero, fold.top - headerHeight - Self.upperPaneSpacing)
            )
        }
    }

    /// Padding around each pane's content.
    static let panePadding = DSSpacing.l
    /// Between the hero and his column, when he stands beside it.
    static let besideSpacing = DSSpacing.l
    /// The narrowest the hero's stage gets beside his column.
    static let smallestStageWidth: CGFloat = 160
    /// Space between the hero pane's title and the stage.
    static let headerSpacing = DSSpacing.m
    /// Space above the family, for the hero's glow and a child's cheer.
    static let stageTopPadding = DSSpacing.xl

    private static let columnHero: CGFloat = 210
    private static let widestHero: CGFloat = 260
    /// Smaller than this the hero is hard to recognise: the pane scrolls instead.
    private static let smallestHero: CGFloat = 120
    /// What the upper pane spends besides its title and the hero.
    private static let upperPaneSpacing = panePadding * 2 + headerSpacing + stageTopPadding
}
