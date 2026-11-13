import DesignSystem
import SwiftUI

/// "Did you do it?" for a quest.
struct QuestSheet: View {
    let quest: QuestDetail
    let errorMessage: String?
    let isCompleting: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.m) {
            RewardPill(text: quest.reward, tint: DSColor.accent)
            Text(quest.title)
                .font(DSFont.title)
                .foregroundStyle(DSColor.textPrimary)
            Text(quest.description)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
            Spacer(minLength: 0)
            if let errorMessage {
                Text(errorMessage)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.boss)
            }
            Button(quest.confirmTitle, action: onConfirm)
                .buttonStyle(.dsPrimary)
                .disabled(isCompleting)
            Button(quest.cancelTitle, action: onCancel)
                .font(DSFont.body)
                .tint(DSColor.textSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(DSSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
    }
}

/// A boss fight: what is coming, a step-by-step survival guide, and "we made it through".
struct BossSheet: View {
    let boss: BossDetail
    let errorMessage: String?
    let isCompleting: Bool
    let onConfirm: () -> Void
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.m) {
                RewardPill(text: boss.reward, tint: DSColor.boss)
                Text(boss.title)
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.textPrimary)
                Text(boss.intro)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(boss.guideTitle)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .padding(.top, DSSpacing.s)
                ForEach(Array(boss.guide.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: DSSpacing.s) {
                        Text(verbatim: "\(index + 1)")
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.heroHighlight)
                            .frame(width: 22, height: 22)
                            .background(DSColor.boss, in: Circle())
                        Text(step)
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(boss.disclaimer)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .padding(.top, DSSpacing.s)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DSSpacing.l)
        }
        .safeAreaInset(edge: .bottom) { actions }
        .background(DSColor.background)
    }

    private var actions: some View {
        VStack(spacing: DSSpacing.s) {
            if let errorMessage {
                Text(errorMessage)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.boss)
            }
            if boss.isDefeated {
                Label(boss.defeatedText, systemImage: "rosette")
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.xp)
                    .padding(.vertical, DSSpacing.s)
            } else {
                Button(boss.confirmTitle, action: onConfirm)
                    .buttonStyle(.dsPrimary)
                    .disabled(isCompleting)
            }
            Button(boss.closeTitle, action: onClose)
                .font(DSFont.body)
                .tint(DSColor.textSecondary)
        }
        .padding(.horizontal, DSSpacing.l)
        .padding(.vertical, DSSpacing.m)
        .background(DSColor.background)
    }
}

private struct RewardPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(DSFont.caption)
            .padding(.horizontal, DSSpacing.s)
            .padding(.vertical, DSSpacing.xs)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}
