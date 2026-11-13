/// Display-ready state for the home screen. Plain values only.
public enum HomeViewState: Equatable, Sendable {
    case loading
    case loaded(HomeContent)
    case failed(message: String)
}

public struct HomeContent: Equatable, Sendable {
    public let heroTitle: String
    public let heroTagline: String
    public let heroLook: HeroLook
    /// The companion: the child's name and age, e.g. "Νίκος · 10 μηνών".
    public let companionLine: String
    public let level: Int
    public let levelFraction: Double
    public let worldTitle: String?
    public let worldTagline: String?
    public let cards: [CardModel]
}
