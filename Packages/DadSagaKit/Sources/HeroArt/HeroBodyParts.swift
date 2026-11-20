import DesignSystem
import SwiftUI

// The parts every dad shares: legs, arms and head. Coordinates are in `HeroFigure`'s design canvas.

struct HeroLegs: View {
    let style: HeroAvatar.Style

    var body: some View {
        ForEach([-9.0, 9.0], id: \.self) { side in
            RoundedRectangle(cornerRadius: 5)
                .fill(style.trousers)
                .frame(width: 13, height: 22)
                .offset(x: side, y: 40)
            RoundedRectangle(cornerRadius: 4)
                .fill(style.shoes)
                .frame(width: 17, height: 11)
                .offset(x: side * 1.15, y: 51.5)
            Capsule()
                .fill(style.cuff)
                .frame(width: 15, height: 4)
                .offset(x: side * 1.05, y: 46.5)
            Capsule()
                .fill(DSColor.heroInk)
                .frame(width: 18, height: 3)
                .offset(x: side * 1.15, y: 56.5)
        }
    }
}

struct HeroArm: View {
    let style: HeroAvatar.Style
    let isRight: Bool
    let angle: Double
    let sway: Double
    @Environment(\.avatarSkin) private var skin
    @Environment(\.heroEquipment) private var equipment

    var body: some View {
        VStack(spacing: -3) {
            Capsule()
                .fill(style.sleeve(skin))
                .frame(width: style.armWidth, height: 22)
            Capsule()
                .fill(style.cuff)
                .frame(width: style.armWidth + 1, height: 6)
            Circle()
                .fill(skin.base)
                .frame(width: 10, height: 10)
                .overlay {
                    // Counter-rotated so whatever he holds stays upright while the arm moves.
                    if isRight {
                        HeroHeldItem(style: style, sway: sway)
                            .rotationEffect(.degrees(-angle))
                    } else if let item = equipment.item(in: .leftHand) {
                        HeroLeftHandItem(item: item, glow: 0.5 + sway / 8)
                            .rotationEffect(.degrees(-angle))
                    }
                }
        }
        .rotationEffect(.degrees(angle), anchor: .top)
    }
}

struct HeroHead: View {
    let pose: HeroPose
    let isCheering: Bool
    /// What the dad wears over his eyes once his archetype has had its say (`Style.wornGlasses`).
    let glasses: HeroAvatar.Features.Glasses
    @Environment(\.avatarSkin) private var skin
    @Environment(\.heroFeatures) private var features

    private var hairColor: Color { features.hairColor.color }

    var body: some View {
        ZStack {
            if features.hair == .long { longHairBehind }
            ForEach([-20.0, 20.0], id: \.self) { side in
                Circle().fill(skin.shade).frame(width: 8, height: 8).offset(x: side, y: -23)
            }
            Circle().fill(skin.base).frame(width: 40, height: 40)
                .offset(y: -24)
            hair
            ForEach([-13.0, 13.0], id: \.self) { side in
                Circle().fill(DSColor.heroBlush.opacity(0.55)).frame(width: 7, height: 7).offset(x: side, y: -22.5)
            }
            beard
            ForEach([-8.0, 8.0], id: \.self) { side in
                eye.offset(x: side, y: -28)
                Capsule()
                    .fill(hairColor)
                    .frame(width: 9, height: 2.5)
                    .rotationEffect(.degrees(side < 0 ? 8 : -8))
                    .offset(x: side, y: isCheering ? -36.5 : -35)
            }
            Ellipse().fill(skin.shade).frame(width: 6, height: 5).offset(y: -23.5)
            if glasses == .round { roundGlasses }
        }
    }

    // MARK: Hair

    @ViewBuilder private var hair: some View {
        switch features.hair {
        case .short, .long: shortHair
        case .curly: curlyHair
        case .shaved: shavedHair
        }
    }

