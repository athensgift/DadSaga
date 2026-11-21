import Domain
import Foundation

/// What the dad can play right now with one child, given the child's age today.
public struct Adventure: Hashable, Sendable {
    public let ageInMonths: Int
    /// The child is older than any world: nothing to play with them yet.
    public let isBeyondContent: Bool
    public let currentWorld: World?
    public let unlockedWorlds: [World]
    public let availableBosses: [BossFight]

    public init(
        ageInMonths: Int,
        currentWorld: World?,
        unlockedWorlds: [World],
        availableBosses: [BossFight],
        isBeyondContent: Bool = false
    ) {
        self.ageInMonths = ageInMonths
        self.isBeyondContent = isBeyondContent
        self.currentWorld = currentWorld
        self.unlockedWorlds = unlockedWorlds
        self.availableBosses = availableBosses
    }

    /// The child's adventure on `today`. `childCount` is the number of children in the family; sibling-only bosses need
    /// more than one.
    public init(for child: Child, childCount: Int, catalog: ContentCatalog, on today: CalendarDay) {
        let age = child.ageInMonths(on: today)
        let isBeyondContent = UnlockRules.isBeyondContent(catalog, ageInMonths: age)
        self.init(
            ageInMonths: age,
            currentWorld: isBeyondContent ? nil : UnlockRules.currentWorld(in: catalog, ageInMonths: age),
            unlockedWorlds: UnlockRules.unlockedWorlds(in: catalog, ageInMonths: age),
            availableBosses: isBeyondContent
                ? []
                : UnlockRules.availableBosses(in: catalog, ageInMonths: age, childCount: childCount),
            isBeyondContent: isBeyondContent
        )
    }
}
