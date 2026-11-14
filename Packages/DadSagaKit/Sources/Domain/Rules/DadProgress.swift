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

        for event in events.sorted(by: { $0.date < $1.date }) {
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
                let moment = CapturedMoment(first: first, date: event.date, note: event.note)
                momentsByChild[event.childID, default: []].append(moment)
            }
        }

        totalXP = total
        skillXP = skills
        self.firstsByChild = firstsByChild
        self.bossesByChild = bossesByChild
        self.questsByChild = questsByChild
        self.momentsByChild = momentsByChild
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
public struct CapturedMoment: Hashable, Sendable {
    public let first: FirstMoment
    public let date: Date
    public let note: String?

    public init(first: FirstMoment, date: Date, note: String?) {
        self.first = first
        self.date = date
        self.note = note
    }
}
