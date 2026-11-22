import Foundation

/// Display-ready state for the home screen. Plain values only.
public enum HomeViewState: Equatable, Sendable {
    case loading
    case loaded(HomeContent)
    case failed(message: String)
}

public struct HomeContent: Equatable, Sendable {
    public let heroTitle: String
    /// The hero's motto; `nil` while the child shown is not born yet, when it would speak of days that haven't come.
    public let heroTagline: String?
    public let heroLook: HeroLook
    public let heroSkin: SkinToneChoice
    public let heroAppearance: DadAppearanceChoice
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
    /// The dad's level and title, e.g. "Επίπεδο 4 · Σίγουρα χέρια". No total and no next title (ADR-0059 §1).
    public let dadTitle: TitleLineModel?
    /// The four skills under it, grown as far as the entries take them; a card's skill waits at its level until the
    /// card's celebration has gone, then rises (ADR-0059 §2).
    public internal(set) var skills: SkillMarksModel
    public let worldTitle: String?
    public let worldTagline: String?
    /// When the shown world is ideal, while it lies ahead of the child: «Ιδανικά από τους 9 μήνες» (ADR-0061 §3).
    public let idealLine: String?
    /// Set while another world is shown instead of the current one: the button text to go back.
    public let backToCurrentTitle: String?
    /// Shown instead of quests when there is no content for the child's age yet.
    public let emptyMessage: String?
    /// One quiet line under the world while the child is not born yet: how to say they've arrived (ADR-0053 §1).
    public let arrivalLine: String?
    public let cards: [CardModel]
    /// The bosses for when life changes, in one closed row after the cards (ADR-0053 §5); `nil` when there are none.
    public let situational: SituationalCards?
    /// The selected child's legendary moments.
    public let moments: MomentsSection
}

/// "When life changes" and its bosses. It opens on a tap and shows no count.
public struct SituationalCards: Equatable, Identifiable, Sendable {
    /// The child, the world and the visit: a new id starts the row closed (ADR-0053 §5).
    public let id: String
    public let title: String
    public let cards: [CardModel]
}

public struct MomentsSection: Equatable, Sendable {
    public let title: String
    /// Captured out of all, e.g. "2 / 14".
    public let progress: String
    public let addTitle: String
    /// Newest first, as gold cards.
    public let cards: [MomentCardModel]
    /// Shown when nothing is captured yet.
    public let emptyText: String
    /// Every first is already captured for this child.
    public let isComplete: Bool
    /// For the cards' photos, full screen.
    public let viewer: PhotoViewerLabels
}

/// The sheet for a legendary moment of the selected child, in two steps (ADR-0042 §5): choose the first and when it
/// happened, which records it at once; then, if the dad likes, photos and a few words. Editing opens at the second.
public struct MomentCapture: Equatable, Identifiable, Sendable {
    public enum Step: Equatable, Sendable {
        case choose(MomentChoice)
        case details(MomentDetails)
    }

    /// The same through both steps, so the sheet stays open while it moves on.
    public let id: UUID
    /// The child's name.
    public let title: String
    public internal(set) var step: Step

    /// The second step, once there.
    public var details: MomentDetails? {
        if case .details(let details) = step { details } else { nil }
    }
}

/// Step 1: which first, and when.
public struct MomentChoice: Equatable, Sendable {
    /// The firsts offered at this age and not captured yet for this child.
    public let options: [MomentOption]
    public let dateLabel: String
    /// The earliest of the options' earliest days, while none is chosen.
    public let earliestDate: Date
    public let latestDate: Date
    /// "Next, if you like: photos or a few words."
    public let nextLine: String
    /// The ✓ button, for VoiceOver.
    public let saveTitle: String
}

/// Step 2: the moment's own page, to add photos and a few words or change the date.
public struct MomentDetails: Equatable, Sendable {
    public let momentID: UUID
    /// Emoji and name, e.g. "👣 Πρώτα βήματα".
    public let title: String
    /// Just recorded: it says so, offers "Not now", and celebrates. Otherwise it was opened to edit, with Delete.
    public let isNew: Bool
    /// "Saved! Want to keep something more?", for a new moment.
    public let heading: String?
    /// "Photos or a few words, now or whenever you like.", for a new moment.
    public let line: String?
    public let date: Date
    public let note: String
    /// In the dad's order; the first is the cover.
    public let photoIDs: [String]
    public let dateLabel: String
    public let earliestDate: Date
    public let latestDate: Date
    public let notePlaceholder: String
    public let saveTitle: String
    public let notNowTitle: String
    public let labels: MomentLabels
    /// "Saved · Undo" in the sheet: undoing deletes the moment and closes the sheet.
    public internal(set) var undoOffer: UndoOffer?
}

public struct MomentLabels: Equatable, Sendable {
    public let journal: JournalLabels
    public let delete: String
    public let deleteConfirmation: String
    public let cancel: String
}

/// A captured moment as a gold card.
public struct MomentCardModel: Equatable, Identifiable, Sendable {
    public let id: UUID
    /// Emoji and name, e.g. "👣 Πρώτα βήματα".
    public let title: String
    /// Date and note.
    public let subtitle: String
    /// In the dad's order; the first is the cover.
    public let photoIDs: [String]
    /// How many photos, for VoiceOver, e.g. "3 φωτογραφίες"; `nil` without photos.
    public let photoCount: String?
}

