/// A real-life challenge (first fever, sleep regression…) with a short survival guide.
public struct BossFight: Hashable, Identifiable, Sendable {
    public let id: String
    public let worldID: String
    public let title: LocalizedText
    public let intro: LocalizedText
    public let guide: [LocalizedText]
    public let badge: LocalizedText
    public let skill: Skill
    public let xp: Int
    public let minAgeMonths: Int

    public init(
        id: String,
        worldID: String,
        title: LocalizedText,
        intro: LocalizedText,
        guide: [LocalizedText],
        badge: LocalizedText,
        skill: Skill,
        xp: Int,
        minAgeMonths: Int
    ) {
        self.id = id
        self.worldID = worldID
        self.title = title
        self.intro = intro
        self.guide = guide
        self.badge = badge
        self.skill = skill
        self.xp = xp
        self.minAgeMonths = minAgeMonths
    }
}
