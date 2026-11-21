import Domain
import Foundation

/// What the dad can play right now with one child: the child's age today and the family's facts (ADR-0053).
public struct Adventure: Hashable, Sendable {
    public let age: ChildAge
    /// Who the cards are for in this family (ADR-0053 §4).
    public let family: FamilyFacts
    /// No world fits this age (older than every world, or not born with no world before birth): nothing to play with
    /// them yet.
    public let isBeyondContent: Bool
    public let currentWorld: World?
    public let unlockedWorlds: [World]

    public init(
        age: ChildAge,
        family: FamilyFacts,
        currentWorld: World?,
        unlockedWorlds: [World],
        isBeyondContent: Bool = false
    ) {
        self.age = age
        self.family = family
        self.isBeyondContent = isBeyondContent
        self.currentWorld = currentWorld
        self.unlockedWorlds = unlockedWorlds
    }

    /// The child's adventure on `today`.
    public init(for child: Child, family: FamilyFacts, catalog: ContentCatalog, on today: CalendarDay) {
        let age = child.age(on: today)
        let isBeyondContent = UnlockRules.isBeyondContent(catalog, age: age)
        self.init(
            age: age,
            family: family,
            currentWorld: isBeyondContent ? nil : UnlockRules.currentWorld(in: catalog, age: age),
            unlockedWorlds: UnlockRules.unlockedWorlds(in: catalog, age: age),
            isBeyondContent: isBeyondContent
        )
    }
}
