import DesignSystem
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
        /// Worn crossbody: strap from the right shoulder, bag on the left hip.
        case hip
    }

    /// Each skill has a first item and an upgrade. Upgrades read as special from their shape and a gold glow,
    /// not from colour alone.
    public enum Tier: Sendable {
        case standard, legendary
    }

    public var tier: Tier {
        switch self {
        case .burpCloth, .mug, .duck, .diaperBag: .standard
        case .burpClothGold, .thermos, .blocks, .megaBag: .legendary
        }
    }

    var slot: Slot {
        switch self {
        case .burpCloth, .burpClothGold: .shoulder
        case .mug, .thermos: .leftHand
        case .duck, .blocks: .ground
        case .diaperBag, .megaBag: .hip
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

extension View {
    /// A cartoon outline around the whole silhouette, like the rest of the avatar: four hard ink shadows.
    func heroOutline(_ width: CGFloat) -> some View {
        let ink = DSColor.heroInk.opacity(0.75)
        return compositingGroup()
            .shadow(color: ink, radius: 0, x: width, y: 0)
            .shadow(color: ink, radius: 0, x: -width, y: 0)
            .shadow(color: ink, radius: 0, x: 0, y: width)
            .shadow(color: ink, radius: 0, x: 0, y: -width)
    }

    /// Legendary items glow gold, pulsing with `glow`, and carry a sparkle.
    @ViewBuilder
    func heroTier(_ tier: HeroItem.Tier, glow: Double, sparkleAt sparkle: CGPoint) -> some View {
        switch tier {
        case .standard:
            self
        case .legendary:
            self
                .shadow(color: DSColor.legendary.opacity(0.45 + 0.45 * glow), radius: 2.5 + 2 * glow)
                .overlay {
                    Sparkle()
                        .fill(DSColor.legendary)
                        .frame(width: 5, height: 5)
                        .scaleEffect(0.75 + 0.35 * glow)
                        .offset(x: sparkle.x, y: sparkle.y)
                }
        }
    }
}

/// An item as the avatar wears it: simplified, outlined, with its tier's glow.
private struct HeroWornItem: View {
    let item: HeroItem
    let glow: Double

    private var sparkle: CGPoint {
        switch item {
        case .burpClothGold: CGPoint(x: 8, y: -7)
        case .thermos: CGPoint(x: 7, y: -12)
        case .blocks: CGPoint(x: 7, y: -8)
        case .megaBag: CGPoint(x: 11, y: -9)
        default: .zero
        }
    }

    var body: some View {
        ZStack {
            HeroItemSteam(item: item, glow: glow)
            HeroItemArt(item: item)
                .heroOutline(0.7)
                .heroTier(item.tier, glow: glow, sparkleAt: sparkle)
        }
    }
}

/// The large, detailed item for lists such as the wardrobe. Legendary items glow and sparkle here too.
public struct HeroItemIcon: View {
    let item: HeroItem
    let size: CGFloat

    public init(item: HeroItem, size: CGFloat = 56) {
        self.item = item
        self.size = size
    }

    public var body: some View {
        let canvas = HeroItemArt.canvas
        ZStack {
            HeroItemSteam(item: item, glow: 1)
            HeroItemArt(item: item, detailed: true)
                .heroOutline(0.45)
                .heroTier(item.tier, glow: 0.6, sparkleAt: CGPoint(x: 10, y: -10))
        }
            .frame(width: canvas.width, height: canvas.height)
            .scaleEffect(size / canvas.width)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Slots (coordinates in `HeroFigure`'s design canvas)

struct HeroShoulderItem: View {
    let item: HeroItem
    var glow: Double = 0.5

    var body: some View {
        HeroWornItem(item: item, glow: glow)
            .rotationEffect(.degrees(-28))
            .offset(x: -23, y: 9)
    }
}

/// Drawn on the left hand, upright whatever the arm does.
struct HeroLeftHandItem: View {
    let item: HeroItem
    let glow: Double

    var body: some View {
        // The mug is held by the handle, so the cup sits outside the hand and reads at a glance.
        HeroWornItem(item: item, glow: glow)
            .offset(x: item == .mug ? -8 : -7, y: item == .mug ? 2 : 0)
    }
}

struct HeroGroundItem: View {
    let item: HeroItem
    var glow: Double = 0.5

    var body: some View {
        HeroWornItem(item: item, glow: glow)
            .offset(x: -45, y: item == .duck ? 60 : 58)
    }
}

/// A crossbody bag: the strap runs across the chest from the right shoulder, the bag hangs on the left hip,
/// clear of the right hand's archetype item.
struct HeroHipItem: View {
    let item: HeroItem
    var glow: Double = 0.5

    var body: some View {
        let isMega = item == .megaBag
        ZStack {
            Capsule()
                .fill(DSColor.heroCloth)
                .overlay { Capsule().strokeBorder(DSColor.heroInk.opacity(0.3), lineWidth: 0.6) }
                .frame(width: 3, height: 44)
                .rotationEffect(.degrees(47))
                .offset(x: 3, y: 17)
            HeroWornItem(item: item, glow: glow)
                .offset(x: -13, y: isMega ? 38 : 37)
        }
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
