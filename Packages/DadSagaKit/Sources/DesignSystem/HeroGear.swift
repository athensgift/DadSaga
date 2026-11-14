import SwiftUI

// What makes each dad recognisable: what he wears on his head, on his back and holds in his hand.

struct HeroHeadgear: View {
    let style: HeroAvatar.Style
    let pose: HeroPose
    @Environment(\.avatarSkin) private var skin

    var body: some View {
        switch style {
        case .hero: quiff
        case .cool: capAndShades
        case .strong: headband
        case .smart: glassesAndIdea
        case .chef: toque
        case .fixer: hardHat
        }
    }

    private var quiff: some View {
        Ellipse()
            .fill(skin.hair)
            .frame(width: 20, height: 11)
            .rotationEffect(.degrees(-18 + pose.sway * 0.5))
            .offset(x: 5, y: -51)
    }

    private var capAndShades: some View {
        ZStack {
            dome(heroGradient(DSColor.heroMage, DSColor.heroMageShade), width: 45, height: 30).offset(y: -40)
            Capsule().fill(DSColor.heroMageShade).frame(width: 46, height: 4).offset(y: -40)
            Circle().fill(DSColor.heroHighlight).frame(width: 4, height: 4).offset(y: -54)
            ForEach([-8.0, 8.0], id: \.self) { side in
                RoundedRectangle(cornerRadius: 3.5)
                    .fill(DSColor.heroInk)
                    .frame(width: 13, height: 10)
                    .overlay(alignment: .topLeading) {
                        Capsule()
                            .fill(DSColor.heroHighlight.opacity(0.35 + 0.3 * pose.glow))
                            .frame(width: 5, height: 1.5)
                            .rotationEffect(.degrees(-30))
                            .offset(x: 2, y: 3)
                    }
                    .offset(x: side, y: -28)
            }
            Rectangle().fill(DSColor.heroInk).frame(width: 6, height: 2).offset(y: -30)
        }
    }

    private var headband: some View {
        ZStack {
            ForEach([-12.0, 14.0], id: \.self) { tilt in
                Capsule()
                    .fill(DSColor.legendary)
                    .frame(width: 4, height: 13)
                    .rotationEffect(.degrees(tilt + pose.sway * 2), anchor: .top)
                    .offset(x: -22, y: -33)
            }
            Capsule().fill(DSColor.legendary).frame(width: 44, height: 6).offset(y: -39)
        }
    }

    private var glassesAndIdea: some View {
        ZStack {
            ForEach([-8.0, 8.0], id: \.self) { side in
                Circle().stroke(DSColor.heroInk, lineWidth: 1.8).frame(width: 13, height: 13).offset(x: side, y: -28)
            }
            Rectangle().fill(DSColor.heroInk).frame(width: 4, height: 1.8).offset(y: -28)
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 15))
                .foregroundStyle(DSColor.legendary)
                .opacity(0.35 + 0.65 * pose.glow)
                .shadow(color: DSColor.legendary.opacity(0.8 * pose.glow), radius: 6 * pose.glow)
                .offset(y: -66)
        }
    }

    private var toque: some View {
        ZStack {
            ForEach([-11.0, 0.0, 11.0], id: \.self) { side in
                Circle()
                    .fill(heroGradient(DSColor.heroChef, DSColor.heroChefShade))
                    .frame(width: 19, height: 19)
                    .offset(x: side, y: side == 0 ? -61 : -57)
            }
            RoundedRectangle(cornerRadius: 3)
                .fill(heroGradient(DSColor.heroChef, DSColor.heroChefShade))
                .overlay { RoundedRectangle(cornerRadius: 3).stroke(DSColor.heroChefShade, lineWidth: 1) }
                .frame(width: 36, height: 13)
                .offset(y: -45)
        }
        .rotationEffect(.degrees(pose.sway * 0.4), anchor: .bottom)
    }

    private var hardHat: some View {
        ZStack {
            dome(heroGradient(DSColor.legendary, DSColor.boss), width: 46, height: 34).offset(y: -40)
            RoundedRectangle(cornerRadius: 2).fill(DSColor.heroHighlight.opacity(0.45)).frame(width: 5, height: 14).offset(y: -49)
            Capsule().fill(DSColor.legendary).frame(width: 53, height: 5).offset(y: -39.5)
        }
    }

    /// Top half of an ellipse: a cap or helmet sitting on the head.
    private func dome(_ fill: LinearGradient, width: CGFloat, height: CGFloat) -> some View {
        Ellipse()
            .trim(from: 0.5, to: 1)
            .fill(fill)
            .frame(width: width, height: height)
    }
}

