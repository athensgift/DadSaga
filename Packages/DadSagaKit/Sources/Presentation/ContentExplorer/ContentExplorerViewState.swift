/// Display-ready state for the content explorer. Plain values only: no Domain types reach the View.
public enum ContentExplorerViewState: Equatable, Sendable {
    case loading
    case loaded(ContentExplorerContent)
    case failed(message: String)
}

public struct ContentExplorerContent: Equatable, Sendable {
    public let level: Int
    public let levelFraction: Double
    public let worlds: [WorldSection]
    public let firstsTitle: String
    public let firsts: [CardModel]
}

public struct WorldSection: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let tagline: String
    public let cards: [CardModel]
}

public struct CardModel: Equatable, Identifiable, Sendable {
    public enum Kind: Equatable, Sendable {
        case quest, boss, legendary
    }

    public let id: String
    public let title: String
    public let subtitle: String
    public let badge: String
    public let kind: Kind
    /// A "done" line, e.g. how many times the quest was completed.
    public var footnote: String?
}
