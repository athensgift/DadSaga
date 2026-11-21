/// Something the hero carries once the dad has earned enough XP in a skill, e.g. a coffee mug for patience.
/// Gear is only ever gained: XP never goes down, so nothing is ever taken away (ADR-0006).
public struct GearItem: ContentItem, Hashable, Identifiable, Sendable {
    public let id: String
    /// Ids it had before a rename (ADR-0048 §4).
    public let formerIDs: [String]
    public let skill: Skill
    /// Skill XP needed to earn it.
    public let minXP: Int
    /// Which drawing the avatar uses. Unknown looks are simply not drawn.
    public let look: String
    public let title: LocalizedText

    public init(
        id: String,
        skill: Skill,
        minXP: Int,
        look: String,
        title: LocalizedText,
        formerIDs: [String] = []
    ) {
        self.id = id
        self.formerIDs = formerIDs
        self.skill = skill
        self.minXP = minXP
        self.look = look
        self.title = title
    }
}
