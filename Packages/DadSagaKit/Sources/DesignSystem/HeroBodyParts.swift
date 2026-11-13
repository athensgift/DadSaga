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

    var body: some View {
        VStack(spacing: -3) {
            Capsule()
                .fill(style.sleeve)
                .frame(width: style.armWidth, height: 22)
            Capsule()
                .fill(style.cuff)
                .frame(width: style.armWidth + 1, height: 6)
            Circle()
                .fill(DSColor.heroSkin)
                .frame(width: 10, height: 10)
                .overlay {
                    if isRight {
                        // Counter-rotated so whatever he holds stays upright while the arm moves.
                        HeroHeldItem(style: style, sway: sway)
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

    var body: some View {
        ZStack {
            ForEach([-20.0, 20.0], id: \.self) { side in
                Circle().fill(DSColor.heroSkinShade).frame(width: 8, height: 8).offset(x: side, y: -23)
            }
            Circle().fill(DSColor.heroSkin).frame(width: 40, height: 40)
                .offset(y: -24)
            hair
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

    private var hair: some View {
        ZStack {
            Ellipse()
                .trim(from: 0.5, to: 1)
                .fill(DSColor.heroBeard)
                .frame(width: 42, height: 26)
                .offset(y: -39)
            ForEach([-19.0, 19.0], id: \.self) { side in
                Capsule().fill(DSColor.heroBeard).frame(width: 5, height: 11).offset(x: side, y: -34)
            }
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
