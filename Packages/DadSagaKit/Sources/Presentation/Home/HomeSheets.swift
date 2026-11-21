import DesignSystem
import SwiftUI

/// "Did you do it?" for a quest, with its tip when it has one. No custom background, so the system shows it as a
/// Liquid Glass sheet.
struct QuestSheet: View {
    let quest: QuestDetail
    let errorMessage: String?
    let isCompleting: Bool
    let loader: PhotoLoader
    let onConfirm: (_ note: String, _ photos: PhotoDrafts) -> Void
    let onClose: () -> Void
    @State private var note = ""
    @State private var photos = PhotoDrafts()
    /// The last note's photos, full screen.
    @State private var lastViewer: PhotoViewerContent?
    @State private var isConfirmingDiscard = false

    private var hasUnsavedChanges: Bool { JournalDraft.hasUnsavedChanges(note: note, photos: photos) }

    var body: some View {
        NavigationStack {
            ReadAndActPanes(column: QuestColumn()) { _ in
                RewardPill(text: quest.reward, tint: DSColor.accent)
                Text(quest.title)
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.textPrimary)
                Text(quest.description)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let last = quest.lastJournal {
                    LastJournalView(
                        last: last, entry: quest.title, viewerLabels: quest.journal.photo.viewer, loader: loader,
                        viewer: $lastViewer
                    )
                }
                if let tip = quest.tip {
                    StepsPanel(title: tip.title, steps: tip.steps, tint: DSColor.accent, fill: DSColor.accent.opacity(0.08))
                        .multilineTextAlignment(.leading)
                }
                if let footer = quest.footer {
                    // A safety note: big enough to read at a glance, not fine print.
                    Text(footer)
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textSecondary)
                }
            } acting: { _ in
                JournalSection(
                    labels: quest.journal, note: $note, photos: $photos, entry: quest.title, loader: loader,
                    fill: DSColor.background
                )
                actions
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        if hasUnsavedChanges { isConfirmingDiscard = true } else { onClose() }
                    }
                    // A save under way can't be discarded: it writes everything anyway.
                    .disabled(isCompleting)
                }
            }
            .modifier(UnsavedChangesGuard(
                hasUnsavedChanges: hasUnsavedChanges,
                isAsking: $isConfirmingDiscard,
                labels: quest.journal,
                canSave: !isCompleting && !photos.isLoading,
                onSave: { onConfirm(note, photos) },
                onDiscard: onClose
            ))
        }
        .photoViewer($lastViewer, loader: loader)
    }

    private var actions: some View {
        VStack(spacing: DSSpacing.s) {
            SheetError(message: errorMessage)
            PrimaryButton(quest.confirmTitle) { onConfirm(note, photos) }
                .disabled(isCompleting || photos.isLoading)
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
    let onConfirm: (_ note: String, _ photos: PhotoDrafts) -> Void
    let onClose: () -> Void
    @State private var note = ""
    @State private var photos = PhotoDrafts()
    /// The last note's photos, full screen.
    @State private var lastViewer: PhotoViewerContent?
    @State private var isConfirmingDiscard = false

    private var hasUnsavedChanges: Bool { JournalDraft.hasUnsavedChanges(note: note, photos: photos) }

    var body: some View {
        NavigationStack {
            // A defeated boss has nothing left to do: its guide keeps the whole sheet.
            ReadAndActPanes(alignment: .leading, splits: !boss.isDefeated, column: BossColumn()) { _ in
                RewardPill(text: boss.reward, tint: DSColor.boss)
                Text(boss.intro)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let last = boss.lastJournal {
                    LastJournalView(
                        last: last, entry: boss.title, viewerLabels: boss.journal.photo.viewer, loader: loader,
                        viewer: $lastViewer
                    )
                }
                guide
                // The same safety note as on a quest's tip: readable at a glance.
                Text(boss.disclaimer)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
            } acting: { _ in
                if !boss.isDefeated {
                    JournalSection(
                        labels: boss.journal, note: $note, photos: $photos, entry: boss.title, loader: loader,
                        fill: DSColor.surface
                    )
                }
                actions
            }
            .background(DSColor.background)
            .navigationTitle(boss.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        if hasUnsavedChanges { isConfirmingDiscard = true } else { onClose() }
                    }
                    // A save under way can't be discarded: it writes everything anyway.
                    .disabled(isCompleting)
                }
            }
            .modifier(UnsavedChangesGuard(
                hasUnsavedChanges: hasUnsavedChanges,
                isAsking: $isConfirmingDiscard,
                labels: boss.journal,
                canSave: !isCompleting && !photos.isLoading,
                onSave: { onConfirm(note, photos) },
                onDiscard: onClose
            ))
        }
        .photoViewer($lastViewer, loader: loader)
    }

    private var guide: some View {
        StepsPanel(title: boss.guideTitle, steps: boss.guide, tint: DSColor.boss, fill: DSColor.surface)
    }

    @ViewBuilder private var actions: some View {
        VStack(spacing: DSSpacing.s) {
            SheetError(message: errorMessage)
            if boss.isDefeated {
                Label(boss.defeatedText, systemImage: "rosette")
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.xp)
                    .padding(.vertical, DSSpacing.s)
            } else {
                PrimaryButton(boss.confirmTitle) { onConfirm(note, photos) }
                    .disabled(isCompleting || photos.isLoading)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DSSpacing.s)
    }
}

/// The quest sheet's column: centred, with wide margins.
private struct QuestColumn: ViewModifier {
    func body(content: Content) -> some View {
        content
            .multilineTextAlignment(.center)
            .frame(maxWidth: readableWidth)
            .padding(.horizontal, DSSpacing.l)
            .padding(.bottom, DSSpacing.m)
            .frame(maxWidth: .infinity)
    }
}

/// The boss sheet's column: leading, like the guide it holds.
private struct BossColumn: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: readableWidth, alignment: .leading)
            .padding(DSSpacing.m)
            .frame(maxWidth: .infinity)
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
                        .foregroundStyle(DSColor.onTint)
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
