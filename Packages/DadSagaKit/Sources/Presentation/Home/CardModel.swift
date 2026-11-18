/// One card on home: a quest or a boss, ready to show.
public struct CardModel: Equatable, Identifiable, Sendable {
    public enum Kind: Equatable, Sendable {
        case quest, boss
    }

    public let id: String
    public let title: String
    public let subtitle: String
    public let badge: String
    /// SF Symbol for the card's icon tile.
    public let symbol: String
    public let kind: Kind
    /// A "done" line, e.g. how many times the quest was completed.
    public var footnote: String?
    /// A marker that the card has more inside, e.g. a tip's title.
    public var hint: String?
    /// The skill a quest feeds, e.g. "Care", so the dad sees which gear it moves him towards.
    public var skill: String?
}