    private var shortHair: some View {
        ZStack {
            Ellipse()
                .trim(from: 0.5, to: 1)
                .fill(hairColor)
                .frame(width: 42, height: 26)
                .offset(y: -39)
            ForEach([-19.0, 19.0], id: \.self) { side in
                Capsule().fill(hairColor).frame(width: 5, height: 11).offset(x: side, y: -34)
            }
        }
    }

    private var curlyHair: some View {
        ZStack {
            ForEach(Array(zip([-15.0, -7.5, 0, 7.5, 15.0], [-37.0, -41.5, -43.0, -41.5, -37.0])), id: \.0) { x, y in
                Circle().fill(hairColor).frame(width: 14, height: 14).offset(x: x, y: y)
            }
            ForEach([-19.5, 19.5], id: \.self) { side in
                Circle().fill(hairColor).frame(width: 7, height: 7).offset(x: side, y: -32)
            }
        }
    }

    /// No hair to speak of: a faint shadow of it and a highlight on the scalp.
    private var shavedHair: some View {
        ZStack {
            Ellipse()
                .trim(from: 0.5, to: 1)
                .fill(hairColor.opacity(0.22))
                .frame(width: 40, height: 22)
                .offset(y: -36)
            Capsule()
                .fill(DSColor.heroHighlight.opacity(0.45))
                .frame(width: 10, height: 3)
                .rotationEffect(.degrees(-18))
                .offset(x: -7, y: -41)
        }
    }

    /// Down to the jaw on both sides of the face, behind the head, so it shows under every hat.
    private var longHairBehind: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(heroGradient(hairColor, hairColor.opacity(0.9)))
            .frame(width: 48, height: 36)
            .offset(y: -28)
    }

    // MARK: Face

    private var eye: some View {
        ZStack {
            Ellipse().fill(DSColor.heroHighlight).frame(width: 9, height: 10)
            Circle().fill(DSColor.heroInk).frame(width: 5.5, height: 5.5).offset(x: pose.look)
            Circle().fill(DSColor.heroHighlight).frame(width: 1.8, height: 1.8).offset(x: pose.look + 1.2, y: -1.2)
        }
        .scaleEffect(x: 1, y: pose.eyeScale)
    }

    private var roundGlasses: some View {
        ZStack {
            ForEach([-8.0, 8.0], id: \.self) { side in
                Circle().stroke(DSColor.heroInk, lineWidth: 1.8).frame(width: 13, height: 13).offset(x: side, y: -28)
            }
            Rectangle().fill(DSColor.heroInk).frame(width: 4, height: 1.8).offset(y: -28)
        }
    }

    private var beard: some View {
        ZStack {
            switch features.beard {
            case .full:
                jaw(height: 18)
                Capsule().fill(hairColor).frame(width: 19, height: 6).offset(y: -20)
            case .short:
                jaw(height: 11)
                Capsule().fill(hairColor).frame(width: 15, height: 4).offset(y: -19.5)
            case .none:
                EmptyView()
            }
            mouth
        }
    }

    private func jaw(height: CGFloat) -> some View {
        Circle()
            .fill(heroGradient(hairColor, hairColor.opacity(0.85)))
            .frame(width: 40, height: 40)
            .mask(alignment: .bottom) { Rectangle().frame(height: height) }
            .offset(y: -24)
    }

    private var mouth: some View {
        HeroMouth(openness: isCheering ? 1 : 0)
            .fill(DSColor.heroHighlight)
            .overlay {
                HeroMouth(openness: isCheering ? 1 : 0)
                    .fill(DSColor.heroInk)
                    .scaleEffect(0.62, anchor: .top)
                    .offset(y: 1.2)
                    .opacity(isCheering ? 1 : 0)
            }
            .overlay {
                // Without a beard behind it, a white smile needs an outline to read on skin.
                if features.beard == .none {
                    HeroMouth(openness: isCheering ? 1 : 0).stroke(DSColor.heroInk, lineWidth: 1)
                }
            }
            .frame(width: 12, height: 9)
            .offset(y: features.beard == .none ? -14 : -12.5)
    }
}
