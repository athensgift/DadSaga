/// Something the hero carries, e.g. a coffee mug. A title brings it (ADR-0055 §4); once had, it is never taken away
/// (ADR-0006, ADR-0048).
public struct GearItem: ContentItem, Hashable, Identifiable, Sendable {
    public let id: String
    /// Ids it had before a rename (ADR-0048 §5).
    public let formerIDs: [String]
    /// Its slot on the hero (ADR-0014) and its section in the wardrobe. It unlocks nothing.
    public let skill: Skill
    /// The skill XP that earned it before titles, for the eight items that shipped then; `nil` for items added since.
    /// Only says what a dad from before titles had already earned.
    public let skillXPBeforeTitles: Int?
    /// Which drawing the avatar uses. Unknown looks are simply not drawn.
    public let look: String
    public let title: LocalizedText

    public init(
        id: String,
        skill: Skill,
        skillXPBeforeTitles: Int? = nil,
        look: String,
        title: LocalizedText,
        formerIDs: [String] = []
    ) {
        self.id = id
        self.formerIDs = formerIDs
        self.skill = skill
        self.skillXPBeforeTitles = skillXPBeforeTitles
        self.look = look
        self.title = title
    }
}
