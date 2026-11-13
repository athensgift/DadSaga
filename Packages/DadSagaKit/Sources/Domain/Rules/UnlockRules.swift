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

    public static func availableBosses(in catalog: ContentCatalog, ageInMonths: Int) -> [BossFight] {
        let worldIDs = Set(unlockedWorlds(in: catalog, ageInMonths: ageInMonths).map(\.id))
        return catalog.bosses.filter { worldIDs.contains($0.worldID) && $0.minAgeMonths <= ageInMonths }
    }
}
