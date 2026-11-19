import DesignSystem
import HeroArt
import SwiftUI

/// The dad's skin tone and a grid of heroes to choose from.
struct HeroPicker: View {
    let content: HeroPickerContent
    @Binding var skinTone: SkinToneChoice
    let selectedHeroID: String?
    let onSelect: (String) -> Void
    /// Grows with the text, so large sizes get one hero per row instead of names broken mid-word. Never below 150,
    /// which the 120pt avatar needs.
    @ScaledMetric(relativeTo: .headline) private var cardMinimumWidth: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            Text(content.subtitle)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
            AdaptiveStack(spacing: DSSpacing.s) {
                Text(content.skinToneLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SkinTonePicker(selection: $skinTone, names: content.skinToneNames)
            }
            .font(DSFont.body)
            .foregroundStyle(DSColor.textPrimary)
            .padding(.horizontal, DSSpacing.m)
            .frame(minHeight: 52)
            .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
            let columns = [GridItem(.adaptive(minimum: max(150, cardMinimumWidth)), spacing: DSSpacing.m)]
            LazyVGrid(columns: columns, spacing: DSSpacing.m) {
                ForEach(content.heroes) { hero in
                    HeroOptionCard(hero: hero, skin: skinTone.avatarSkin, isSelected: hero.id == selectedHeroID) {
                        onSelect(hero.id)
                    }
                }
            }
        }
    }
}

private struct HeroOptionCard: View {
    let hero: HeroOption
    let skin: AvatarSkin
    let isSelected: Bool
    let onSelect: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: DSSpacing.s) {
                HeroAvatar(style: hero.look.avatarStyle, size: 120, cheerTrigger: isSelected ? 1 : 0, skin: skin)
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
                    Image(systemName: "checkmark.circle.fill")
                        .font(DSFont.symbol)
                        .foregroundStyle(hero.look.avatarStyle.tint)
                        .padding(DSSpacing.s)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(shape)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
