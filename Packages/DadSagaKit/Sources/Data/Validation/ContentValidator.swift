import Application
import Foundation
import Domain

/// Catches content mistakes at load time instead of as silent bugs at runtime.
enum ContentValidator {
    static func validate(_ catalog: ContentCatalog) throws {
        var seen: Set<String> = []
        // A former id is reserved like a current one (ADR-0048 §5): it may not name anything else, nor be listed twice.
        let items: [any ContentItem] = catalog.worlds + catalog.quests + catalog.bosses + catalog.firsts
            + catalog.heroClasses + catalog.gear
        let allIDs = items.flatMap { [$0.id] + $0.formerIDs }
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
        try validateAppearance(catalog.appearanceOptions)
    }

    /// Each part names every option the app can draw, once, and nothing else (ADR-0044 §3). Ids are unique within
    /// their part only, so they stay out of the catalog-wide check above.
    private static func validateAppearance(_ options: [DadAppearanceOption]) throws {
        for part in DadAppearance.Part.allCases {
            let known = DadAppearance.optionIDs(for: part)
            var seen: Set<String> = []
            for option in options where option.part == part {
                guard known.contains(option.id) else {
                    throw ContentDataError.unknownAppearanceOption(part: part.rawValue, id: option.id)
                }
                guard seen.insert(option.id).inserted else {
                    throw ContentDataError.duplicateID("\(part.rawValue).\(option.id)")
                }
            }
            if let missing = known.first(where: { !seen.contains($0) }) {
                throw ContentDataError.missingAppearanceOption(part: part.rawValue, id: missing)
            }
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