/// Drawn behind the body. Only Super Dad wears a cape.
struct HeroBackGear: View {
    let style: HeroAvatar.Style
    let sway: Double

    var body: some View {
        if style == .hero {
            HeroTrapezoid(topRatio: 0.55)
                .fill(heroGradient(DSColor.legendary, DSColor.boss))
                .frame(width: 62, height: 58)
                .rotationEffect(.degrees(sway * 1.4), anchor: .top)
                .offset(y: 25)
        }
    }
}

/// What the dad holds in his right hand, laid out around the hand's centre.
struct HeroHeldItem: View {
    let style: HeroAvatar.Style
    let sway: Double

    var body: some View {
        ZStack { item }
            .frame(width: 10, height: 10)
    }

    @ViewBuilder private var item: some View {
        switch style {
        case .hero: EmptyView()
        case .cool: skateboard
        case .strong: dumbbell
        case .smart: book
        case .chef: spatula
        case .fixer: wrench
        }
    }

    private var skateboard: some View {
        ZStack {
            ForEach([-17.0, 17.0], id: \.self) { height in
                Circle().fill(DSColor.heroInk).frame(width: 6, height: 6).offset(x: 6, y: height)
            }
            Capsule().fill(heroGradient(DSColor.heroWood, DSColor.heroLeather)).frame(width: 10, height: 50)
            Capsule().fill(DSColor.legendary).frame(width: 2.5, height: 34)
        }
        .rotationEffect(.degrees(4 + sway * 0.3), anchor: .bottom)
        .offset(x: 5, y: 7)
    }

    private var dumbbell: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2).fill(DSColor.heroInk).frame(width: 7, height: 15)
            Rectangle().fill(DSColor.heroSteel).frame(width: 12, height: 4)
            RoundedRectangle(cornerRadius: 2).fill(DSColor.heroInk).frame(width: 7, height: 15)
        }
    }

    private var book: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(heroGradient(DSColor.accent, DSColor.heroKnightShade))
            .frame(width: 16, height: 20)
            .overlay(alignment: .trailing) {
                Rectangle().fill(DSColor.heroChef).frame(width: 2.5, height: 17).padding(.trailing, 1)
            }
            .overlay { Capsule().fill(DSColor.legendary).frame(width: 7, height: 2).offset(x: -1.5, y: -4) }
            .rotationEffect(.degrees(sway * 0.5))
            .offset(x: 3, y: 3)
    }

    private var spatula: some View {
        VStack(spacing: -1) {
            RoundedRectangle(cornerRadius: 2)
                .fill(heroGradient(DSColor.heroSteel, DSColor.heroSteelShade))
                .frame(width: 12, height: 14)
                .overlay {
                    HStack(spacing: 2.5) {
                        ForEach(0..<2, id: \.self) { _ in
                            Capsule().fill(DSColor.heroInk.opacity(0.35)).frame(width: 1.5, height: 8)
                        }
                    }
                }
            Capsule().fill(DSColor.heroWood).frame(width: 3.5, height: 26)
        }
        .rotationEffect(.degrees(8 + sway * 1.5), anchor: .bottom)
        .offset(y: -14)
    }

    private var wrench: some View {
        VStack(spacing: -3) {
            Circle()
                .fill(heroGradient(DSColor.heroSteel, DSColor.heroSteelShade))
                .frame(width: 14, height: 14)
                .overlay(alignment: .top) { Rectangle().fill(DSColor.heroInk.opacity(0.55)).frame(width: 5, height: 7) }
            Capsule()
                .fill(heroGradient(DSColor.heroSteel, DSColor.heroSteelShade))
                .frame(width: 5, height: 26)
        }
        .rotationEffect(.degrees(8 + sway * 1.5), anchor: .bottom)
        .offset(y: -14)
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

/// A crest: flat top, sides curving into a point at the bottom.
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
