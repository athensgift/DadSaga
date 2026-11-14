import SwiftUI

/// The torso, dressed for each dad archetype.
struct HeroTorso: View {
    let style: HeroAvatar.Style
    let breath: CGFloat
    @Environment(\.avatarSkin) private var skin

    var body: some View {
        ZStack {
            Rectangle()
                .fill(skin.shade)
                .frame(width: 12, height: 8)
                .offset(y: -6)
            outfit
                .scaleEffect(breath)
        }
    }

    @ViewBuilder private var outfit: some View {
        switch style {
        case .hero: superSuit
        case .cool: hoodie
        case .strong: tankTop
        case .smart: vestAndTie
        case .chef: chefJacket
        case .fixer: overalls
        }
    }

    /// An original crest (a gold shield with "Μ" for Μπαμπάς), not any existing superhero's logo.
    private var superSuit: some View {
        ZStack {
            base(style.fabric)
            HeroShieldShape()
                .fill(heroGradient(DSColor.legendary, DSColor.boss))
                .overlay { HeroShieldShape().stroke(DSColor.heroHighlight, lineWidth: 1.5) }
                .overlay {
                    Text(verbatim: "Μ")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(DSColor.heroHighlight)
                        .offset(y: -1.5)
                }
                .frame(width: 21, height: 21)
                .offset(y: 8)
            Capsule().fill(DSColor.legendary).frame(width: 40, height: 5).offset(y: 25)
        }
    }

    private var hoodie: some View {
        ZStack {
            base(style.fabric)
            RoundedRectangle(cornerRadius: 4).fill(DSColor.heroMageShade).frame(width: 24, height: 9).offset(y: 23)
            Ellipse().fill(DSColor.heroMageShade).frame(width: 34, height: 12).offset(y: -2)
            ForEach([-4.0, 4.0], id: \.self) { side in
                Capsule().fill(DSColor.heroHighlight).frame(width: 1.5, height: 11).offset(x: side, y: 7)
            }
            // Headphones resting around the neck.
            Ellipse()
                .trim(from: 0, to: 0.5)
                .stroke(DSColor.heroInk, lineWidth: 3)
                .frame(width: 30, height: 12)
                .offset(y: -4)
            ForEach([-15.0, 15.0], id: \.self) { side in
                RoundedRectangle(cornerRadius: 3).fill(DSColor.heroInk).frame(width: 7, height: 10).offset(x: side, y: -3)
            }
        }
    }

    private var tankTop: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(skin.gradient)
                .frame(width: 46, height: 40)
                .offset(y: 14)
            HeroTrapezoid(topRatio: 0.5)
                .fill(style.fabric)
                .frame(width: 42, height: 37)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .offset(y: 15.5)
            Image(systemName: "bolt.fill")
                .font(.system(size: 11))
                .foregroundStyle(DSColor.legendary)
                .offset(y: 14)
        }
    }

    private var vestAndTie: some View {
        ZStack {
            base(style.fabric)
            HeroTrapezoid(topRatio: 0)
                .fill(DSColor.heroChef)
                .frame(width: 18, height: 20)
                .rotationEffect(.degrees(180))
                .offset(y: 4)
            Capsule().fill(DSColor.boss).frame(width: 4.5, height: 15).offset(y: 5)
            Circle().fill(DSColor.heroCapeShade).frame(width: 6, height: 6).offset(y: -3)
            ForEach([19.0, 26.0], id: \.self) { height in
                Circle().fill(DSColor.legendary).frame(width: 2.8, height: 2.8).offset(y: height)
            }
            RoundedRectangle(cornerRadius: 1).fill(DSColor.heroRangerShade).frame(width: 8, height: 7).offset(x: 12, y: 12)
            Capsule().fill(DSColor.accent).frame(width: 2, height: 8).offset(x: 12, y: 8)
        }
    }

    private var chefJacket: some View {
        ZStack {
            base(style.fabric)
                .overlay {
                    RoundedRectangle(cornerRadius: 13).stroke(DSColor.heroChefShade, lineWidth: 1)
                        .frame(width: 40, height: 40)
                        .offset(y: 14)
                }
            ForEach([-6.0, 6.0], id: \.self) { side in
                ForEach([8.0, 16.0, 24.0], id: \.self) { height in
                    Circle().fill(DSColor.heroCloth).frame(width: 2.8, height: 2.8).offset(x: side, y: height)
                }
            }
            HeroTrapezoid(topRatio: 0)
                .fill(heroGradient(DSColor.boss, DSColor.heroCapeShade))
                .frame(width: 18, height: 11)
                .rotationEffect(.degrees(180))
                .offset(y: -0.5)
        }
    }

    private var overalls: some View {
        ZStack {
            base(style.fabric)
            ForEach([-9.0, 9.0], id: \.self) { side in
                Capsule().fill(DSColor.accent).frame(width: 5, height: 18).offset(x: side, y: 2)
                Circle().fill(DSColor.legendary).frame(width: 3.5, height: 3.5).offset(x: side, y: 9)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(heroGradient(DSColor.accent, DSColor.heroKnightShade))
                .frame(width: 30, height: 25)
                .offset(y: 21.5)
            RoundedRectangle(cornerRadius: 2).fill(DSColor.heroKnightShade).frame(width: 13, height: 8).offset(y: 16)
            Rectangle().fill(DSColor.heroLeather).frame(width: 40, height: 5).offset(y: 29)
            RoundedRectangle(cornerRadius: 2).fill(DSColor.heroWood).frame(width: 9, height: 10).offset(x: -13, y: 32)
        }
    }

    private func base(_ fill: LinearGradient) -> some View {
        RoundedRectangle(cornerRadius: 13)
            .fill(fill)
            .frame(width: 40, height: 40)
            .offset(y: 14)
    }
}
