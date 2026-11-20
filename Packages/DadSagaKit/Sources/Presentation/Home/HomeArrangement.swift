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
    static func make(width: CGFloat, fold: HorizontalFold?, flatFold: HorizontalFold? = nil) -> HomeArrangement {
        if let fold { return .stacked(fold) }
        guard width >= twoColumnWidth else { return .column }
        return flatFold.map(HomeArrangement.stacked) ?? .columns
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
