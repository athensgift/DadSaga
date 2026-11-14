import DesignSystem
import SwiftUI

/// The dad with his children standing next to him: the first child on his right, the second on his left, and so on.
/// Shrinks to fit the width, so four children fit on the iPhone Duo cover display. Tapping a child selects them.
struct FamilyStage: View {
    let heroStyle: HeroAvatar.Style
    let heroSkin: AvatarSkin
    let heroGear: [HeroItem]
    let medals: Int
    let heroTitle: String
    let companions: [CompanionModel]
    let selectedChildID: UUID
    /// The dad's height when there is room for it.
    let maxHeroSize: CGFloat
    let cheerTrigger: Int
    let onSelect: (UUID) -> Void

    @State private var width: CGFloat = 0
    @State private var taps: [UUID: Int] = [:]

    /// Children are drawn at this fraction of the dad's height (their canvas; a baby fills about half of it).
    private static let childScale: CGFloat = 0.62
    /// How much neighbours overlap, as a fraction of the dad's height.
    private static let overlap: CGFloat = 0.06

    var body: some View {
        let heroSize = heroSize
        let childSize = heroSize * Self.childScale
        HStack(alignment: .bottom, spacing: -heroSize * Self.overlap) {
            ForEach(leftSide) { companion in
                child(companion, size: childSize, heroSize: heroSize)
            }
            HeroAvatar(
                style: heroStyle,
                size: heroSize,
                cheerTrigger: cheerTrigger,
                skin: heroSkin,
                items: heroGear,
                medals: medals
            )
                .accessibilityLabel(heroTitle)
                .zIndex(1)
            ForEach(rightSide) { companion in
                child(companion, size: childSize, heroSize: heroSize)
            }
        }
        // minWidth 0: the frame takes the offered width even while the group is still too wide, so the measured
        // width is what is available, not what the group currently needs (which would never let it shrink).
        .frame(minWidth: 0, maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    private var heroSize: CGFloat {
        let count = CGFloat(companions.count)
        let widthPerHeroHeight = HeroAvatar.aspectRatio
            + count * (Self.childScale * ChildAvatar.aspectRatio - Self.overlap)
        guard width > 0 else { return maxHeroSize }
        return min(maxHeroSize, width / widthPerHeroHeight)
    }

    /// Odd positions (2nd, 4th child) stand on the dad's left, nearest first.
    private var leftSide: [CompanionModel] {
        companions.enumerated().filter { $0.offset.isMultiple(of: 2) == false }.map(\.element).reversed()
    }

    private var rightSide: [CompanionModel] {
        companions.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element)
    }

    private func child(_ companion: CompanionModel, size: CGFloat, heroSize: CGFloat) -> some View {
        let isSelected = companion.id == selectedChildID
        return ChildAvatar(
            stage: companion.stage.avatarStage,
            gender: companion.gender.avatarGender,
            skin: companion.skin.avatarSkin,
            size: size,
            cheerTrigger: taps[companion.id, default: 0] + (isSelected ? cheerTrigger : 0),
            traits: companion.traits.avatarTraits
        )
        .padding(.bottom, HeroAvatar.groundInset(forSize: heroSize) - ChildAvatar.groundInset(forSize: size))
        .contentShape(Rectangle())
        .onTapGesture {
            taps[companion.id, default: 0] += 1
            onSelect(companion.id)
        }
        .accessibilityElement()
        .accessibilityLabel(companion.name)
        .accessibilityAddTraits(isSelected && companions.count > 1 ? [.isButton, .isSelected] : .isButton)
    }
}
