import SwiftUI

/// Horizontal XP progress bar with level label.
public struct XPBar: View {
    let level: Int
    let fraction: Double

    public init(level: Int, fraction: Double) {
        self.level = level
        self.fraction = min(max(fraction, 0), 1)
    }

    public var body: some View {
        HStack(spacing: DSSpacing.s) {
            Text("Lv \(level)")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textPrimary)
                .monospacedDigit()
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DSColor.xp.opacity(0.2))
                    Capsule().fill(DSColor.xp).frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level)")
        .accessibilityValue("\(Int(fraction * 100))%")
    }
}

/// Card for a quest, boss fight or legendary moment.
public struct QuestCard: View {
    public enum Style: Sendable {
        case quest, boss, legendary

        var tint: Color {
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
    let style: Style
    let footnote: String?

    /// - Parameter footnote: an optional "done" line under the text, e.g. how many times a quest was completed.
    public init(title: String, subtitle: String, badge: String, style: Style = .quest, footnote: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.style = style
        self.footnote = footnote
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                Spacer(minLength: DSSpacing.s)
                Text(badge)
                    .font(DSFont.caption)
                    .padding(.horizontal, DSSpacing.s)
                    .padding(.vertical, DSSpacing.xs)
                    .background(style.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(style.tint)
            }
            Text(subtitle)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let footnote {
                Label(footnote, systemImage: "checkmark.circle.fill")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.xp)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.m)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.card)
                .strokeBorder(style.tint.opacity(style == .quest ? 0 : 0.6), lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview("Components") {
    VStack(spacing: DSSpacing.m) {
        XPBar(level: 3, fraction: 0.4)
        QuestCard(title: "Νυχτερινή βάρδια", subtitle: "Ανάλαβε μια ολόκληρη νυχτερινή βάρδια.", badge: "+30 XP")
        QuestCard(title: "Ο Πρώτος Πυρετός", subtitle: "Δεν είσαι μόνος.", badge: "BOSS", style: .boss)
        QuestCard(title: "👣 Πρώτα βήματα", subtitle: "11 μηνών", badge: "LEGENDARY", style: .legendary)
    }
    .padding()
    .background(DSColor.background)
}
