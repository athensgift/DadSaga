import DesignSystem
import SwiftUI

/// The dad's level and XP inside it.
struct LevelPanel: View {
    let title: String
    let xpLine: String
    let fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                Text(xpLine)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            XPBar(fraction: fraction)
        }
        .padding(DSSpacing.m)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: fraction)
        .accessibilityElement(children: .combine)
    }
}

/// Whose world and quests are shown, when there are several children.
struct ChildPicker: View {
    let content: HomeContent
    let onSelect: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            Picker(content.familyTitle, selection: Binding(get: { content.selectedChildID }, set: onSelect)) {
                ForEach(content.childTabs) { tab in
                    Text(tab.name).tag(tab.id)
                }
            }
            .pickerStyle(.segmented)
            if let line = content.selectedChildLine {
                Text(line)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .padding(.bottom, DSSpacing.s)
    }
}

/// Floating, transient feedback after a quest or boss: the one place on home where Liquid Glass sits over content.
struct CelebrationBadge: View {
    let celebration: Celebration
    let onFinished: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.xs) {
            Text(celebration.xpText)
                .font(DSFont.title)
                .foregroundStyle(DSColor.xp)
            if let levelUpText = celebration.levelUpText {
                Label(levelUpText, systemImage: "star.fill")
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.legendary)
            }
            if let badgeText = celebration.badgeText {
                Label(badgeText, systemImage: "rosette")
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.boss)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, DSSpacing.l)
        .padding(.vertical, DSSpacing.m)
        .glassEffect(.regular, in: .rect(cornerRadius: DSRadius.card))
        .offset(y: -DSSpacing.l)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
        .task(id: celebration.id) {
            try? await Task.sleep(for: .seconds(2.2))
            onFinished()
        }
    }
}
