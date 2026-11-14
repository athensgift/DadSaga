import Foundation

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
    public let heroSkin: SkinToneChoice
    /// Earned gear, one per skill at most.
    public let heroGear: [HeroGearLook]
    /// Bosses defeated with any child: one medal each.
    public let medalCount: Int
    /// One child: their name and age, e.g. "Νίκος · 10 μηνών". Several: their names.
    public let companionLine: String
    /// One tab per child when there are several, to choose whose quests are shown. Empty for one child.
    public let childTabs: [ChildTab]
    /// Every child, drawn next to the dad.
    public let companions: [CompanionModel]
    public let selectedChildID: UUID
    /// Name and age of the selected child, shown above their quests when there are several children.
    public let selectedChildLine: String?
    public let familyTitle: String
    public let level: Int
    /// e.g. "Επίπεδο 2".
    public let levelTitle: String
    public let levelFraction: Double
    /// XP inside the current level, e.g. "40 / 100 XP".
    public let xpLine: String
    public let worldTitle: String?
    public let worldTagline: String?
    /// Shown instead of quests when there is no content for the child's age yet.
    public let emptyMessage: String?
    public let cards: [CardModel]
}

/// The sheet asking the dad whether he did a quest.
public struct QuestDetail: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let reward: String
    public let confirmTitle: String
}

/// The sheet for a boss fight: intro, survival guide and the "we made it" action.
public struct BossDetail: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let intro: String
    public let guideTitle: String
    public let guide: [String]
    public let reward: String
    public let disclaimer: String
    public let isDefeated: Bool
    public let defeatedText: String
    public let confirmTitle: String
}

/// Shown briefly after a quest is completed or a boss is defeated.
public struct Celebration: Equatable, Identifiable, Sendable {
    /// Increases with every completion, so it also works as an animation trigger.
    public let id: Int
    public let xpText: String
    /// Set only when the completion reached a new level.
    public let levelUpText: String?
    /// The badge earned, for boss fights.
    public let badgeText: String?
    /// Gear the hero just earned, e.g. "Νέο: Κούπα καφέ".
    public let unlockText: String?
}

public struct ChildTab: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
}
