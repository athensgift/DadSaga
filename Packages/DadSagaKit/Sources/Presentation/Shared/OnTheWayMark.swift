import DesignSystem
import HeroArt
import SwiftUI

/// A child not born yet, beside the hero (ADR-0053 §2): a small heart in a circle, standing on the ground a child would,
/// in a frame the size of a child's. An SF Symbol present since iOS 13; the code-drawn children don't change.
struct OnTheWayMark: View {
    /// The canvas height a child would have here.
    let size: CGFloat

    var body: some View {
        let diameter = size * 0.34
        Image(systemName: "heart.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(DSColor.accent)
            .padding(diameter * 0.26)
            .frame(width: diameter, height: diameter)
            .background(DSColor.surface, in: Circle())
            .overlay { Circle().strokeBorder(DSColor.accent.opacity(0.35), lineWidth: max(1, size * 0.015)) }
            .padding(.bottom, ChildAvatar.groundInset(forSize: size))
            .frame(width: size * ChildAvatar.aspectRatio, height: size, alignment: .bottom)
            .accessibilityAddTraits(.isImage)
    }
}

/// A child as drawn: the code-drawn child, or the mark while they are on the way.
struct CompanionFigure: View {
    let stage: CompanionStage
    let gender: GenderChoice
    let skin: SkinToneChoice
    let size: CGFloat
    var cheerTrigger = 0
    var traits: Set<CompanionTrait> = []

    var body: some View {
        if let avatarStage = stage.avatarStage {
            ChildAvatar(
                stage: avatarStage,
                gender: gender.avatarGender,
                skin: skin.avatarSkin,
                size: size,
                cheerTrigger: cheerTrigger,
                traits: traits.avatarTraits
            )
        } else {
            OnTheWayMark(size: size)
        }
    }
}
