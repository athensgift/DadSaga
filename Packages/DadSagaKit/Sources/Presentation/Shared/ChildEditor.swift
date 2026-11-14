import DesignSystem
import SwiftUI

/// One child's details: name, birth date, gender and skin tone. Used by onboarding and the family screen.
struct ChildEditorCard: View {
    @Binding var child: ChildDraft
    let number: Int
    let labels: ChildEditorLabels
    let latestBirthDate: Date
    /// `nil` hides the remove button (the last remaining child).
    let onRemove: (() -> Void)?
    var onSubmit: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DSSpacing.s) {
                ChildAvatar(
                    stage: child.stage(at: latestBirthDate).avatarStage,
                    gender: child.gender.avatarGender,
                    skin: child.skinTone.avatarSkin,
                    size: 76
                )
                .padding(.vertical, -DSSpacing.s)
                .accessibilityHidden(true)
                Text(verbatim: "\(labels.childTitle) \(number)")
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textSecondary)
                Spacer()
                if let onRemove {
                    Button(labels.removeTitle, systemImage: "minus.circle.fill", role: .destructive, action: onRemove)
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .foregroundStyle(DSColor.boss)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .padding(.leading, DSSpacing.s)
            .padding(.trailing, DSSpacing.xs)
            .padding(.top, DSSpacing.xs)
            .frame(minHeight: 44)
            row {
                TextField(labels.namePlaceholder, text: $child.name)
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .onSubmit(onSubmit)
            }
            row {
                DatePicker(labels.birthDateLabel, selection: $child.birthDate, in: ...latestBirthDate, displayedComponents: .date)
            }
            row {
                Picker(labels.genderLabel, selection: $child.gender) {
                    Text(labels.boy).tag(GenderChoice.boy)
                    Text(labels.girl).tag(GenderChoice.girl)
                }
                .pickerStyle(.segmented)
            }
            row {
                HStack {
                    Text(labels.skinToneLabel)
                    Spacer(minLength: DSSpacing.s)
                    SkinTonePicker(selection: $child.skinTone, names: labels.skinToneNames)
                }
            }
        }
        .font(DSFont.body)
        .foregroundStyle(DSColor.textPrimary)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
    }

    private func row(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: 0) {
            Divider().padding(.leading, DSSpacing.m)
            content()
                .padding(.horizontal, DSSpacing.m)
                .frame(minHeight: 50)
        }
    }
}

/// Five swatches, one per skin tone.
struct SkinTonePicker: View {
    @Binding var selection: SkinToneChoice
    let names: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(SkinToneChoice.allCases.enumerated()), id: \.element) { index, tone in
                let isSelected = tone == selection
                Button {
                    selection = tone
                } label: {
                    Circle()
                        .fill(tone.avatarSkin.base)
                        .frame(width: 26, height: 26)
                        .overlay { Circle().strokeBorder(DSColor.textPrimary.opacity(0.12), lineWidth: 1) }
                        .padding(3)
                        .overlay { Circle().strokeBorder(DSColor.accent, lineWidth: isSelected ? 2.5 : 0) }
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(names.indices.contains(index) ? names[index] : "")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .animation(.easeOut(duration: 0.15), value: selection)
    }
}
