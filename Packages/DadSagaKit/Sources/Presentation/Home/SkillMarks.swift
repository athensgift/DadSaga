import DesignSystem
import SwiftUI

/// How a skill's mark is drawn for how much the skill has grown (ADR-0059 §2). Plain values, so tests can read them.
///
/// The symbol always sits inside its circle with room around it: 44% of the circle before the skill has grown, nearing
/// 60%. Growth shows mostly behind it: a wash of the tint that deepens and a glow that spreads, both inside the
/// circle. The look follows the square root of the growth, so the first cards show most and later ones still show,
/// without an end. Nothing fills up and nothing is ever grey or empty: a mark that hasn't grown is drawn in full
/// colour, only quieter. The circle itself never changes size.
public struct SkillMarkLook: Equatable, Sendable {
    /// The symbol's share of the circle before the skill has grown.
    public static let restingSymbolScale = 0.44
    /// The share of the circle the symbol nears and never reaches. A square of 60% has its corners well inside the
    /// circle, so a wide symbol (the heart) and a tall one (the hourglass) both keep room around them.
    public static let largestSymbolScale = 0.6
    /// The wash's ceiling: the tint's own wash, so the symbol keeps its contrast (ADR-0032).
    public static let maxWashOpacity = DSTint.washOpacity

    /// From 0 up to, never reaching, 1.
    public let growth: Double

    public init(growth: Double) {
        self.growth = min(max(growth, 0), 1)
    }

    /// What the eye is shown of the growth: one card of 20 XP, about 12% grown, already shows as a third.
    private var shown: Double { growth.squareRoot() }
    /// The symbol's side as a share of the circle's.
    public var symbolScale: Double {
        Self.restingSymbolScale + (Self.largestSymbolScale - Self.restingSymbolScale) * shown
    }
    /// Some wash from the start, so a new mark looks new, not missing.
    public var washOpacity: Double { Self.maxWashOpacity * (0.3 + 0.7 * shown) }
    /// The opacity of each of the glow's two layers.
    public var glowOpacity: Double { 0.7 * shown }
    /// The glow's radius as a share of the circle's side: none before the skill has grown, then wide enough from
    /// the first card to show around the symbol.
    public var glowRadius: Double { growth == 0 ? 0 : 0.06 + 0.16 * shown }
}

/// The dad's four skills under his title, each its symbol with its name under it (ADR-0059 §2). All four side by side
/// when they fit, else two by two, else one column with each symbol beside its name. One VoiceOver element: "Your
/// skills", then the four names, never a number.
struct SkillMarks: View {
    let model: SkillMarksModel
    /// How many times each mark has bounced (`HomeViewModel.skillBounces`).
    let bounces: [String: Int]
    /// Gets the width the four need side by side, so home can make room for them.
    var onRowWidth: (CGFloat) -> Void = { _ in }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row
            Grid(horizontalSpacing: DSSpacing.l, verticalSpacing: DSSpacing.s) {
                ForEach(rows, id: \.first?.id) { row in
                    GridRow {
                        ForEach(row) { mark(for: $0, nameBeside: false) }
                    }
                }
            }
            VStack(alignment: .leading, spacing: DSSpacing.s) {
                ForEach(model.marks) { mark(for: $0, nameBeside: true) }
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            row.fixedSize().hidden()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { onRowWidth($0) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(model.label))
        .accessibilityValue(Text(model.value))
    }

    /// All four side by side, each name under its symbol.
    private var row: some View {
        HStack(alignment: .top, spacing: DSSpacing.s) {
            ForEach(model.marks) { mark(for: $0, nameBeside: false) }
        }
    }

    /// Two by two, in the marks' order.
    private var rows: [[SkillMarkModel]] {
        stride(from: 0, to: model.marks.count, by: 2).map { Array(model.marks[$0..<min($0 + 2, model.marks.count)]) }
    }

    private func mark(for mark: SkillMarkModel, nameBeside: Bool) -> some View {
        let layout = nameBeside
            ? AnyLayout(HStackLayout(spacing: DSSpacing.s))
            : AnyLayout(VStackLayout(spacing: DSSpacing.xs))
        return layout {
            SkillMarkSymbol(mark: mark, bounce: bounces[mark.id] ?? 0)
            Text(mark.name)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(nameBeside ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One skill's symbol in its circle, drawn by `SkillMarkLook`.
private struct SkillMarkSymbol: View {
    let mark: SkillMarkModel
    let bounce: Int
    /// 36 pt at the default text size, growing with the headline style, never with the skill.
    @ScaledMetric(relativeTo: .headline) private var side: CGFloat = 36
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let look = SkillMarkLook(growth: mark.growth)
        Image(systemName: mark.symbol)
            .resizable()
            .scaledToFit()
            .foregroundStyle(DSColor.accent)
            .frame(width: side * look.symbolScale, height: side * look.symbolScale)
            // Twice at the same radius: a glow dense enough to see on a light background, and still soft at the
            // symbol's edge.
            .shadow(color: DSColor.accent.opacity(look.glowOpacity), radius: side * look.glowRadius)
            .shadow(color: DSColor.accent.opacity(look.glowOpacity), radius: side * look.glowRadius)
            // Once each time the skill's card is celebrated, as its badge goes; never with Reduce Motion, and not when
            // the setting changes either.
            .symbolEffect(.bounce, value: bounce)
            .symbolEffectsRemoved(reduceMotion)
            .frame(width: side, height: side)
            .background(DSColor.accent.opacity(look.washOpacity))
            // The glow stays in the circle with the symbol: a clean edge at every growth.
            .clipShape(Circle())
            // Quieter at once after an undo or a deletion, and brighter with no show: the bounce says it grew.
            .animation(nil, value: mark.growth)
    }
}
