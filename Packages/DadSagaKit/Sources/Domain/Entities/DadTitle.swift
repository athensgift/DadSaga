/// What the dad has become, e.g. "Steady hands" (ADR-0055). A title needs both a number of cards done and total XP, so
/// one early boss can't skip titles. It may bring gear for the hero. Titles are content, never Swift (ADR-0005).
public struct DadTitle: ContentItem, Hashable, Identifiable, Sendable {
    public let id: String
    /// Ids it had before a rename (ADR-0048 §5).
    public let formerIDs: [String]
    /// The first title is 0, and orders run 0, 1, 2… with no gap; a higher order is a higher title. It is also the
    /// dad's level, shown beside the title on home (ADR-0059 §1), so a shipped title keeps its order for good.
    public let order: Int
    /// Counted timeline entries needed: a quest every time, a boss or a first once per child.
    public let minCards: Int
    /// Total XP needed.
    public let minXP: Int
    /// The gear items it brings, by id.
    public let gearIDs: [String]
    public let name: LocalizedText

    public init(
        id: String,
        order: Int,
        minCards: Int,
        minXP: Int,
        gearIDs: [String] = [],
        name: LocalizedText,
        formerIDs: [String] = []
    ) {
        self.id = id
        self.formerIDs = formerIDs
        self.order = order
        self.minCards = minCards
        self.minXP = minXP
        self.gearIDs = gearIDs
        self.name = name
    }
}
