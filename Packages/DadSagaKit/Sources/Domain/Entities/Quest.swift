/// Something the dad does in real life. XP rewards the dad's action.
public struct Quest: ContentItem, Hashable, Identifiable, Sendable {
    public let id: String
    /// Ids it had before a rename (ADR-0048 §4).
    public let formerIDs: [String]
    public let worldID: String
    public let title: LocalizedText
    public let description: LocalizedText
    public let skill: Skill
    public let xp: Int
    public let minAgeMonths: Int
    /// How to do it well, when the card needs more than its title.
    public let tip: QuestTip?
    /// Also shown in every later world (ADR-0020): needs that do not belong to one age.
    public let isEvergreen: Bool

    public init(
        id: String,
        worldID: String,
        title: LocalizedText,
        description: LocalizedText,
        skill: Skill,
        xp: Int,
        minAgeMonths: Int,
        tip: QuestTip? = nil,
        isEvergreen: Bool = false,
        formerIDs: [String] = []
    ) {
        self.id = id
        self.formerIDs = formerIDs
        self.worldID = worldID
        self.title = title
        self.description = description
        self.skill = skill
        self.xp = xp
        self.minAgeMonths = minAgeMonths
        self.tip = tip
        self.isEvergreen = isEvergreen
    }
}

/// A short, practical "how to" on a quest. Medical tips end with a fixed "ask your paediatrician" line in the app.
public struct QuestTip: Hashable, Sendable {
    public let title: LocalizedText
    public let steps: [LocalizedText]
    public let isMedical: Bool

    public init(title: LocalizedText, steps: [LocalizedText], isMedical: Bool = false) {
        self.title = title
        self.steps = steps
        self.isMedical = isMedical
    }
}
