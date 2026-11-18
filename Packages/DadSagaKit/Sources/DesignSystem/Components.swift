import SwiftUI

/// Horizontal XP progress bar.
public struct XPBar: View {
    /// What VoiceOver reads, in the dad's language, e.g. "Επίπεδο 3".
    let label: String
    let fraction: Double

    public init(label: String, fraction: Double) {
        self.label = label
        self.fraction = min(max(fraction, 0), 1)
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(DSColor.xp.opacity(0.18))
                Capsule().fill(DSColor.xp.gradient).frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(fraction * 100))%")
    }
}

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
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
    }
}

/// A row for a quest, boss fight or legendary moment: icon tile, text, and a reward or tag.
public struct QuestCard: View {
    public enum Style: Sendable {
        case quest, boss, legendary

        public var tint: Color {
            switch self {
            case .quest: DSColor.accent
            case .boss: DSColor.boss
            case .legendary: DSColor.legendary
            }
        }
    }

    let title: String
    let subtitle: String
    let badge: String
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
        badge: String,
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
        HStack(alignment: .top, spacing: DSSpacing.m) {
            Image(systemName: symbol)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(DSColor.heroHighlight)
                .frame(width: 36, height: 36)
                .background(style.tint.gradient, in: RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.s) {
                    Text(title)
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)
                    Spacer(minLength: 0)
                    Text(badge)
                        .font(DSFont.caption)
                        .foregroundStyle(style.tint)
                        .lineLimit(1)
                        .fixedSize()
                }
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

#Preview("Components") {
    VStack(spacing: DSSpacing.m) {
        XPBar(label: "Επίπεδο 3", fraction: 0.4)
        QuestCard(title: "Νυχτερινή βάρδια", subtitle: "Ανάλαβε μια ολόκληρη νυχτερινή βάρδια.",
                  badge: "+30 XP", symbol: "hourglass", footnote: "Το έκανες 1 φορά",
                  hint: "Ο καναπές είναι παγίδα")
        QuestCard(title: "Ο Πρώτος Πυρετός", subtitle: "Δεν είσαι μόνος.", badge: "BOSS", symbol: "flame.fill", style: .boss)
        PrimaryButton("Συνέχεια") {}
    }
    .padding()
    .background(DSColor.background)
}
