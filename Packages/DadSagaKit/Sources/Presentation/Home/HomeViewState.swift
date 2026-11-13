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
    /// XP inside the current level, e.g. "40 / 100 XP".
    public let xpLine: String
    public let worldTitle: String?
    public let worldTagline: String?
    public let cards: [CardModel]
}

/// The sheet asking the dad whether he did a quest.
public struct QuestDetail: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let reward: String
    public let confirmTitle: String
    public let cancelTitle: String
}

/// Shown briefly after a quest is completed.
public struct Celebration: Equatable, Identifiable, Sendable {
    /// Increases with every completion, so it also works as an animation trigger.
    public let id: Int
    public let xpText: String
    /// Set only when the completion reached a new level.
    public let levelUpText: String?
}
