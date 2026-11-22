import DesignSystem
import SwiftUI

/// How home lays out the hero and today's adventure (ADR-0011, ADR-0043).
enum HomeArrangement: Equatable, Sendable {
    /// One scrolling column: iPhones in portrait, the iPhone Duo's cover display.
    case column
    /// Two columns side by side: wide with the fold running down (iPhone Duo on its side, flat or half-open like a
    /// book, where it runs between them), or wide with no fold at all.
    case columns
    /// The hero above the fold and the adventure below it: the iPhone Duo held upright, half-open like a laptop or
    /// open flat, where the fold has no thickness (ADR-0045).
    case stacked(HorizontalFold)

    /// - Parameters:
    ///   - width: the width home has.
    ///   - fold: the fold that runs across home while the device is half-open, if any.
    ///   - flatFold: where the fold runs across home while the device lies flat, if it does. It splits home only
    ///     where there would otherwise be two columns.
    static func make(width: CGFloat, fold: HorizontalFold?, flatFold: HorizontalFold?) -> HomeArrangement {
        if let fold { return .stacked(fold) }
        guard width >= twoColumnWidth else { return .column }
        return flatFold.map(HomeArrangement.stacked) ?? .columns
    }

    /// Two panes that scroll separately.
    var hasPanes: Bool { self != .column }

    var fold: HorizontalFold? {
        if case .stacked(let fold) = self { fold } else { nil }
    }

    /// The tallest the hero is drawn. Above a fold, standing beside his level, he takes what the pane's header
    /// leaves of the upper pane, so the stage reaches down to the fold. Stacked over his level (the accessibility text
    /// sizes) he is no taller than in one column, so the level follows him and the pane scrolls.
    /// - Parameters:
    ///   - headerHeight: the height the pane's title is drawn at.
    ///   - besideTitle: whether the hero stands beside his lines and title rather than above them.
    func maxHeroSize(headerHeight: CGFloat, besideTitle: Bool) -> CGFloat {
        switch self {
        case .column: Self.columnHero
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
