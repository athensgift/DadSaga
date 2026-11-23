import Foundation

/// One parent's progress, from their own entries only. Pure and deterministic.
///
/// XP, skills, cards done, bosses and quests are a parent's own (ADR-0065 §3.1, §3.3): a partner's entry never adds to
/// them or takes from them. Built only for this iPhone's player, never for another author (§3.5). What happened with a
/// child is kept per child: each child has their own first fever and their own bosses. The firsts the family captured,
/// whoever captured them, are `FamilyMoments`.
public struct DadProgress: Hashable, Sendable {
    public let totalXP: Int
    /// Every counted entry of his: a quest every time, a boss or a first once per child (ADR-0055 §1).
    public let cardsDone: Int
    public let skillXP: [Skill: Int]
    private let bossesByChild: [UUID: Set<String>]
    private let questsByChild: [UUID: [String: Int]]
    private let journalByChild: [UUID: [ProgressEvent.Kind: JournalEntry]]

    /// Every boss he defeated, with any child.
    public var allDefeatedBossIDs: Set<String> { bossesByChild.values.reduce(into: []) { $0.formUnion($1) } }

    /// Counts `player`'s entries in `events` as the timeline counts them (see `Timeline`): unknown content is ignored,
    /// bosses and firsts count once per child, quests are repeatable. Every other author's entry is left out.
    public init(of player: PlayerProfile, events: [ProgressEvent], catalog: ContentCatalog) {
        self.init(counted: Timeline.countedEntries(from: events.filter { $0.authorID == player.id }, catalog: catalog))
    }

    /// No progress: before there is a player.
    public static let none = DadProgress(counted: [])

    private init(counted entries: [TimelineEntry]) {
        var total = 0
        var skills: [Skill: Int] = [:]
        var bossesByChild: [UUID: Set<String>] = [:]
        var questsByChild: [UUID: [String: Int]] = [:]
        var journalByChild: [UUID: [ProgressEvent.Kind: JournalEntry]] = [:]

        cardsDone = entries.count
        for entry in entries {
            total += entry.xp
            let eventKind: ProgressEvent.Kind
            switch entry.kind {
            case .quest(let quest):
                eventKind = .quest(id: quest.id)
                skills[quest.skill, default: 0] += quest.xp
                questsByChild[entry.childID, default: [:]][quest.id, default: 0] += 1
            case .boss(let boss):
                eventKind = .boss(id: boss.id)
                skills[boss.skill, default: 0] += boss.xp
                bossesByChild[entry.childID, default: []].insert(boss.id)
            case .first(let first):
                eventKind = .first(id: first.id)
            }
            if entry.note != nil || !entry.photoIDs.isEmpty {
                journalByChild[entry.childID, default: [:]][eventKind] = JournalEntry(
                    eventID: entry.id, date: entry.date, note: entry.note, photoIDs: entry.photoIDs
                )
            }
        }

        totalXP = total
        skillXP = skills
        self.bossesByChild = bossesByChild
        self.questsByChild = questsByChild
        self.journalByChild = journalByChild
    }

    /// The newest note or photo he left on this card with this child, if any ("last time you wrote…").
    public func lastJournal(for kind: ProgressEvent.Kind, childID: UUID) -> JournalEntry? {
        journalByChild[childID]?[kind]
    }

    public func defeatedBossIDs(for childID: UUID) -> Set<String> {
        bossesByChild[childID] ?? []
    }

    /// How many times he has completed each quest with this child.
    public func questCompletions(for childID: UUID) -> [String: Int] {
        questsByChild[childID] ?? [:]
    }

    /// How far he got in one world with this child. An evergreen quest or boss counts only in its home world. Every
    /// boss beaten counts, whoever it is for now, and so does a retired quest he did (ADR-0053 §4, §6).
    public func progress(in world: World, catalog: ContentCatalog, childID: UUID) -> WorldProgress {
        let completions = questCompletions(for: childID)
        let defeated = defeatedBossIDs(for: childID)
        let bosses = catalog.bosses.filter { $0.worldID == world.id }
        return WorldProgress(
            questsDone: catalog.quests.filter { $0.worldID == world.id && completions[$0.id, default: 0] > 0 }.count,
            bossesDone: bosses.filter { defeated.contains($0.id) }.count
        )
    }
}

/// Quests done at least once and bosses beaten in one world, with one child.
public struct WorldProgress: Hashable, Sendable {
    public let questsDone: Int
    public let bossesDone: Int

    public init(questsDone: Int, bossesDone: Int) {
        self.questsDone = questsDone
        self.bossesDone = bossesDone
    }
}

/// A first captured for a child, with when it happened and what was written.
public struct CapturedMoment: Hashable, Identifiable, Sendable {
    /// The event that recorded it.
    public let eventID: UUID
    /// The parent who captured it.
    public let authorID: UUID
    public let first: FirstMoment
    public let date: Date
    public let note: String?
    /// In the dad's order; the first is the cover.
    public let photoIDs: [String]

    public var id: UUID { eventID }
    public var coverPhotoID: String? { photoIDs.first }

    public init(eventID: UUID, authorID: UUID, first: FirstMoment, date: Date, note: String?, photoIDs: [String]) {
        self.eventID = eventID
        self.authorID = authorID
        self.first = first
        self.date = date
        self.note = note
        self.photoIDs = photoIDs
    }
}

/// What the dad wrote or photographed when he completed something: a note, photos, or both.
public struct JournalEntry: Hashable, Sendable {
    public let eventID: UUID
    public let date: Date
    public let note: String?
    /// In the dad's order; the first is the cover.
    public let photoIDs: [String]

    public var coverPhotoID: String? { photoIDs.first }

    public init(eventID: UUID, date: Date, note: String?, photoIDs: [String]) {
        self.eventID = eventID
        self.date = date
        self.note = note
        self.photoIDs = photoIDs
    }
}
