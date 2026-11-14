/// Something the hero carries once the dad has earned enough XP in a skill, e.g. a coffee mug for patience.
/// Gear is only ever gained: XP never goes down, so nothing is ever taken away (ADR-0006).
public struct GearItem: Hashable, Identifiable, Sendable {
    public let id: String
    public let skill: Skill
    /// Skill XP needed to earn it.
    public let minXP: Int
    /// Which drawing the avatar uses. Unknown looks are simply not drawn.
    public let look: String
    public let title: LocalizedText

    public init(id: String, skill: Skill, minXP: Int, look: String, title: LocalizedText) {
        self.id = id
        self.skill = skill
        self.minXP = minXP
        self.look = look
        self.title = title
    }
}
