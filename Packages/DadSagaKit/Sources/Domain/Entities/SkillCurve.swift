/// How fast one skill's mark on home grows (ADR-0059 §2): the skill XP at which it is half grown. Content, from
/// `skills.json`, never Swift (ADR-0005). A value that has shipped may only go down (ADR-0048 §5).
public struct SkillCurve: Hashable, Sendable {
    public let skill: Skill
    /// Above 0.
    public let halfGrownXP: Int

    public init(skill: Skill, halfGrownXP: Int) {
        self.skill = skill
        self.halfGrownXP = halfGrownXP
    }
}
