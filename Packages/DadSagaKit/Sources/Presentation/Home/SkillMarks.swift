import DesignSystem
import SwiftUI

/// How a skill's mark is drawn for how much the skill has grown (ADR-0059 §2). Plain values, so tests can read them.
///
/// The symbol itself fills with the tint from its own bottom up, like liquid. It never changes size, and its circle
/// stays the same pale wash at every growth. Above the level the symbol is drawn pale, as if not coloured in yet.
/// The first card colours its foot clearly, each card after it raises the level a little, and the level never
/// reaches the top: the symbol's head always stays pale, so nothing ever looks finished.
public struct SkillMarkLook: Equatable, Sendable {
    /// The symbol's share of the circle's side, the same at every growth. Even the corners of its square stay
    /// inside the circle.
    public static let symbolScale = 0.56
    /// The level the first card starts from, as a share of the symbol's height: less would colour only the tip of
    /// the heart.
    public static let lowestLevel = 0.25
    /// The level the colour nears and never reaches.
    public static let highestLevel = 0.85
    /// How long the colour takes to rise after a card, in seconds.
    public static let riseDuration = 1.0

    /// From 0 up to, never reaching, 1.
    public let growth: Double

    public init(growth: Double) {
        self.growth = min(max(growth, 0), 1)
    }

    /// How far up the symbol the colour stands, as a share of its height: nothing before the skill has grown, then
    /// straight with the growth from the lowest level towards the highest.
    public var fillLevel: Double {
        growth == 0 ? 0 : Self.lowestLevel + (Self.highestLevel - Self.lowestLevel) * growth
    }
}

/// The dad's four skills under his title, each its symbol with its name under it (ADR-0059 §2). All four side by side
/// when they fit, else two by two, else one column with each symbol beside its name. One VoiceOver element: "Your
/// skills", then the four names, never a number.
struct SkillMarks: View {
    let model: SkillMarksModel
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
            SkillMarkSymbol(mark: mark)
            Text(mark.name)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(nameBeside ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One skill's symbol in its circle, drawn by `SkillMarkLook`: the symbol is pale on its pale circle, and coloured in
/// with the tint from its own bottom up to the skill's level. The coloured part is the tint on its own wash, a pair
/// ADR-0032 holds to 4.5:1; the pale part still shows the whole shape (`DSTint.ghostOpacity`).
private struct SkillMarkSymbol: View {
    let mark: SkillMarkModel
    /// 36 pt at the default text size, growing with the headline style, never with the skill.
    @ScaledMetric(relativeTo: .headline) private var side: CGFloat = 36
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let look = SkillMarkLook(growth: mark.growth)
        symbol
            .foregroundStyle(DSColor.accent.opacity(DSTint.ghostOpacity))
            // Over the symbol itself, so the level is a share of the symbol's own height, whatever its shape.
            .overlay {
                symbol
                    .foregroundStyle(DSColor.accent)
                    .mask {
                        Rectangle()
                            .scaleEffect(x: 1, y: look.fillLevel, anchor: .bottom)
                            // The colour rises gently once the card's celebration has gone, and only then
                            // (`SkillMarkModel.rises`). With Reduce Motion it just changes.
                            .animation(
                                reduceMotion ? nil : .easeInOut(duration: SkillMarkLook.riseDuration), value: mark.rises
                            )
                    }
            }
            .frame(width: side * SkillMarkLook.symbolScale, height: side * SkillMarkLook.symbolScale)
            .frame(width: side, height: side)
            .background(DSColor.accent.opacity(DSTint.washOpacity), in: Circle())
            // Lower at once after an undo or a deletion, with nothing to draw the eye to it.
            .animation(nil, value: mark.growth)
    }

    private var symbol: some View {
        Image(systemName: mark.symbol)
            .resizable()
            .scaledToFit()
    }
}
