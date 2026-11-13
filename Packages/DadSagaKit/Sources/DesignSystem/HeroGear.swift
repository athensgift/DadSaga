import SwiftUI

// What makes each class recognisable: headgear, weapon, and what is worn on the back.

struct HeroHeadgear: View {
    let style: HeroAvatar.Style
    let sway: Double

    var body: some View {
        switch style {
        case .knight: knightHelmet
        case .mage: mageHat
        case .ranger: rangerHood
        }
    }

    private var knightHelmet: some View {
        ZStack {
            Capsule()
                .fill(heroGradient(DSColor.boss, DSColor.heroCapeShade))
                .frame(width: 8, height: 20)
                .rotationEffect(.degrees(sway * 2), anchor: .bottom)
                .offset(y: -62)
            dome(heroGradient(DSColor.heroSteel, DSColor.heroSteelShade), width: 45, height: 30)
                .offset(y: -39)
            Rectangle().fill(DSColor.heroSteelShade).frame(width: 2, height: 13).offset(y: -47)
            Capsule().fill(DSColor.heroSteel).frame(width: 48, height: 5).offset(y: -39)
            RoundedRectangle(cornerRadius: 2).fill(DSColor.heroSteel).frame(width: 4, height: 11).offset(y: -33)
            ForEach([-17.0, 17.0], id: \.self) { side in
                Circle().fill(DSColor.heroSteelShade).frame(width: 2.5, height: 2.5).offset(x: side, y: -39)
            }
        }
    }

    private var mageHat: some View {
        ZStack {
            HeroTrapezoid(topRatio: 0)
                .fill(heroGradient(DSColor.heroMage, DSColor.heroMageShade))
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(DSColor.legendary)
                        .offset(y: 4)
                }
                .rotationEffect(.degrees(sway * 0.6), anchor: .bottom)
                .offset(y: -61)
            Capsule().fill(DSColor.legendary).frame(width: 35, height: 4.5).offset(y: -44)
            Ellipse()
                .fill(heroGradient(DSColor.heroMage, DSColor.heroMageShade))
                .frame(width: 58, height: 9)
                .offset(y: -41)
        }
    }

    private var rangerHood: some View {
        ZStack {
            Capsule()
                .fill(heroGradient(DSColor.legendary, DSColor.boss))
                .frame(width: 5, height: 18)
                .rotationEffect(.degrees(28 + sway), anchor: .bottom)
                .offset(x: 13, y: -58)
            dome(heroGradient(DSColor.heroRanger, DSColor.heroRangerShade), width: 46, height: 32)
                .offset(y: -38)
            Capsule().fill(DSColor.heroRangerShade).frame(width: 48, height: 4).offset(y: -38)
            ForEach([-21.5, 21.5], id: \.self) { side in
                Capsule().fill(DSColor.heroRangerShade).frame(width: 6, height: 22).offset(x: side, y: -27)
            }
        }
    }

    /// Top half of an ellipse: a helmet or hood sitting on the head.
    private func dome(_ fill: LinearGradient, width: CGFloat, height: CGFloat) -> some View {
        Ellipse()
            .trim(from: 0.5, to: 1)
            .fill(fill)
            .frame(width: width, height: height)
    }
}

/// Drawn behind the body: capes and the ranger's quiver.
struct HeroBackGear: View {
    let style: HeroAvatar.Style
    let sway: Double

    var body: some View {
        switch style {
        case .knight: cape(heroGradient(DSColor.boss, DSColor.heroCapeShade))
        case .mage: cape(heroGradient(DSColor.heroMageShade, DSColor.heroInk))
        case .ranger: quiver
        }
    }

    private func cape(_ fill: LinearGradient) -> some View {
        HeroTrapezoid(topRatio: 0.62)
            .fill(fill)
            .frame(width: 58, height: 56)
            .rotationEffect(.degrees(sway * 0.7), anchor: .top)
            .offset(y: 24)
    }

    private var quiver: some View {
        VStack(spacing: -2) {
            HStack(spacing: 1) {
                Capsule().fill(DSColor.boss).frame(width: 3, height: 9)
                Capsule().fill(DSColor.legendary).frame(width: 3, height: 11)
                Capsule().fill(DSColor.heroHighlight).frame(width: 3, height: 8)
            }
            RoundedRectangle(cornerRadius: 3)
                .fill(heroGradient(DSColor.heroWood, DSColor.heroLeather))
                .frame(width: 11, height: 30)
        }
        .rotationEffect(.degrees(-28 + sway * 0.4), anchor: .bottom)
        .offset(x: -17, y: -4)
    }
}

