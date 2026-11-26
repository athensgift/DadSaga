import Application
import Foundation
import Domain

/// Catches content mistakes at load time instead of as silent bugs at runtime.
enum ContentValidator {
    /// The most steps a card's tip may have (ADR-0073).
    static let maxTipSteps = 6

    static func validate(_ catalog: ContentCatalog) throws {
        var seen: Set<String> = []
        // A former id is reserved like a current one (ADR-0048 §5): it may not name anything else, nor be listed twice.
        let items: [any ContentItem] = catalog.worlds + catalog.quests + catalog.bosses + catalog.firsts
            + catalog.heroClasses + catalog.gear + catalog.titles
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
        for quest in catalog.quests where (quest.tip?.steps.count ?? 0) > maxTipSteps {
            throw ContentDataError.longTip(itemID: quest.id)
        }
        for boss in catalog.bosses where boss.guide.isEmpty {
            throw ContentDataError.emptyGuide(itemID: boss.id)
        }
        try validateXP(catalog)
        try validateWorldAges(catalog)
        try validateBeforeBirth(catalog)
        try validateWeekly(catalog)
        try validateAppearance(catalog.appearanceOptions)
        try validateTitles(catalog)
        try validateSkillCurves(catalog.skillCurves)
    }

    private static func validateXP(_ catalog: ContentCatalog) throws {
        let rewards = catalog.quests.map { ($0.id, $0.xp) } + catalog.bosses.map { ($0.id, $0.xp) }
            + catalog.firsts.map { ($0.id, $0.xp) }
        if let (id, _) = rewards.first(where: { $0.1 <= 0 }) { throw ContentDataError.invalidXP(itemID: id) }
    }

    /// After the birth each world takes up where the one before it ends: from 0 months, by order, with no gap, no
    /// overlap and no world that ends before it starts. Only the last one may be open-ended.
    private static func validateWorldAges(_ catalog: ContentCatalog) throws {
        var expected: Int? = 0
        for world in catalog.worlds.sorted(by: { $0.order < $1.order }) {
            guard case .months(let min, let max) = world.span else { continue }
            guard min == expected, max.map({ $0 >= min }) ?? true else {
                throw ContentDataError.worldAgesNotInARow(worldID: world.id)
            }
            expected = max.map { $0 + 1 }
        }
    }

    /// Each skill has exactly one curve, and each half-grown XP is above 0 (ADR-0059 §2).
    private static func validateSkillCurves(_ curves: [SkillCurve]) throws {
        var seen: Set<Skill> = []
        for curve in curves {
            guard seen.insert(curve.skill).inserted else { throw ContentDataError.duplicateID(curve.skill.rawValue) }
            guard curve.halfGrownXP > 0 else { throw ContentDataError.invalidSkillCurve(skill: curve.skill.rawValue) }
        }
        if let missing = Skill.allCases.first(where: { !seen.contains($0) }) {
            throw ContentDataError.missingSkillCurve(skill: missing.rawValue)
        }
    }

    /// Orders run 0, 1, 2… (ADR-0059 §1), the first title needs nothing, each later one more cards and more XP, every
    /// item comes with exactly one title, and every name says something (ADR-0055 §2).
    private static func validateTitles(_ catalog: ContentCatalog) throws {
        let titles = catalog.titles
        for (index, title) in titles.enumerated() where title.order != index {
            throw ContentDataError.invalidTitleOrder(titleID: title.id)
        }
        if let first = titles.first, first.minCards != 0 || first.minXP != 0 {
            throw ContentDataError.invalidTitleThresholds(titleID: first.id)
        }
        for (lower, higher) in zip(titles, titles.dropFirst())
        where higher.minCards <= lower.minCards || higher.minXP <= lower.minXP {
            throw ContentDataError.invalidTitleThresholds(titleID: higher.id)
        }
        for title in titles where title.name.el.isEmpty || title.name.en.isEmpty {
            throw ContentDataError.emptyText(itemID: title.id)
        }
        var bringing: [String: String] = [:]
        for title in titles {
            for gearID in title.gearIDs {
                guard let item = catalog.gearItem(id: gearID) else {
                    throw ContentDataError.unknownGear(titleID: title.id, gearID: gearID)
                }
                guard bringing.updateValue(title.id, forKey: item.id) == nil else {
                    throw ContentDataError.gearInTwoTitles(gearID: item.id)
                }
            }
        }
        if !titles.isEmpty, let item = catalog.gear.first(where: { bringing[$0.id] == nil }) {
            throw ContentDataError.gearWithoutTitle(gearID: item.id)
        }
    }

    /// At most one world is before birth, and it comes first by order; every card in it is for 0 months, so it is
    /// reached before the birth and after it (ADR-0053 §2, §7).
    private static func validateBeforeBirth(_ catalog: ContentCatalog) throws {
        let beforeBirth = catalog.worlds.filter(\.isBeforeBirth)
        if let second = beforeBirth.dropFirst().first {
            throw ContentDataError.misplacedBeforeBirthWorld(worldID: second.id)
        }
        guard let world = beforeBirth.first else { return }
        if catalog.worlds.contains(where: { !$0.isBeforeBirth && $0.order <= world.order }) {
            throw ContentDataError.misplacedBeforeBirthWorld(worldID: world.id)
        }
        let aged = catalog.quests.filter { $0.worldID == world.id && $0.minAgeMonths > 0 }.map(\.id)
            + catalog.bosses.filter { $0.worldID == world.id && $0.minAgeMonths > 0 }.map(\.id)
        if let itemID = aged.first { throw ContentDataError.agedBeforeBirth(itemID: itemID) }
    }

    /// A world's own quests are never all left out of the weekly pick: `"weekly": false` is for a few cards. The check
    /// is per world, not per dad: it doesn't weigh `onlyFor` or ages (ADR-0082 §3).
    private static func validateWeekly(_ catalog: ContentCatalog) throws {
        for world in catalog.worlds {
            let own = catalog.quests.filter { $0.worldID == world.id && !$0.isRetired }
            if !own.isEmpty, !own.contains(where: \.isWeekly) {
                throw ContentDataError.noWeeklyQuest(worldID: world.id)
            }
        }
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
