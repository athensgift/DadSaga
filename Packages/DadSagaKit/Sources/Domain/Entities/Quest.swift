/// Something the dad does in real life. XP rewards the dad's action.
public struct Quest: Hashable, Identifiable, Sendable {
    public let id: String
    public let worldID: String
    public let title: LocalizedText
    public let description: LocalizedText
    public let skill: Skill
    public let xp: Int
    public let minAgeMonths: Int

    public init(
        id: String,
        worldID: String,
        title: LocalizedText,
        description: LocalizedText,
        skill: Skill,
        xp: Int,
        minAgeMonths: Int
    ) {
        self.id = id
        self.worldID = worldID
        self.title = title
        self.description = description
        self.skill = skill
        self.xp = xp
        self.minAgeMonths = minAgeMonths
    }
}
