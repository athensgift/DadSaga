import Foundation

/// The dad's aggregated progress, derived from events. Pure and deterministic.
///
/// XP and level are the dad's, from every child together. What happened with a child (quests done, bosses
/// defeated, firsts captured) is kept per child: each child has their own first fever and their own first steps.
public struct DadProgress: Hashable, Sendable {
    public let totalXP: Int
    public let skillXP: [Skill: Int]
    private let firstsByChild: [UUID: Set<String>]
    private let bossesByChild: [UUID: Set<String>]
    private let questsByChild: [UUID: [String: Int]]
    private let momentsByChild: [UUID: [CapturedMoment]]
    private let journalByChild: [UUID: [ProgressEvent.Kind: JournalEntry]]

    public var level: LevelProgress { LevelCurve.progress(forTotalXP: totalXP) }

    /// Every boss defeated, with any child.
    public var allDefeatedBossIDs: Set<String> { bossesByChild.values.reduce(into: []) { $0.formUnion($1) } }

    /// Counts the same events as the timeline (see `Timeline`): unknown content is ignored, bosses and firsts count
    /// once per child, quests are repeatable.
    public init(events: [ProgressEvent], catalog: ContentCatalog) {
        var total = 0
        var skills: [Skill: Int] = [:]
        var firstsByChild: [UUID: Set<String>] = [:]
        var bossesByChild: [UUID: Set<String>] = [:]
        var questsByChild: [UUID: [String: Int]] = [:]
        var momentsByChild: [UUID: [CapturedMoment]] = [:]
        var journalByChild: [UUID: [ProgressEvent.Kind: JournalEntry]] = [:]

        for entry in Timeline.countedEntries(from: events, catalog: catalog) {
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
                firstsByChild[entry.childID, default: []].insert(first.id)
                momentsByChild[entry.childID, default: []].append(
                    CapturedMoment(
                        eventID: entry.id, first: first, date: entry.date, note: entry.note, photoIDs: entry.photoIDs
                    )
                )
            }
            if entry.note != nil || !entry.photoIDs.isEmpty {
                journalByChild[entry.childID, default: [:]][eventKind] = JournalEntry(
                    eventID: entry.id, date: entry.date, note: entry.note, photoIDs: entry.photoIDs
                )
            }
        }

        totalXP = total
        skillXP = skills
        self.firstsByChild = firstsByChild
        self.bossesByChild = bossesByChild
        self.questsByChild = questsByChild
        self.momentsByChild = momentsByChild
        self.journalByChild = journalByChild
    }

    /// The newest note or photo the dad left on this card with this child, if any ("last time you wrote…").
    public func lastJournal(for kind: ProgressEvent.Kind, childID: UUID) -> JournalEntry? {
        journalByChild[childID]?[kind]
    }

    /// Whether recording this again for the child would count for nothing: a boss already beaten or a first already
    /// captured. Always false for a quest, which can be done again and again.
    public func isAlreadyCounted(_ kind: ProgressEvent.Kind, for childID: UUID) -> Bool {
        switch kind {
        case .quest: false
        case .boss(let id): defeatedBossIDs(for: childID).contains(id)
        case .first(let id): capturedFirstIDs(for: childID).contains(id)
        }
    }

    public func capturedFirstIDs(for childID: UUID) -> Set<String> {
        firstsByChild[childID] ?? []
    }

    public func defeatedBossIDs(for childID: UUID) -> Set<String> {
        bossesByChild[childID] ?? []
    }

    /// The child's legendary moments, newest first.
    public func moments(for childID: UUID) -> [CapturedMoment] {
        (momentsByChild[childID] ?? []).sorted { $0.date > $1.date }
    }

    /// How many times each quest has been completed with this child.
    public func questCompletions(for childID: UUID) -> [String: Int] {
        questsByChild[childID] ?? [:]
    }

    /// How far the dad got in one world with this child. An evergreen quest or boss counts only in its home world. Every
    /// boss beaten counts, whoever it is for now, and so does a retired quest he did (ADR-0051 §4, §6).
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

/// A first the dad captured for a child, with when it happened and what he wrote.
public struct CapturedMoment: Hashable, Identifiable, Sendable {
    /// The event that recorded it.
    public let eventID: UUID
    public let first: FirstMoment
    public let date: Date
    public let note: String?
    /// In the dad's order; the first is the cover.
    public let photoIDs: [String]

    public var id: UUID { eventID }
    public var coverPhotoID: String? { photoIDs.first }

    public init(eventID: UUID, first: FirstMoment, date: Date, note: String?, photoIDs: [String]) {
        self.eventID = eventID
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
