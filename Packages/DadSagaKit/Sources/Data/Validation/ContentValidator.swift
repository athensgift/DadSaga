import Application
import Foundation
import Domain

/// Catches content mistakes at load time instead of as silent bugs at runtime.
enum ContentValidator {
    static func validate(_ catalog: ContentCatalog) throws {
        var seen: Set<String> = []
        let allIDs = catalog.worlds.map(\.id) + catalog.quests.map(\.id) + catalog.bosses.map(\.id)
            + catalog.firsts.map(\.id) + catalog.heroClasses.map(\.id) + catalog.gear.map(\.id)
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
        for quest in catalog.quests where quest.tip?.steps.isEmpty == true {
            throw ContentDataError.emptyTip(itemID: quest.id)
        }
    }

    static func validate(_ soundtracks: [Soundtrack]) throws {
        var seen: Set<String> = []
        for track in soundtracks {
            guard seen.insert(track.id).inserted else { throw ContentDataError.duplicateID(track.id) }
            let texts = [track.title.el, track.title.en, track.mood.el, track.mood.en, track.artist]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard !texts.contains(where: \.isEmpty) else { throw ContentDataError.emptyText(itemID: track.id) }
        }
    }
}
