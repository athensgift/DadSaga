import DesignSystem
import HeroArt
import SwiftUI

/// One child's details: name, whether they are born yet, birth date, gender and skin tone. Used by onboarding and the
/// family screen. While "Not born yet" is on, only the name is asked (ADR-0053 §1).
struct ChildEditorCard: View {
    @Binding var child: ChildDraft
    let number: Int
    let labels: ChildEditorLabels
    let latestBirthDate: Date
    /// The zone the date picker draws in.
    let timeZone: TimeZone
    /// `nil` hides the remove button (the last remaining child).
    let onRemove: (() -> Void)?
    var onSubmit: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DSSpacing.s) {
                CompanionFigure(
                    stage: child.stage(at: latestBirthDate, timeZone: timeZone),
                    gender: child.gender,
                    skin: child.skinTone,
                    size: 76
                )
                // Its whole height, so the child stands above the line under the row, not on it.
                .accessibilityHidden(true)
                Text(verbatim: "\(labels.childTitle) \(number)")
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textSecondary)
                Spacer()
                if let onRemove {
                    Button(labels.removeTitle, systemImage: "minus.circle.fill", role: .destructive, action: onRemove)
                        .labelStyle(.iconOnly)
                        .font(DSFont.symbol)
                        .foregroundStyle(DSColor.boss)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .padding(.leading, DSSpacing.s)
            .padding(.trailing, DSSpacing.xs)
            .padding(.top, DSSpacing.xs)
            .frame(minHeight: 44)
            row {
                TextField(child.isBorn ? labels.namePlaceholder : labels.unbornNamePlaceholder, text: $child.name)
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .onSubmit(onSubmit)
            }
            row {
                Toggle(labels.notBornLabel, isOn: notBornYet)
            }
            if child.isBorn {
                row {
                    DateRow(label: labels.birthDateLabel, date: birthDate, range: .distantPast...latestBirthDate)
                }
                row {
                    Picker(labels.genderLabel, selection: $child.gender) {
                        Text(labels.boy).tag(GenderChoice.boy)
                        Text(labels.girl).tag(GenderChoice.girl)
                    }
                    .pickerStyle(.segmented)
                }
                row {
                    AdaptiveStack(spacing: DSSpacing.s) {
                        Text(labels.skinToneLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        SkinTonePicker(selection: $child.skinTone, names: labels.skinToneNames)
                    }
                }
            }
        }
        .font(DSFont.body)
        .foregroundStyle(DSColor.textPrimary)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
    }

    /// "Not born yet" is the child not being born.
    private var notBornYet: Binding<Bool> {
        Binding(get: { !child.isBorn }, set: { child.isBorn = !$0 })
    }

    /// The picker shows and sets the stored day; the day itself never goes through a time of day.
    private var birthDate: Binding<Date> {
        Binding(
            get: { child.pickerDate(in: timeZone) },
            set: { child.pickBirthDate($0, in: timeZone) }
        )
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
                        .padding(DSSpacing.xxs)
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
