import DesignSystem
import Domain
import SwiftUI

/// How a skill's mark is drawn for how much the skill has grown (ADR-0059 §2). Plain values, so tests can read them.
///
/// The symbol is 72% of its circle before the skill has grown and nears the whole circle as it grows; a glow and a
/// wash of the tint behind it grow with it. Nothing fills up and nothing is ever grey or empty: a mark that hasn't
/// grown is drawn in full colour, only smaller and quieter. The circle itself never changes size.
public struct SkillMarkLook: Equatable, Sendable {
    /// The symbol's share of the circle before the skill has grown.
    public static let restingSymbolScale = 0.72
    /// The wash's ceiling: the tint's own wash, so the symbol keeps its contrast (ADR-0032).
    public static let maxWashOpacity = DSTint.washOpacity

    /// From 0 up to, never reaching, 1.
    public let growth: Double

    public init(growth: Double) {
        self.growth = min(max(growth, 0), 1)
    }

    /// The symbol's side as a share of the circle's.
    public var symbolScale: Double { Self.restingSymbolScale + (1 - Self.restingSymbolScale) * growth }
    /// Some wash from the start, so a new mark looks new, not missing.
    public var washOpacity: Double { Self.maxWashOpacity * (0.4 + 0.6 * growth) }
    public var glowOpacity: Double { 0.55 * growth }
    /// The glow's radius as a share of the circle's side.
    public var glowRadius: Double { 0.22 * growth }
}

/// The dad's four skills under his title, each its symbol with its name under it (ADR-0059 §2). All four side by side
/// when they fit, else two by two, else one column with each symbol beside its name. One VoiceOver element: "Your
/// skills", then the four names, never a number.
struct SkillMarks: View {
    let model: SkillMarksModel
    /// How many times each mark has bounced (`HomeViewModel.skillBounces`).
    let bounces: [Skill: Int]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: DSSpacing.m) {
                ForEach(model.marks) { mark(for: $0, nameBeside: false) }
            }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(model.label))
        .accessibilityValue(Text(model.value))
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
            SkillMarkSymbol(mark: mark, bounce: bounces[mark.skill] ?? 0)
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
            .shadow(color: DSColor.accent.opacity(look.glowOpacity), radius: side * look.glowRadius)
            // Once each time the skill's card is celebrated, as its badge goes; never with Reduce Motion.
            .symbolEffect(.bounce, value: reduceMotion ? 0 : bounce)
            .frame(width: side, height: side)
            .background(DSColor.accent.opacity(look.washOpacity), in: Circle())
            // Smaller at once after an undo or a deletion, and larger with no show: the bounce says it grew.
            .animation(nil, value: mark.growth)
    }
}
