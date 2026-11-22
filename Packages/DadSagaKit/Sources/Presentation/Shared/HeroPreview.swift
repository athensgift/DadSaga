import DesignSystem
import HeroArt
import SwiftUI

/// The hero alone, without gear, on the glow of his colour: what "Your hero" changes, and who Settings is about.
/// Decoration, hidden from VoiceOver.
struct HeroPreview: View {
    let style: HeroAvatar.Style
    let skin: AvatarSkin
    let features: HeroFeatures

    var body: some View {
        HeroAvatar(style: style, size: 160, skin: skin, features: features)
            .background {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [style.tint.opacity(0.25), .clear], center: .center, startRadius: 10, endRadius: 110
                        )
                    )
                    .frame(width: 220, height: 220)
            }
            .accessibilityHidden(true)
    }
}
