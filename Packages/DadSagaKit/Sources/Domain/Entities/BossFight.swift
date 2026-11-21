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
    /// Offered only to a family where every one of these holds (ADR-0053 §4). Empty: every family.
    public let onlyFor: Set<Audience>
    /// For when life changes (a move, two homes, a loss): home keeps it in a closed row of its own (ADR-0053 §5).
    public let isSituational: Bool
    /// Also shown in every later world, like an evergreen quest; counted only in its own world (ADR-0053 §5).
    public let isEvergreen: Bool

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
        onlyFor: Set<Audience> = [],
        isSituational: Bool = false,
        isEvergreen: Bool = false,
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
        self.onlyFor = onlyFor
        self.isSituational = isSituational
        self.isEvergreen = isEvergreen
    }
}
