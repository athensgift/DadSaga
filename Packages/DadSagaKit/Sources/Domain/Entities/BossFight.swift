/// A real-life challenge (first fever, sleep regression…) with a short survival guide.
public struct BossFight: ContentItem, Hashable, Identifiable, Sendable {
    public let id: String
    /// Ids it had before a rename (ADR-0048 §5).
    public let formerIDs: [String]
    public let worldID: String
    public let title: LocalizedText
    public let intro: LocalizedText
    public let guide: [LocalizedText]
    public let badge: LocalizedText
    public let skill: Skill
    public let xp: Int
    public let minAgeMonths: Int
    /// Only for families with more than one child (e.g. a new sibling). Reads the family, never the child's development.
    public let requiresSibling: Bool

    public init(
        id: String,
        worldID: String,
        title: LocalizedText,
        intro: LocalizedText,
        guide: [LocalizedText],
        badge: LocalizedText,
        skill: Skill,
        xp: Int,
        minAgeMonths: Int,
        requiresSibling: Bool = false,
        formerIDs: [String] = []
    ) {
        self.id = id
        self.formerIDs = formerIDs
        self.worldID = worldID
        self.title = title
        self.intro = intro
        self.guide = guide
        self.badge = badge
        self.skill = skill
        self.xp = xp
        self.minAgeMonths = minAgeMonths
        self.requiresSibling = requiresSibling
    }
}
