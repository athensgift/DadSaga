/// How much one of the dad's skills has grown, from the XP his entries give it now (ADR-0059 §2). Pure.
///
/// It is `xp / (xp + halfGrownXP)`: 0 before any card of the skill, half at `halfGrownXP`, three quarters at three
/// times that, and never 1. Nothing fills up and there is nothing to reach. It follows the entries, so an undo or a
/// deletion takes back what its card gave; a first has no skill and grows none.
public struct SkillGrowth: Hashable, Sendable {
    public let skill: Skill
    /// From 0 up to, never reaching, 1.
    public let value: Double

    /// A skill without a curve doesn't grow: the validator makes sure the content has one for each.
    public init(skill: Skill, xp: Int, curve: SkillCurve?) {
        self.skill = skill
        guard let curve, curve.halfGrownXP > 0, xp > 0 else {
            value = 0
            return
        }
        value = Double(xp) / Double(xp + curve.halfGrownXP)
    }

    /// The four skills, always in `Skill.allCases` order, never sorted by size.
    public static func all(_ progress: DadProgress, catalog: ContentCatalog) -> [SkillGrowth] {
        Skill.allCases.map { skill in
            SkillGrowth(skill: skill, xp: progress.skillXP[skill] ?? 0, curve: catalog.curve(for: skill))
        }
    }
}
