/// What the hero has earned and what he wears, derived from the dad's skill XP and his wardrobe choices.
public enum GearRules {
    /// Every item earned so far, lowest threshold first within each skill, skills in order.
    public static func earned(_ gear: [GearItem], skillXP: [Skill: Int]) -> [GearItem] {
        Skill.allCases.flatMap { skill in
            gear
                .filter { $0.skill == skill && $0.minXP <= skillXP[skill, default: 0] }
                .sorted { $0.minXP < $1.minXP }
        }
    }

    /// What the hero wears: one item per skill at most. Automatic slots wear the best earned item; a chosen item that
    /// is not earned (e.g. content changed) falls back to automatic, and one chosen before a rename stays worn. Ordered by
    /// skill.
    public static func equipped(_ gear: [GearItem], skillXP: [Skill: Int], outfit: Outfit = Outfit()) -> [GearItem] {
        let earned = earned(gear, skillXP: skillXP)
        return Skill.allCases.compactMap { skill in
            let best = earned.last { $0.skill == skill }
            switch outfit.choice(for: skill) {
            case .automatic: return best
            case .hidden: return nil
            case .item(let id): return earned.first { $0.has(id: id) && $0.skill == skill } ?? best
            }
        }
    }

    /// Items earned by a change that were not earned before: what to celebrate.
    public static func newlyEarned(_ gear: [GearItem], before: [Skill: Int], after: [Skill: Int]) -> [GearItem] {
        let old = Set(earned(gear, skillXP: before).map(\.id))
        return earned(gear, skillXP: after).filter { !old.contains($0.id) }
    }
}
