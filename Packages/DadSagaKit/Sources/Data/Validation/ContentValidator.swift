import Domain

/// Catches content mistakes at load time instead of as silent bugs at runtime.
enum ContentValidator {
    static func validate(_ catalog: ContentCatalog) throws {
        var seen: Set<String> = []
        let allIDs = catalog.worlds.map(\.id) + catalog.quests.map(\.id) + catalog.bosses.map(\.id) + catalog.firsts.map(\.id)
        for id in allIDs where !seen.insert(id).inserted {
            throw ContentDataError.duplicateID(id)
        }

        let worldIDs = Set(catalog.worlds.map(\.id))
        for quest in catalog.quests where !worldIDs.contains(quest.worldID) {
            throw ContentDataError.unknownWorld(itemID: quest.id, worldID: quest.worldID)
        }
        for boss in catalog.bosses where !worldIDs.contains(boss.worldID) {
            throw ContentDataError.unknownWorld(itemID: boss.id, worldID: boss.worldID)
        }
    }
}
