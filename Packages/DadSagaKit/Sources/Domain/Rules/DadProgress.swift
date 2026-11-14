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
            }
        }

        totalXP = total
        skillXP = skills
        self.firstsByChild = firstsByChild
        self.bossesByChild = bossesByChild
        self.questsByChild = questsByChild
    }

    public func capturedFirstIDs(for childID: UUID?) -> Set<String> {
        firstsByChild[childID] ?? []
    }

    public func defeatedBossIDs(for childID: UUID?) -> Set<String> {
        bossesByChild[childID] ?? []
    }

    /// How many times each quest has been completed with this child.
    public func questCompletions(for childID: UUID?) -> [String: Int] {
        questsByChild[childID] ?? [:]
    }
}
