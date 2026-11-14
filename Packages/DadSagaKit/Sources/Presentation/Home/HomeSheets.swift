import DesignSystem
import SwiftUI

/// "Did you do it?" for a quest. No custom background, so the system shows it as a Liquid Glass sheet.
struct QuestSheet: View {
    let quest: QuestDetail
    let errorMessage: String?
    let isCompleting: Bool
    let onConfirm: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
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
                PrimaryButton(quest.confirmTitle, action: onConfirm)
                    .disabled(isCompleting)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, DSSpacing.l)
            .padding(.bottom, DSSpacing.m)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: onClose)
                }
            }
        }
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.m) {
                    RewardPill(text: boss.reward, tint: DSColor.boss)
                    Text(boss.intro)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    guide
                    Text(boss.disclaimer)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
                .frame(maxWidth: readableWidth, alignment: .leading)
                .padding(DSSpacing.m)
                .frame(maxWidth: .infinity)
            }
            .background(DSColor.background)
            .navigationTitle(boss.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: onClose)
                }
            }
            .safeAreaBar(edge: .bottom) { actions }
        }
    }

    private var guide: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            Text(boss.guideTitle)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(boss.guide.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.m) {
                    Text(verbatim: "\(index + 1)")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.heroHighlight)
                        .frame(width: 24, height: 24)
                        .background(DSColor.boss.gradient, in: Circle())
                    Text(step)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(DSSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
    }

    @ViewBuilder private var actions: some View {
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
                PrimaryButton(boss.confirmTitle, action: onConfirm)
                    .disabled(isCompleting)
            }
        }
        .frame(maxWidth: readableWidth)
        .padding(.horizontal, DSSpacing.l)
        .padding(.vertical, DSSpacing.s)
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
