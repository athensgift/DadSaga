import DesignSystem
import SwiftUI

/// "Did you do it?" for a quest, with its tip when it has one. No custom background, so the system shows it as a
/// Liquid Glass sheet.
struct QuestSheet: View {
    let quest: QuestDetail
    let errorMessage: String?
    let isCompleting: Bool
    let loader: PhotoLoader
    let onConfirm: (_ note: String, _ photo: MomentPhotoEdit) -> Void
    let onClose: () -> Void
    @State private var note = ""
    @State private var photo: MomentPhotoEdit = .keep

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.m) {
                    RewardPill(text: quest.reward, tint: DSColor.accent)
                    Text(quest.title)
                        .font(DSFont.title)
                        .foregroundStyle(DSColor.textPrimary)
                    Text(quest.description)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let last = quest.lastJournal {
                        LastJournalView(last: last, loader: loader)
                    }
                    if let tip = quest.tip {
                        StepsPanel(title: tip.title, steps: tip.steps, tint: DSColor.accent, fill: DSColor.accent.opacity(0.08))
                            .multilineTextAlignment(.leading)
                    }
                    if let footer = quest.footer {
                        Text(footer)
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                    JournalSection(labels: quest.journal, note: $note, photo: $photo, loader: loader, fill: DSColor.background)
                    actions
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: readableWidth)
                .padding(.horizontal, DSSpacing.l)
                .padding(.bottom, DSSpacing.m)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: onClose)
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: DSSpacing.s) {
            if let errorMessage {
                Text(errorMessage)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.boss)
            }
            PrimaryButton(quest.confirmTitle) { onConfirm(note, photo) }
                .disabled(isCompleting)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DSSpacing.s)
    }
}

/// A boss fight: what is coming, a step-by-step survival guide, and "we made it through".
struct BossSheet: View {
    let boss: BossDetail
    let errorMessage: String?
    let isCompleting: Bool
    let loader: PhotoLoader
    let onConfirm: (_ note: String, _ photo: MomentPhotoEdit) -> Void
    let onClose: () -> Void
    @State private var note = ""
    @State private var photo: MomentPhotoEdit = .keep

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.m) {
                    RewardPill(text: boss.reward, tint: DSColor.boss)
                    Text(boss.intro)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let last = boss.lastJournal {
                        LastJournalView(last: last, loader: loader)
                    }
                    guide
                    Text(boss.disclaimer)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                    if !boss.isDefeated {
                        JournalSection(labels: boss.journal, note: $note, photo: $photo, loader: loader, fill: DSColor.surface)
                    }
                    actions
                }
                .frame(maxWidth: readableWidth, alignment: .leading)
                .padding(DSSpacing.m)
                .frame(maxWidth: .infinity)
            }
            .background(DSColor.background)
            .navigationTitle(boss.title)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: onClose)
                }
            }
        }
    }

    private var guide: some View {
        StepsPanel(title: boss.guideTitle, steps: boss.guide, tint: DSColor.boss, fill: DSColor.surface)
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
                PrimaryButton(boss.confirmTitle) { onConfirm(note, photo) }
                    .disabled(isCompleting)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DSSpacing.s)
    }
}

/// Numbered "how to" steps on a card: a boss's survival guide or a quest's tip. One look for both.
private struct StepsPanel: View {
    let title: String
    let steps: [String]
    let tint: Color
    /// The panel's background. A tinted fill where the sheet itself is light (the quest sheet), a surface elsewhere.
    let fill: Color
    /// The circle round each step's number grows with the number.
    @ScaledMetric(relativeTo: .caption) private var numberSize: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            Text(title)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.m) {
                    Text(verbatim: "\(index + 1)")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.heroHighlight)
                        .frame(width: numberSize, height: numberSize)
                        .background(tint.gradient, in: Circle())
                    Text(step)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(DSSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
    }
}

private struct RewardPill: View {
    let text: String
    let tint: Color
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// A capsule for one line; a rounded rectangle once the text wraps at the accessibility sizes.
    private var shape: AnyShape {
        dynamicTypeSize.isAccessibilitySize
            ? AnyShape(RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
            : AnyShape(Capsule())
    }

    var body: some View {
        Text(text)
            .font(DSFont.caption)
            .padding(.horizontal, DSSpacing.s)
            .padding(.vertical, DSSpacing.xs)
            .background(tint.opacity(0.15), in: shape)
            .foregroundStyle(tint)
    }
}
