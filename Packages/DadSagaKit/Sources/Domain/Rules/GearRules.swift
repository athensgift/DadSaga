/// What the hero carries, derived from the dad's skill XP.
public enum GearRules {
    /// For each skill, the best item earned: the one with the highest threshold the dad has reached.
    /// Skills with nothing earned yet carry nothing. Ordered by skill.
    public static func equipped(_ gear: [GearItem], skillXP: [Skill: Int]) -> [GearItem] {
        Skill.allCases.compactMap { skill in
            gear
                .filter { $0.skill == skill && $0.minXP <= skillXP[skill, default: 0] }
                .max { $0.minXP < $1.minXP }
        }
    }

    /// Items equipped after a change that were not equipped before: what to celebrate.
    public static func newlyEquipped(_ gear: [GearItem], before: [Skill: Int], after: [Skill: Int]) -> [GearItem] {
        let old = Set(equipped(gear, skillXP: before).map(\.id))
        return equipped(gear, skillXP: after).filter { !old.contains($0.id) }
    }
}
