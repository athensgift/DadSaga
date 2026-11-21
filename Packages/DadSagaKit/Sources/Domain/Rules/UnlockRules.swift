/// Age-based unlocking, and who a card is for (ADR-0019, ADR-0020, ADR-0053). The child's development never locks the dad
/// out of anything.
public enum UnlockRules {
    /// Every world the child has reached: a world before birth at every age, a world of months from its minimum age.
    public static func unlockedWorlds(in catalog: ContentCatalog, age: ChildAge) -> [World] {
        catalog.worlds.filter { $0.span.isReached(at: age) }
    }

    /// The world the child is in right now: the last reached, by order.
    public static func currentWorld(in catalog: ContentCatalog, age: ChildAge) -> World? {
        unlockedWorlds(in: catalog, age: age).last
    }

    /// True when no world fits this age: the child is older than every world, or not born yet and the content has no
    /// world before birth. There is no content for this age yet.
    public static func isBeyondContent(_ catalog: ContentCatalog, age: ChildAge) -> Bool {
        guard let months = age.months else { return !catalog.worlds.contains(where: \.isBeforeBirth) }
        let limits = catalog.worlds.compactMap { world -> Int?? in
            if case .months(_, let max) = world.span { max } else { nil }
        }
        guard !limits.isEmpty, !limits.contains(nil) else { return false }
        return months > limits.compactMap(\.self).max() ?? .max
    }

    /// The quests offered in one world: its own, then every evergreen quest from an earlier world (ADR-0020), each
    /// offered to this child and family (`isOffered`).
    public static func quests(for world: World, in catalog: ContentCatalog, age: ChildAge, family: FamilyFacts) -> [Quest] {
        shown(in: world, catalog: catalog, from: catalog.quests.filter { isOffered($0, in: catalog, age: age, family: family) })
    }

    /// The bosses offered in one world: its own, then every evergreen boss from an earlier world (ADR-0053 §5), each
    /// offered to this child and family. Situational bosses are included; home keeps them apart.
    public static func bosses(
        for world: World,
        in catalog: ContentCatalog,
        age: ChildAge,
        family: FamilyFacts
    ) -> [BossFight] {
        shown(in: world, catalog: catalog, from: catalog.bosses.filter { isOffered($0, in: catalog, age: age, family: family) })
    }

    /// Whether a quest is offered at all: not retired, reached at this age, and for this family.
    public static func isOffered(_ quest: Quest, in catalog: ContentCatalog, age: ChildAge, family: FamilyFacts) -> Bool {
        !quest.isRetired
            && isReached(minAgeMonths: quest.minAgeMonths, worldID: quest.worldID, in: catalog, at: age)
            && family.allows(quest.onlyFor)
    }

    /// Whether a boss is offered at all: reached at this age, and for this family.
    public static func isOffered(_ boss: BossFight, in catalog: ContentCatalog, age: ChildAge, family: FamilyFacts) -> Bool {
        isReached(minAgeMonths: boss.minAgeMonths, worldID: boss.worldID, in: catalog, at: age) && family.allows(boss.onlyFor)
    }

    /// The firsts that can be captured at this age (ADR-0053 §3): before the birth only firsts before birth, after it
    /// every first. Never a retired one.
    public static func firsts(in catalog: ContentCatalog, age: ChildAge) -> [FirstMoment] {
        catalog.firsts.filter { first in
            guard !first.isRetired else { return false }
            return age == .beforeBirth ? first.isBeforeBirth : true
        }
    }

    /// Before the birth, only the cards of a world before birth; after it, every card of its minimum age.
    private static func isReached(minAgeMonths: Int, worldID: String, in catalog: ContentCatalog, at age: ChildAge) -> Bool {
        guard let months = age.months else { return catalog.world(id: worldID)?.isBeforeBirth == true }
        return minAgeMonths <= months
    }

    /// A world's own items, then the evergreen items of earlier worlds in world order.
    private static func shown<Item: WorldCard>(in world: World, catalog: ContentCatalog, from items: [Item]) -> [Item] {
        let order = Dictionary(uniqueKeysWithValues: catalog.worlds.map { ($0.id, $0.order) })
        let own = items.filter { $0.worldID == world.id }
        let evergreen = items.filter { item in
            guard item.isEvergreen, let home = order[item.worldID] else { return false }
            return home < world.order
        }
        return own + evergreen.sorted { order[$0.worldID, default: 0] < order[$1.worldID, default: 0] }
    }
}

/// A card that belongs to a world and may show in later ones.
private protocol WorldCard {
    var worldID: String { get }
    var isEvergreen: Bool { get }
}

extension Quest: WorldCard {}
extension BossFight: WorldCard {}