public struct MomentOption: Equatable, Identifiable, Sendable {
    public let id: String
    public let emoji: String
    public let title: String
    /// The earliest day this first can be dated (ADR-0053 §3).
    public let earliestDate: Date
}

/// The sheet asking the dad whether he did a quest.
public struct QuestDetail: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    /// The skill it grows, e.g. "Care". No XP (ADR-0055 §7).
    public let reward: String
    /// How to do it well, when the quest has a tip.
    public let tip: TipDetail?
    /// The "does not replace a doctor's advice" line, for medical tips only.
    public let footer: String?
    public let confirmTitle: String
    public let journal: JournalLabels
    /// The note or photo from the last time with this child, if he left one.
    public let lastJournal: LastJournal?
}

/// A quest tip as shown in the quest sheet.
public struct TipDetail: Equatable, Sendable {
    public let title: String
    public let steps: [String]
}

/// The sheet for a boss fight: intro, survival guide and the "we made it" action.
public struct BossDetail: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let intro: String
    public let guideTitle: String
    public let guide: [String]
    /// The badge it brings, e.g. "Θερμόμετρο". No XP (ADR-0055 §7).
    public let reward: String
    public let disclaimer: String
    public let isDefeated: Bool
    public let defeatedText: String
    public let confirmTitle: String
    public let journal: JournalLabels
    /// What he wrote when they got through it, once defeated.
    public let lastJournal: LastJournal?
}

/// Shown briefly after a quest is completed or a boss is defeated.
public struct Celebration: Equatable, Identifiable, Sendable {
    /// Increases with every completion, so it also works as an animation trigger.
    public let id: Int
    /// What grew, e.g. "Your patience grew". Never XP, a level or a title: the title has its own card (ADR-0055 §6).
    public let skillText: String?
    /// The badge earned, for boss fights.
    public let badgeText: String?
    /// A legendary moment just captured, e.g. "Πρώτα βήματα".
    public var momentText: String?

    /// How big a moment this is, which sets the animation and haptic. Bigger moments win when several happen at once.
    public enum Highlight: Comparable, Sendable {
        case quest, boss, moment
    }

    /// Everything the badge shows, in its order, for VoiceOver to read out as it appears.
    public var announcement: String {
        [skillText, badgeText, momentText].compactMap(\.self).joined(separator: ", ")
    }

    public var highlight: Highlight {
        if momentText != nil { return .moment }
        if badgeText != nil { return .boss }
        return .quest
    }

    /// The tap this celebration plays, if any. An ordinary quest gets none here: the hero's cheer already taps once.
    /// None at all when the dad turned haptics off (ADR-0030).
    public func haptic(isEnabled: Bool) -> CelebrationHaptic? {
        guard isEnabled else { return nil }
        return switch highlight {
        case .quest: nil
        case .boss: .heavy
        case .moment: .success
        }
    }
}

public enum CelebrationHaptic: Equatable, Sendable {
    case heavy, success
}

/// Shown for a few seconds after something is recorded.
public struct UndoOffer: Equatable, Identifiable, Sendable {
    /// Matches the celebration it came with.
    public let id: Int
    let eventID: UUID
    public let message: String
    public let actionTitle: String
    /// Undoing it failed: the entry is still there, and the bar says so.
    public var didFail = false
}

public struct ChildTab: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
}

/// Every world in order, for the selected child: where they are, where they have been, what is ahead.
public struct WorldMapContent: Equatable, Sendable {
    public let title: String
    /// e.g. "Νίκος · 10 μηνών".
    public let subtitle: String
    /// «Άνοιξε αυτόν τον κόσμο», under the world shown above the fold (ADR-0061 §4).
    public let openTitle: String
    public let worlds: [WorldMapItem]

    /// The world home shows: the one above the fold until the dad taps another.
    public var shownWorld: WorldMapItem? {
        worlds.first(where: \.isShown) ?? worlds.first { $0.status == .current }
    }
}

public struct WorldMapItem: Equatable, Identifiable, Sendable {
    public enum Status: Equatable, Sendable {
        /// The child's age is in this world.
        case current
        /// Reached earlier; its quests can still be played.
        case visited
        /// The child's age hasn't reached it. Open all the same, with all its cards (ADR-0061 §3).
        case ahead
    }

    public let id: String
    public let number: Int
    public let title: String
    public let tagline: String
    /// e.g. "9–24 μηνών".
    public let ageRange: String
    public let status: Status
    /// When a world ahead is ideal («Ιδανικά από τους 9 μήνες»); `nil` for a world the child has reached, where nothing
    /// is ever late.
    public let idealLine: String?
    /// What was kept there ("7 αποστολές · 1 αφεντικό"): always for a world reached, for one ahead once the dad has
    /// done something there.
    public let progress: String?
    /// "Είσαι εδώ", "Βλέπεις αυτόν τον κόσμο", or nil.
    public let tag: String?
    /// The world shown on home right now.
    public let isShown: Bool
}