struct HeroWeapon: View {
    let style: HeroAvatar.Style
    let pose: HeroPose

    var body: some View {
        switch style {
        case .knight: sword
        case .mage: staff
        case .ranger: bow
        }
    }

    private var sword: some View {
        VStack(spacing: 0) {
            HeroBlade()
                .fill(heroGradient(DSColor.heroHighlight, DSColor.heroSteel))
                .frame(width: 7, height: 40)
                .overlay { Rectangle().fill(DSColor.heroSteelShade).frame(width: 1, height: 28).offset(y: 4) }
                .overlay(alignment: .top) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 9))
                        .foregroundStyle(DSColor.heroHighlight)
                        .opacity(pose.glint)
                        .offset(y: -3)
                }
            Capsule().fill(DSColor.legendary).frame(width: 18, height: 4)
            Rectangle().fill(DSColor.heroLeather).frame(width: 4, height: 9)
            Circle().fill(DSColor.legendary).frame(width: 6, height: 6)
        }
        .rotationEffect(.degrees(10 + pose.sway), anchor: UnitPoint(x: 0.5, y: 0.82))
        .offset(x: 30.5, y: 5.5)
    }

    private var staff: some View {
        VStack(spacing: -3) {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(heroGradient(DSColor.heroHighlight, DSColor.legendary))
                    .frame(width: 11, height: 11)
                    .rotationEffect(.degrees(45))
                    .shadow(color: DSColor.legendary.opacity(0.4 + 0.5 * pose.glow), radius: 4 + 6 * pose.glow)
                ForEach(0..<3, id: \.self) { index in
                    let angle = pose.orbit + Double(index) * 2 * .pi / 3
                    Image(systemName: "sparkle")
                        .font(.system(size: 5))
                        .foregroundStyle(DSColor.legendary)
                        .offset(x: cos(angle) * 12, y: sin(angle) * 7)
                }
            }
            .frame(width: 16, height: 16)
            Capsule().fill(DSColor.legendary).frame(width: 7, height: 4)
            Capsule()
                .fill(heroGradient(DSColor.heroWood, DSColor.heroLeather))
                .frame(width: 4, height: 68)
        }
        .rotationEffect(.degrees(4 + pose.sway * 0.5), anchor: .bottom)
        .offset(x: 32, y: 16)
    }

    private var bow: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(DSColor.heroHighlight.opacity(0.85))
                .frame(width: 1)
            HeroBowLimb()
                .stroke(heroGradient(DSColor.heroWood, DSColor.heroLeather), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            Capsule()
                .fill(DSColor.heroLeather)
                .frame(width: 5.5, height: 11)
                .offset(x: 13)
        }
        .frame(width: 16, height: 60)
        .rotationEffect(.degrees(pose.sway * 0.5), anchor: .center)
        .offset(x: 23, y: 20)
    }
}

struct HeroShield: View {
    let tint: Color
    let shade: Color

    var body: some View {
        HeroShieldShape()
            .fill(heroGradient(tint, shade))
            .overlay { HeroShieldShape().stroke(DSColor.heroSteel, lineWidth: 2.5) }
            .overlay {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(DSColor.legendary)
                    .offset(y: -2)
            }
            .frame(width: 26, height: 30)
    }
}

// MARK: - Shapes

/// A symmetric trapezoid. `topRatio` is the top edge's width relative to the bottom: 0 gives a triangle.
struct HeroTrapezoid: Shape {
    let topRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset = rect.width * (1 - topRatio) / 2
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A sword blade: straight edges ending in a point at the top.
struct HeroBlade: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.width))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.width))
        path.closeSubpath()
        return path
    }
}

/// A heater shield: flat top, sides curving into a point at the bottom.
struct HeroShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY * 0.8))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.maxY * 0.8))
        path.closeSubpath()
        return path
    }
}

/// A bow limb: a curve from top-left to bottom-left that bulges to the right edge.
struct HeroBowLimb: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY),
            control: CGPoint(x: rect.minX + rect.width * 2, y: rect.midY)
        )
        return path
    }
}

/// The mouth as one shape, so it can morph: a thin smile at `openness` 0, a wide open grin at 1.
struct HeroMouth: Shape {
    var openness: CGFloat

    var animatableData: CGFloat {
        get { openness }
        set { openness = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let upperDip = 4 * (1 - openness)
        let lowerDip = 8 + 9 * openness
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.minY + upperDip))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.minY + lowerDip))
        path.closeSubpath()
        return path
    }
}
