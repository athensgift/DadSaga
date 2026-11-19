import DesignSystem
import SwiftUI

// MARK: - Item art

/// One item drawn centred on its own small canvas (design units, like `HeroFigure`). The same drawing serves the
/// avatar, simplified and outlined, and the wardrobe icon, with extra detail.
struct HeroItemArt: View {
    let item: HeroItem
    /// Adds the small details that only read at icon size: stitching, letters, buckles, highlights.
    var detailed = false

    /// The canvas every item fits in, so icons line up.
    static let canvas = CGSize(width: 24, height: 24)

    var body: some View {
        switch item {
        case .burpCloth, .burpClothGold: burpCloth(isGold: item == .burpClothGold)
        case .mug: mug
        case .thermos: thermos
        case .duck: duck
        case .blocks: blocks
        case .diaperBag, .megaBag: bag(isMega: item == .megaBag)
        }
    }

    private var ink: Color { DSColor.heroInk.opacity(0.45) }

    private func burpCloth(isGold: Bool) -> some View {
        let trim = isGold ? DSColor.legendary : DSColor.accent.opacity(0.6)
        return ZStack {
            if isGold {
                // Fringe on both ends: the legendary cloth has a different outline, not just a different colour.
                ForEach([-1.0, 1.0], id: \.self) { side in
                    ForEach([-2.6, 0, 2.6], id: \.self) { row in
                        Capsule().fill(DSColor.legendary).frame(width: 3, height: 1.3).offset(x: side * 9, y: row)
                    }
                }
            }
            RoundedRectangle(cornerRadius: 3)
                .fill(DSColor.heroHighlight)
                .overlay {
                    VStack(spacing: 2) {
                        ForEach(0..<2, id: \.self) { _ in
                            Capsule().fill(trim).frame(height: 1.5)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .overlay {
                    if detailed {
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(DSColor.heroChefShade, style: StrokeStyle(lineWidth: 0.5, dash: [1, 1]))
                            .padding(1.2)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(isGold ? DSColor.legendary : DSColor.heroChefShade, lineWidth: 1)
                }
                .frame(width: 15, height: 9)
        }
    }

    private var mug: some View {
        ZStack {
            Circle().stroke(DSColor.heroChefShade, lineWidth: 2.4).frame(width: 7, height: 7).offset(x: 6.5)
            RoundedRectangle(cornerRadius: 2.5)
                .fill(heroGradient(DSColor.heroHighlight, DSColor.heroChefShade))
                .overlay { RoundedRectangle(cornerRadius: 2.5).strokeBorder(ink, lineWidth: 0.8) }
                .frame(width: 13, height: 14)
            Capsule().fill(DSColor.heroTeal).frame(width: 13, height: 3).offset(y: 1)
            if detailed {
                Ellipse().fill(DSColor.heroWood).frame(width: 10, height: 2).offset(y: -6)
                Capsule().fill(DSColor.heroHighlight).frame(width: 1.4, height: 6).offset(x: -4, y: 1)
            }
        }
    }

    private var thermos: some View {
        ZStack {
            // Tall and narrow with a cup-lid on top: a different silhouette from the mug it replaces.
            RoundedRectangle(cornerRadius: 2.5)
                .fill(heroGradient(DSColor.heroSteel, DSColor.heroSteelShade))
                .overlay { RoundedRectangle(cornerRadius: 2.5).strokeBorder(ink, lineWidth: 0.8) }
                .frame(width: 9, height: 19)
                .offset(y: 1)
            RoundedRectangle(cornerRadius: 1.5).fill(DSColor.legendary).frame(width: 10, height: 4).offset(y: -9)
            RoundedRectangle(cornerRadius: 1).fill(DSColor.heroSteelShade).frame(width: 6, height: 2.5).offset(y: -12)
            Capsule().fill(DSColor.legendary).frame(width: 9, height: 1.6).offset(y: 6)
            if detailed {
                Capsule().fill(DSColor.heroHighlight.opacity(0.8)).frame(width: 1.4, height: 11).offset(x: -2.5, y: 0)
                Capsule().fill(DSColor.legendary).frame(width: 9, height: 1.2).offset(y: 3)
            }
        }
    }

    private var duck: some View {
        ZStack {
            Ellipse().fill(DSColor.legendary).frame(width: 14, height: 9)
            Circle().fill(DSColor.legendary).frame(width: 8, height: 8).offset(x: 5, y: -5)
            Capsule().fill(DSColor.boss).frame(width: 4, height: 2).offset(x: 10, y: -4.5)
            Circle().fill(DSColor.heroInk).frame(width: 1.5, height: 1.5).offset(x: 6, y: -6)
            if detailed {
                Ellipse().fill(DSColor.heroCapeShade.opacity(0.25)).frame(width: 7, height: 4).offset(x: -1.5, y: 0.5)
                Circle().fill(DSColor.heroHighlight).frame(width: 0.6, height: 0.6).offset(x: 6.3, y: -6.3)
            }
        }
        .offset(x: -1.5, y: 2)
    }

    private var blocks: some View {
        ZStack {
            block(DSColor.boss, letter: "A").offset(x: -4.5, y: 4.5)
            block(DSColor.accent, letter: "B").offset(x: 4.5, y: 4.5)
            block(DSColor.legendary, letter: "C").offset(x: 0, y: -4)
        }
    }

    private func block(_ color: Color, letter: String) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .overlay { RoundedRectangle(cornerRadius: 1.5).strokeBorder(DSColor.heroInk.opacity(0.2), lineWidth: 0.8) }
            .overlay {
                if detailed {
                    Text(letter).font(.system(size: 5.5, weight: .black, design: .rounded)).foregroundStyle(DSColor.heroHighlight)
                }
            }
            .frame(width: 8, height: 8)
    }

    private func bag(isMega: Bool) -> some View {
        let trim = isMega ? DSColor.legendary : DSColor.heroSteel
        let size = isMega ? CGSize(width: 22, height: 18) : CGSize(width: 18, height: 15)
        return ZStack {
            if isMega {
                // A bottle sticking out of the side pocket: the big bag carries more, and it shows.
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(DSColor.heroHighlight)
                    .overlay { RoundedRectangle(cornerRadius: 1.5).strokeBorder(ink, lineWidth: 0.6) }
                    .frame(width: 4.5, height: 9)
                    .overlay(alignment: .top) { Capsule().fill(DSColor.heroTeal).frame(width: 3, height: 2).offset(y: -1.5) }
                    .offset(x: -10, y: -6)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(heroGradient(DSColor.heroCloth, DSColor.heroNavyShade))
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 4, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: 4
                    )
                        .fill(DSColor.heroNavyShade)
                        .frame(height: isMega ? 8 : 7)
                        .overlay {
                            if detailed {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 3, bottomLeadingRadius: 2, bottomTrailingRadius: 2, topTrailingRadius: 3
                                )
                                    .strokeBorder(
                                        DSColor.heroSteel.opacity(0.6),
                                        style: StrokeStyle(lineWidth: 0.4, dash: [0.8, 0.8])
                                    )
                                    .padding(1)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            Capsule().fill(trim).frame(width: isMega ? 7 : 5, height: 2.5).offset(y: 1)
                        }
                }
                .overlay(alignment: .bottom) {
                    if isMega {
                        RoundedRectangle(cornerRadius: 2).fill(DSColor.heroTeal).frame(width: 11, height: 5).padding(.bottom, 2.5)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(isMega ? DSColor.legendary : ink, lineWidth: isMega ? 1.2 : 0.8)
                }
                .frame(width: size.width, height: size.height)
        }
    }

}

/// Steam over hot drinks. Drawn apart from `HeroItemArt` so the outline does not turn it into solid bars.
struct HeroItemSteam: View {
    let item: HeroItem
    let glow: Double

    var body: some View {
        switch item {
        case .mug: steam(offsets: [-2.5, 2.5], top: -11, opacity: 0.3 + 0.3 * glow)
        case .thermos: steam(offsets: [-1.5, 1.5], top: -16, opacity: 0.35 * glow)
        default: EmptyView()
        }
    }

    private func steam(offsets: [CGFloat], top: CGFloat, opacity: Double) -> some View {
        ForEach(offsets, id: \.self) { side in
            Capsule().fill(DSColor.textSecondary.opacity(opacity)).frame(width: 1.5, height: 5).offset(x: side, y: top)
        }
    }
}
