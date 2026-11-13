/// The dad's aggregated progress, derived from events. Pure and deterministic.
public struct DadProgress: Hashable, Sendable {
    public let totalXP: Int
    public let skillXP: [Skill: Int]
    public let capturedFirstIDs: Set<String>
    public let defeatedBossIDs: Set<String>
    /// How many times each quest has been completed.
    public let questCompletions: [String: Int]

    public var level: LevelProgress { LevelCurve.progress(forTotalXP: totalXP) }

    /// Events whose ids are not in the catalog are ignored (e.g. content removed in an update).
    /// Bosses and firsts count once; quests are repeatable.
    public init(events: [ProgressEvent], catalog: ContentCatalog) {
        let quests = Dictionary(uniqueKeysWithValues: catalog.quests.map { ($0.id, $0) })
        let bosses = Dictionary(uniqueKeysWithValues: catalog.bosses.map { ($0.id, $0) })
        let firsts = Dictionary(uniqueKeysWithValues: catalog.firsts.map { ($0.id, $0) })

        var total = 0
        var skills: [Skill: Int] = [:]
        var capturedFirsts: Set<String> = []
        var defeatedBosses: Set<String> = []
        var completions: [String: Int] = [:]

        for event in events.sorted(by: { $0.date < $1.date }) {
            switch event.kind {
            case .quest(let id):
                guard let quest = quests[id] else { continue }
                total += quest.xp
                skills[quest.skill, default: 0] += quest.xp
                completions[id, default: 0] += 1
            case .boss(let id):
                guard let boss = bosses[id], defeatedBosses.insert(id).inserted else { continue }
                total += boss.xp
                skills[boss.skill, default: 0] += boss.xp
            case .first(let id):
                guard let first = firsts[id], capturedFirsts.insert(id).inserted else { continue }
                total += first.xp
            }
        }

        totalXP = total
        skillXP = skills
        capturedFirstIDs = capturedFirsts
        defeatedBossIDs = defeatedBosses
        questCompletions = completions
    }
}
