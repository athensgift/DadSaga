import Foundation

/// The dad's aggregated progress, derived from events. Pure and deterministic.
///
/// XP and level are the dad's, from every child together. What happened with a child (quests done, bosses
/// defeated, firsts captured) is kept per child: each child has their own first fever and their own first steps.
public struct DadProgress: Hashable, Sendable {
    public let totalXP: Int
    public let skillXP: [Skill: Int]
    private let firstsByChild: [UUID?: Set<String>]
    private let bossesByChild: [UUID?: Set<String>]
    private let questsByChild: [UUID?: [String: Int]]
    private let momentsByChild: [UUID?: [CapturedMoment]]
    private let journalByChild: [UUID?: [ProgressEvent.Kind: JournalEntry]]

    public var level: LevelProgress { LevelCurve.progress(forTotalXP: totalXP) }

    /// Every boss defeated, with any child.
    public var allDefeatedBossIDs: Set<String> { bossesByChild.values.reduce(into: []) { $0.formUnion($1) } }

    /// Events whose ids are not in the catalog are ignored (e.g. content removed in an update).
    /// Bosses and firsts count once per child; quests are repeatable.
    public init(events: [ProgressEvent], catalog: ContentCatalog) {
        let quests = Dictionary(uniqueKeysWithValues: catalog.quests.map { ($0.id, $0) })
        let bosses = Dictionary(uniqueKeysWithValues: catalog.bosses.map { ($0.id, $0) })
        let firsts = Dictionary(uniqueKeysWithValues: catalog.firsts.map { ($0.id, $0) })

        var total = 0
        var skills: [Skill: Int] = [:]
        var firstsByChild: [UUID?: Set<String>] = [:]
        var bossesByChild: [UUID?: Set<String>] = [:]
        var questsByChild: [UUID?: [String: Int]] = [:]
        var momentsByChild: [UUID?: [CapturedMoment]] = [:]
        var journalByChild: [UUID?: [ProgressEvent.Kind: JournalEntry]] = [:]

        for event in events.sorted(by: { $0.date < $1.date }) {
            if event.note != nil || event.photoID != nil {
                journalByChild[event.childID, default: [:]][event.kind] = JournalEntry(
                    eventID: event.id, date: event.date, note: event.note, photoID: event.photoID
                )
            }
            switch event.kind {
            case .quest(let id):
                guard let quest = quests[id] else { continue }
                total += quest.xp
                skills[quest.skill, default: 0] += quest.xp
                questsByChild[event.childID, default: [:]][id, default: 0] += 1
            case .boss(let id):
                guard let boss = bosses[id], bossesByChild[event.childID, default: []].insert(id).inserted else { continue }
                total += boss.xp
                skills[boss.skill, default: 0] += boss.xp
            case .first(let id):
                guard let first = firsts[id], firstsByChild[event.childID, default: []].insert(id).inserted else { continue }
                total += first.xp
                let moment = CapturedMoment(
                    eventID: event.id,
                    first: first,
                    date: event.date,
                    note: event.note,
                    photoID: event.photoID
                )
                momentsByChild[event.childID, default: []].append(moment)
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
    public func lastJournal(for kind: ProgressEvent.Kind, childID: UUID?) -> JournalEntry? {
        journalByChild[childID]?[kind]
    }

    public func capturedFirstIDs(for childID: UUID?) -> Set<String> {
        firstsByChild[childID] ?? []
    }

    public func defeatedBossIDs(for childID: UUID?) -> Set<String> {
        bossesByChild[childID] ?? []
    }

    /// The child's legendary moments, newest first.
    public func moments(for childID: UUID?) -> [CapturedMoment] {
        (momentsByChild[childID] ?? []).sorted { $0.date > $1.date }
    }

    /// How many times each quest has been completed with this child.
    public func questCompletions(for childID: UUID?) -> [String: Int] {
        questsByChild[childID] ?? [:]
    }
}

/// A first the dad captured for a child, with when it happened and what he wrote.
public struct CapturedMoment: Hashable, Identifiable, Sendable {
    /// The event that recorded it.
    public let eventID: UUID
    public let first: FirstMoment
    public let date: Date
    public let note: String?
    public let photoID: String?

    public var id: UUID { eventID }

    public init(eventID: UUID, first: FirstMoment, date: Date, note: String?, photoID: String?) {
        self.eventID = eventID
        self.first = first
        self.date = date
        self.note = note
        self.photoID = photoID
    }
}

/// What the dad wrote or photographed when he completed something.
public struct JournalEntry: Hashable, Sendable {
    public let eventID: UUID
    public let date: Date
    public let note: String?
    public let photoID: String?

    public init(eventID: UUID, date: Date, note: String?, photoID: String?) {
        self.eventID = eventID
        self.date = date
        self.note = note
        self.photoID = photoID
    }
}
