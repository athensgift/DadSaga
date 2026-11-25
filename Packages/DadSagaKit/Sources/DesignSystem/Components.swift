import SwiftUI

/// The app's main call to action: full width, Liquid Glass, tinted with the app's accent colour.
public struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(DSFont.headline)
                .onTintLabel()
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
    }
}

/// A row for a quest, boss fight or legendary moment: icon tile, text, and a reward or tag.
public struct QuestCard: View {
    public enum Style: Sendable {
        case quest, boss

        public var tint: Color {
            switch self {
            case .quest: DSColor.accent
            case .boss: DSColor.boss
            }
        }
    }

    let title: String
    let subtitle: String
    let badge: String?
    let symbol: String
    let style: Style
    let footnote: String?
    let hint: String?
    let skill: String?

    /// - Parameters:
    ///   - symbol: SF Symbol name for the icon tile.
    ///   - footnote: an optional "done" line under the text, e.g. how many times a quest was completed.
    ///   - hint: an optional marker that there is more inside, e.g. the title of a tip.
    ///   - skill: the skill the card feeds, shown with the icon's symbol, e.g. "Care".
    public init(
        title: String,
        subtitle: String,
        badge: String? = nil,
        symbol: String,
        style: Style = .quest,
        footnote: String? = nil,
        hint: String? = nil,
        skill: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.symbol = symbol
        self.style = style
        self.footnote = footnote
        self.hint = hint
        self.skill = skill
    }

    public var body: some View {
        AdaptiveStack(alignment: .top, spacing: DSSpacing.m) {
            IconTile(symbol: symbol, tint: style.tint)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                CardTitle(title, badge: badge, tint: style.tint)
                Text(subtitle)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let skill {
                    Label(skill, systemImage: symbol)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                        .padding(.top, DSSpacing.xs)
                }
                if let hint {
                    Label(hint, systemImage: "lightbulb.fill")
                        .font(DSFont.caption)
                        .foregroundStyle(style.tint)
                        .padding(.top, DSSpacing.xs)
                }
                if let footnote {
                    Label(footnote, systemImage: "checkmark.circle.fill")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.xp)
                        .padding(.top, DSSpacing.xs)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.m)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// A label on a tint fill, such as a prominent button's: `onTint` while enabled. Disabled, the system's dimmed
    /// label on its grey fill, which a fixed colour would override.
    public func onTintLabel() -> some View {
        modifier(OnTintLabel())
    }
}

private struct OnTintLabel: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        if isEnabled {
            content.foregroundStyle(DSColor.onTint)
        } else {
            content
        }
    }
}

/// A card's symbol on a tinted square, growing with the text so the symbol stays inside it. Decorative: hidden from
/// VoiceOver, since the card's text says the same.
public struct IconTile: View {
    let symbol: String
    let tint: Color
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 36

    public init(symbol: String, tint: Color) {
        self.symbol = symbol
        self.tint = tint
    }

    public var body: some View {
        Image(systemName: symbol)
            .font(DSFont.tileSymbol)
            .foregroundStyle(DSColor.onTint)
            .frame(width: size, height: size)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview("Components") {
    VStack(spacing: DSSpacing.m) {
        QuestCard(title: "Νυχτερινή βάρδια", subtitle: "Ανάλαβε μια ολόκληρη νυχτερινή βάρδια.",
                  symbol: "hourglass", footnote: "Το έκανες 1 φορά", hint: "Ο καναπές είναι παγίδα", skill: "Υπομονή")
        QuestCard(title: "Ο Πρώτος Πυρετός", subtitle: "Δεν είσαι μόνος.", badge: "BOSS", symbol: "flame.fill", style: .boss)
        PrimaryButton("Συνέχεια") {}
    }
    .padding()
    .background(DSColor.background)
}
