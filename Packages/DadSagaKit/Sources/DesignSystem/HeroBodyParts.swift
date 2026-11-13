import SwiftUI

// The hero's body: legs, torso, arms and head. Coordinates are in `HeroFigure`'s design canvas.

struct HeroLegs: View {
    let style: HeroAvatar.Style

    var body: some View {
        ForEach([-9.0, 9.0], id: \.self) { side in
            RoundedRectangle(cornerRadius: 5)
                .fill(DSColor.heroCloth)
                .frame(width: 13, height: 22)
                .offset(x: side, y: 40)
            if style == .knight {
                Circle()
                    .fill(heroGradient(DSColor.heroSteel, DSColor.heroSteelShade))
                    .frame(width: 9, height: 9)
                    .offset(x: side, y: 38)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(DSColor.heroLeather)
                .frame(width: 17, height: 11)
                .offset(x: side * 1.15, y: 51.5)
            Capsule()
                .fill(DSColor.heroWood)
                .frame(width: 15, height: 4)
                .offset(x: side * 1.05, y: 46.5)
            Capsule()
                .fill(DSColor.heroInk)
                .frame(width: 18, height: 3)
                .offset(x: side * 1.15, y: 56.5)
        }
    }
}

struct HeroTorso: View {
    let style: HeroAvatar.Style
    let breath: CGFloat

    var body: some View {
        ZStack {
            Rectangle()
                .fill(DSColor.heroSkinShade)
                .frame(width: 12, height: 8)
                .offset(y: -6)
            outfit
                .scaleEffect(breath)
        }
    }

    @ViewBuilder private var outfit: some View {
        switch style {
        case .knight: knightArmour
        case .mage: mageRobe
        case .ranger: rangerTunic
        }
    }

    private var knightArmour: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(style.fabric)
                .frame(width: 40, height: 40)
                .offset(y: 14)
            RoundedRectangle(cornerRadius: 9)
                .fill(heroGradient(DSColor.heroSteel, DSColor.heroSteelShade))
                .frame(width: 30, height: 23)
                .offset(y: 8)
            Rectangle().fill(DSColor.boss).frame(width: 3, height: 13).offset(y: 8)
            Rectangle().fill(DSColor.boss).frame(width: 11, height: 3).offset(y: 6)
            belt(width: 40)
        }
    }

    private var mageRobe: some View {
        ZStack {
            HeroTrapezoid(topRatio: 0.74)
                .fill(style.fabric)
                .frame(width: 52, height: 55)
                .offset(y: 21.5)
            Rectangle().fill(style.shade).frame(width: 2, height: 26).offset(y: 36)
            Capsule().fill(DSColor.legendary).frame(width: 52, height: 4).offset(y: 47)
            Capsule().fill(DSColor.legendary).frame(width: 42, height: 5).offset(y: 22)
            Ellipse().fill(style.shade).frame(width: 28, height: 10).offset(y: -2)
            star(size: 6).offset(x: -9, y: 9)
            star(size: 4).offset(x: 10, y: 34)
            star(size: 5).offset(x: -12, y: 38)
        }
    }

    private var rangerTunic: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(style.fabric)
                .frame(width: 40, height: 44)
                .offset(y: 16)
            Capsule()
                .fill(DSColor.heroLeather)
                .frame(width: 4, height: 46)
                .rotationEffect(.degrees(38))
                .offset(y: 10)
            belt(width: 40)
            Ellipse().fill(style.shade).frame(width: 34, height: 12).offset(y: -2)
        }
    }

    private func belt(width: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(DSColor.heroLeather).frame(width: width, height: 5)
            RoundedRectangle(cornerRadius: 2).fill(DSColor.legendary).frame(width: 7, height: 7)
            RoundedRectangle(cornerRadius: 1).fill(DSColor.heroLeather).frame(width: 3, height: 3)
        }
        .offset(y: 25)
    }

    private func star(size: CGFloat) -> some View {
        Image(systemName: "star.fill")
            .font(.system(size: size))
            .foregroundStyle(DSColor.legendary)
    }
}

struct HeroArm: View {
    let style: HeroAvatar.Style
    let angle: Double
    let holdsShield: Bool

    var body: some View {
        VStack(spacing: -3) {
            Capsule()
                .fill(style.fabric)
                .frame(width: 11, height: 22)
            Capsule()
                .fill(style.cuff)
                .frame(width: 12, height: 6)
            Circle()
                .fill(DSColor.heroSkin)
                .frame(width: 10, height: 10)
                .overlay {
                    if holdsShield { HeroShield(tint: style.tint, shade: style.shade) }
                }
        }
        .rotationEffect(.degrees(angle), anchor: .top)
    }
}

/// Things that sit on top of the arms at the shoulders.
struct HeroShoulders: View {
    let style: HeroAvatar.Style

    var body: some View {
        if style == .knight {
            ForEach([-23.0, 23.0], id: \.self) { side in
                Ellipse()
                    .fill(heroGradient(DSColor.heroSteel, DSColor.heroSteelShade))
                    .frame(width: 17, height: 12)
                    .offset(x: side, y: 0)
            }
        }
    }
}

struct HeroHead: View {
    let pose: HeroPose
    let isCheering: Bool

    var body: some View {
        ZStack {
            ForEach([-20.0, 20.0], id: \.self) { side in
                Circle().fill(DSColor.heroSkinShade).frame(width: 8, height: 8).offset(x: side, y: -23)
            }
            Circle().fill(DSColor.heroSkin).frame(width: 40, height: 40)
                .offset(y: -24)
            ForEach([-13.0, 13.0], id: \.self) { side in
                Circle().fill(DSColor.heroBlush.opacity(0.55)).frame(width: 7, height: 7).offset(x: side, y: -22.5)
            }
            beard
            ForEach([-8.0, 8.0], id: \.self) { side in
                eye.offset(x: side, y: -28)
                Capsule()
                    .fill(DSColor.heroBeard)
                    .frame(width: 9, height: 2.5)
                    .rotationEffect(.degrees(side < 0 ? 8 : -8))
                    .offset(x: side, y: isCheering ? -36.5 : -35)
            }
            Ellipse().fill(DSColor.heroSkinShade).frame(width: 6, height: 5).offset(y: -23.5)
        }
    }

    private var eye: some View {
        ZStack {
            Ellipse().fill(DSColor.heroHighlight).frame(width: 9, height: 10)
            Circle().fill(DSColor.heroInk).frame(width: 5.5, height: 5.5).offset(x: pose.look)
            Circle().fill(DSColor.heroHighlight).frame(width: 1.8, height: 1.8).offset(x: pose.look + 1.2, y: -1.2)
        }
        .scaleEffect(x: 1, y: pose.eyeScale)
    }

    private var beard: some View {
        ZStack {
            Circle()
                .fill(heroGradient(DSColor.heroBeard, DSColor.heroBeard.opacity(0.85)))
                .frame(width: 40, height: 40)
                .mask(alignment: .bottom) { Rectangle().frame(height: 18) }
                .offset(y: -24)
            Capsule().fill(DSColor.heroBeard).frame(width: 19, height: 6).offset(y: -20)
            HeroMouth(openness: isCheering ? 1 : 0)
                .fill(DSColor.heroHighlight)
                .overlay {
                    HeroMouth(openness: isCheering ? 1 : 0)
                        .fill(DSColor.heroInk)
                        .scaleEffect(0.62, anchor: .top)
                        .offset(y: 1.2)
                        .opacity(isCheering ? 1 : 0)
                }
                .frame(width: 12, height: 9)
                .offset(y: -12.5)
        }
    }
}
