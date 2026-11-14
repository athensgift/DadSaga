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

/// Capture a legendary moment: which first, when it happened, and a few words.
struct MomentSheet: View {
    let capture: MomentCapture
    let errorMessage: String?
    let isSaving: Bool
    let onSave: (_ firstID: String, _ date: Date, _ note: String) -> Void
    let onClose: () -> Void

    @State private var selectedID: String?
    @State private var date: Date
    @State private var note = ""

    init(
        capture: MomentCapture,
        errorMessage: String?,
        isSaving: Bool,
        onSave: @escaping (_ firstID: String, _ date: Date, _ note: String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.capture = capture
        self.errorMessage = errorMessage
        self.isSaving = isSaving
        self.onSave = onSave
        self.onClose = onClose
        _date = State(initialValue: capture.latestDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.m) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: DSSpacing.s)], spacing: DSSpacing.s) {
                        ForEach(capture.options) { option in
                            optionButton(option)
                        }
                    }
                    VStack(spacing: 0) {
                        DatePicker(
                            capture.dateLabel,
                            selection: $date,
                            in: capture.earliestDate...capture.latestDate,
                            displayedComponents: .date
                        )
                        .padding(.horizontal, DSSpacing.m)
                        .frame(minHeight: 50)
                        Divider().padding(.leading, DSSpacing.m)
                        TextField(capture.notePlaceholder, text: $note, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(DSSpacing.m)
                    }
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
                    .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
                    if let errorMessage {
                        Text(errorMessage)
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.boss)
                    }
                }
                .frame(maxWidth: readableWidth)
                .padding(DSSpacing.m)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DSColor.background)
            .navigationTitle(capture.title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        if let selectedID { onSave(selectedID, date, note) }
                    }
                    .disabled(selectedID == nil || isSaving)
                    .accessibilityLabel(capture.saveTitle)
                }
            }
        }
    }

    private func optionButton(_ option: MomentOption) -> some View {
        let isSelected = option.id == selectedID
        let shape = RoundedRectangle(cornerRadius: DSRadius.tile + 4, style: .continuous)
        return Button {
            selectedID = option.id
        } label: {
            VStack(spacing: DSSpacing.xs) {
                Text(option.emoji).font(.system(size: 30))
                Text(option.title)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                Text(option.reward)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.legendary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.s)
            .padding(.horizontal, DSSpacing.xs)
            .background(DSColor.surface, in: shape)
            .overlay { shape.strokeBorder(DSColor.legendary, lineWidth: isSelected ? 2.5 : 0) }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeOut(duration: 0.15), value: isSelected)
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
