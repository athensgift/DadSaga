import SwiftUI

/// Things the hero has earned and carries. Each lives in its own slot, chosen so it never clashes with what a dad
/// archetype already wears or holds.
public enum HeroItem: CaseIterable, Sendable {
    case burpCloth, burpClothGold
    case mug, thermos
    case duck, blocks
    case diaperBag, megaBag

    enum Slot {
        /// Over the left shoulder.
        case shoulder
        /// In the left hand (the right hand holds the archetype's own item).
        case leftHand
        /// On the ground, at the dad's feet.
        case ground
        /// Behind him, peeking out on the right.
        case back
    }

    var slot: Slot {
        switch self {
        case .burpCloth, .burpClothGold: .shoulder
        case .mug, .thermos: .leftHand
        case .duck, .blocks: .ground
        case .diaperBag, .megaBag: .back
        }
    }
}

/// What the hero carries: one item per slot at most, and up to four boss medals.
struct HeroEquipment: Equatable {
    var items: [HeroItem] = []
    var medals = 0

    func item(in slot: HeroItem.Slot) -> HeroItem? {
        items.last { $0.slot == slot }
    }
}

extension EnvironmentValues {
    @Entry var heroEquipment = HeroEquipment()
}

// MARK: - Drawings (coordinates in `HeroFigure`'s design canvas)

struct HeroShoulderItem: View {
    let item: HeroItem

    var body: some View {
        let isGold = item == .burpClothGold
        RoundedRectangle(cornerRadius: 3)
            .fill(DSColor.heroHighlight)
            .overlay {
                VStack(spacing: 2) {
                    ForEach(0..<2, id: \.self) { _ in
                        Capsule().fill(isGold ? DSColor.legendary : DSColor.accent.opacity(0.6)).frame(height: 1.5)
                    }
                }
                .padding(.horizontal, 2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 3).strokeBorder(isGold ? DSColor.legendary : DSColor.heroChefShade, lineWidth: 1)
            }
            .frame(width: 15, height: 9)
            .rotationEffect(.degrees(-28))
            .offset(x: -23, y: 9)
    }
}

/// Drawn on the left hand, upright whatever the arm does.
struct HeroLeftHandItem: View {
    let item: HeroItem
    let glow: Double

    var body: some View {
        switch item {
        case .mug:
            ZStack {
                Circle().stroke(DSColor.heroHighlight, lineWidth: 1.8).frame(width: 5, height: 5).offset(x: 4.5)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(heroGradient(DSColor.heroHighlight, DSColor.heroChefShade))
                    .frame(width: 8, height: 9)
                Capsule().fill(DSColor.heroTeal).frame(width: 8, height: 2).offset(y: -1)
            }
            .offset(x: -1, y: 1)
        case .thermos:
            ZStack {
                ForEach([-1.5, 1.5], id: \.self) { side in
                    Capsule()
                        .fill(DSColor.textSecondary.opacity(0.35 * glow))
                        .frame(width: 1.5, height: 5)
                        .offset(x: side, y: -13)
                }
                RoundedRectangle(cornerRadius: 2)
                    .fill(heroGradient(DSColor.heroSteel, DSColor.heroSteelShade))
                    .frame(width: 7, height: 15)
                RoundedRectangle(cornerRadius: 1).fill(DSColor.legendary).frame(width: 8, height: 3).offset(y: -7)
            }
            .offset(y: -2)
        default:
            EmptyView()
        }
    }
}

struct HeroGroundItem: View {
    let item: HeroItem

    var body: some View {
        switch item {
        case .duck:
            ZStack {
                Ellipse().fill(DSColor.legendary).frame(width: 14, height: 9)
                Circle().fill(DSColor.legendary).frame(width: 8, height: 8).offset(x: 5, y: -5)
                Capsule().fill(DSColor.boss).frame(width: 4, height: 2).offset(x: 10, y: -4.5)
                Circle().fill(DSColor.heroInk).frame(width: 1.5, height: 1.5).offset(x: 6, y: -6)
            }
            .offset(x: -40, y: 60)
        case .blocks:
            ZStack {
                block(DSColor.boss).offset(x: -4.5, y: 0)
                block(DSColor.accent).offset(x: 4.5, y: 0)
                block(DSColor.legendary).offset(x: 0, y: -8.5)
            }
            .offset(x: -40, y: 59)
        default:
            EmptyView()
        }
    }

    private func block(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .overlay { RoundedRectangle(cornerRadius: 1.5).strokeBorder(DSColor.heroInk.opacity(0.2), lineWidth: 0.8) }
            .frame(width: 8, height: 8)
    }
}

struct HeroBackItem: View {
    let item: HeroItem

    var body: some View {
        let isMega = item == .megaBag
        RoundedRectangle(cornerRadius: 4)
            .fill(heroGradient(DSColor.heroKnightShade, DSColor.heroCloth))
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(DSColor.heroCloth)
                    .frame(height: isMega ? 8 : 6)
                    .overlay(alignment: .bottom) {
                        Capsule().fill(isMega ? DSColor.legendary : DSColor.heroSteel).frame(width: 6, height: 2).offset(y: 1)
                    }
            }
            .overlay(alignment: .bottom) {
                if isMega {
                    RoundedRectangle(cornerRadius: 2).fill(DSColor.heroTeal).frame(width: 10, height: 7).padding(.bottom, 3)
                }
            }
            .frame(width: isMega ? 22 : 16, height: isMega ? 25 : 18)
            .offset(x: isMega ? 27 : 25, y: isMega ? 22 : 25)
    }
}

/// One medal per boss defeated, in a column on the left of the chest.
struct HeroMedals: View {
    let count: Int

    private static let colors = [DSColor.legendary, DSColor.heroSteel, DSColor.boss, DSColor.accent]

    var body: some View {
        ForEach(0..<min(count, Self.colors.count), id: \.self) { index in
            ZStack {
                Capsule().fill(DSColor.heroTeal).frame(width: 3, height: 4).offset(y: -3)
                Circle()
                    .fill(Self.colors[index])
                    .overlay { Circle().strokeBorder(DSColor.heroInk.opacity(0.25), lineWidth: 0.6) }
                    .frame(width: 5, height: 5)
            }
            .offset(x: -14.5, y: 2 + CGFloat(index) * 7)
        }
    }
}
