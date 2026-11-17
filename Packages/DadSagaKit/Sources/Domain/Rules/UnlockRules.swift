/// Age-based unlocking. The child's development never locks the dad out of anything.
public enum UnlockRules {
    public static func unlockedWorlds(in catalog: ContentCatalog, ageInMonths: Int) -> [World] {
        catalog.worlds.filter { $0.minAgeMonths <= ageInMonths }
    }

    /// The world the child is in right now (latest unlocked).
    public static func currentWorld(in catalog: ContentCatalog, ageInMonths: Int) -> World? {
        unlockedWorlds(in: catalog, ageInMonths: ageInMonths).last
    }

    public static func availableQuests(in catalog: ContentCatalog, ageInMonths: Int) -> [Quest] {
        let worldIDs = Set(unlockedWorlds(in: catalog, ageInMonths: ageInMonths).map(\.id))
        return catalog.quests.filter { worldIDs.contains($0.worldID) && $0.minAgeMonths <= ageInMonths }
    }

    /// The quests shown for one world: its own, then every evergreen quest from an earlier world (ADR-0020).
    /// Each still needs the child to have reached its own minimum age.
    public static func quests(for world: World, in catalog: ContentCatalog, ageInMonths: Int) -> [Quest] {
        let order = Dictionary(uniqueKeysWithValues: catalog.worlds.map { ($0.id, $0.order) })
        let reached = catalog.quests.filter { $0.minAgeMonths <= ageInMonths }
        let own = reached.filter { $0.worldID == world.id }
        let evergreen = reached.filter { quest in
            guard quest.isEvergreen, let home = order[quest.worldID] else { return false }
            return home < world.order
        }
        return own + evergreen.sorted { order[$0.worldID, default: 0] < order[$1.worldID, default: 0] }
    }

    /// True when the child is older than every world: there is no content for this age yet.
    public static func isBeyondContent(_ catalog: ContentCatalog, ageInMonths: Int) -> Bool {
        let limits = catalog.worlds.map(\.maxAgeMonths)
        guard !limits.isEmpty, !limits.contains(nil) else { return false }
        return ageInMonths > limits.compactMap(\.self).max() ?? .max
    }

    /// Bosses the dad can meet with this child. Sibling-only bosses need a family with more than one child.
    public static func availableBosses(in catalog: ContentCatalog, ageInMonths: Int, childCount: Int) -> [BossFight] {
        let worldIDs = Set(unlockedWorlds(in: catalog, ageInMonths: ageInMonths).map(\.id))
        return catalog.bosses.filter {
            worldIDs.contains($0.worldID) && $0.minAgeMonths <= ageInMonths && isPossible($0, childCount: childCount)
        }
    }

    /// Whether a boss can happen at all in a family of this size.
    public static func isPossible(_ boss: BossFight, childCount: Int) -> Bool {
        !boss.requiresSibling || childCount > 1
    }
}
