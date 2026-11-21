/// What the hero has and what he wears (ADR-0055 §4). Gear comes with titles; the skill-XP rule from before titles
/// only says what a dad from then had already earned.
public enum GearRules {
    /// What the rule from before titles gives for this skill XP: every shipped item whose `skillXPBeforeTitles` the
    /// skill reached. Items added since have no such threshold and never come this way.
    public static func earnedBeforeTitles(_ gear: [GearItem], skillXP: [Skill: Int]) -> [GearItem] {
        gear.filter { item in
            item.skillXPBeforeTitles.map { $0 <= skillXP[item.skill, default: 0] } ?? false
        }
    }

    /// `items` by slot, in skill order, and within a slot by the title that brings each, lowest first: the last in a
    /// slot is the best.
    public static func ordered(_ items: [GearItem], in catalog: ContentCatalog) -> [GearItem] {
        Skill.allCases.flatMap { skill in
            items
                .filter { $0.skill == skill }
                .sorted { (catalog.title(bringing: $0.id)?.order ?? .max) < (catalog.title(bringing: $1.id)?.order ?? .max) }
        }
    }

    /// What the hero wears: one item per slot at most, from `earned` in `ordered` order. Automatic slots wear the best;
    /// a chosen item that is not earned (e.g. content changed) falls back to automatic, and one chosen before a rename
    /// stays worn. Ordered by skill.
    public static func equipped(_ earned: [GearItem], outfit: Outfit = Outfit()) -> [GearItem] {
        Skill.allCases.compactMap { skill in
            let best = earned.last { $0.skill == skill }
            switch outfit.choice(for: skill) {
            case .automatic: return best
            case .hidden: return nil
            case .item(let id): return earned.first { $0.has(id: id) && $0.skill == skill } ?? best
            }
        }
    }
}
