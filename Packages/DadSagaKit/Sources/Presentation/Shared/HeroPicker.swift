import DesignSystem
import HeroArt
import SwiftUI

/// The dad's skin tone, his look (on "Your hero" only) and a grid of heroes to choose from, drawn with both.
struct HeroPicker: View {
    let content: HeroPickerContent
    @Binding var skinTone: SkinToneChoice
    let appearance: DadAppearanceChoice
    /// `nil` in onboarding, which asks only for the skin tone (ADR-0044 §2).
    var looks: AppearanceSection?
    let selectedHeroID: String?
    let onSelect: (String) -> Void
    /// A row's id and the option chosen in it.
    var onSelectOption: (String, String) -> Void = { _, _ in }
    /// Grows with the text, so large sizes get one hero per row instead of names broken mid-word. Never below 150,
    /// which the 120pt avatar needs.
    @ScaledMetric(relativeTo: .headline) private var cardMinimumWidth: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            Text(content.subtitle)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
            SkinToneRow(label: content.skinToneLabel, selection: $skinTone, names: content.skinToneNames)
            .font(DSFont.body)
            .foregroundStyle(DSColor.textPrimary)
            .padding(.horizontal, DSSpacing.m)
            .frame(minHeight: 52)
            .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
            if let looks {
                looksSection(looks)
            }
            let columns = [GridItem(.adaptive(minimum: max(150, cardMinimumWidth)), spacing: DSSpacing.m)]
            LazyVGrid(columns: columns, spacing: DSSpacing.m) {
                ForEach(content.heroes) { hero in
                    HeroOptionCard(
                        hero: hero,
                        skin: skinTone.avatarSkin,
                        features: appearance.avatarFeatures,
                        isSelected: hero.id == selectedHeroID
                    ) {
                        onSelect(hero.id)
                    }
                }
            }
        }
    }

    private func looksSection(_ looks: AppearanceSection) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            Text(looks.title)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(looks.rows) { row in
                    if row.id != looks.rows.first?.id { Divider() }
                    // Outside a Form a menu picker shows only its value, so the row's name is a label of its own;
                    // LabeledContent reads the two together ("Beard, Full").
                    LabeledContent {
                        // A menu with a label of our own: the system's menu picker measured «Κοντά» a little
                        // short beside the row's name and broke it in two, at any width.
                        Menu {
                            Picker(row.title, selection: optionBinding(row)) {
                                ForEach(row.options) { Text($0.title).tag($0.id) }
                            }
                        } label: {
                            HStack(spacing: DSSpacing.xs) {
                                Text(selectedTitle(row))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(DSFont.caption)
                                    .accessibilityHidden(true)
                            }
                            .lineLimit(1)
                            .fixedSize()
                        }
                        // The menu's own label is only the value: VoiceOver reads the row's name with it.
                        .accessibilityLabel(row.title)
                        .accessibilityValue(selectedTitle(row))
                    } label: {
                        Text(row.title).foregroundStyle(DSColor.textPrimary)
                    }
                    .font(DSFont.body)
                    .frame(minHeight: 52)
                }
            }
            .padding(.horizontal, DSSpacing.m)
            .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        }
    }

    private func selectedTitle(_ row: AppearanceRow) -> String {
        row.options.first { $0.id == row.selectedID }?.title ?? ""
    }

    private func optionBinding(_ row: AppearanceRow) -> Binding<String> {
        Binding(get: { row.selectedID }, set: { onSelectOption(row.id, $0) })
    }
}

private struct HeroOptionCard: View {
    let hero: HeroOption
    let skin: AvatarSkin
    let features: HeroFeatures
    let isSelected: Bool
    let onSelect: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: DSSpacing.s) {
                HeroAvatar(
                    style: hero.look.avatarStyle, size: 120, cheerTrigger: isSelected ? 1 : 0, skin: skin, features: features
                )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                Text(hero.title)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                Text(hero.tagline)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(DSSpacing.m)
            .background(DSColor.surface, in: shape)
            .overlay { shape.strokeBorder(hero.look.avatarStyle.tint, lineWidth: isSelected ? 2.5 : 0) }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    // The accent, not the hero's colour: gold and teal are below 3:1 on the card (ADR-0033).
                    Image(systemName: "checkmark.circle.fill")
                        .font(DSFont.symbol)
                        .foregroundStyle(DSColor.accent)
                        .padding(DSSpacing.s)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(shape)
            .motion(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
