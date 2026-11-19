import Foundation

/// What the dad did in a film's period, for its credits. Never totals of XP or levels (ADR-0006).
public struct SagaCredits: Hashable, Sendable {
    public let questsDone: Int
    public let bossesBeaten: Int

    public init(questsDone: Int, bossesBeaten: Int) {
        self.questsDone = questsDone
        self.bossesBeaten = bossesBeaten
    }
}

/// One scene of a saga film and how long it lasts.
public struct SagaScene: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case opening
        /// The child's world changed, by age. Numbered from 1 within the film; only in a film that spans two or more
        /// worlds.
        case chapter(World, number: Int)
        /// A first, a boss, or a quest with a photo.
        case entry(TimelineEntry)
        case credits(SagaCredits)
    }

    public let kind: Kind
    public let seconds: TimeInterval
}

/// The scenes of a saga film, oldest first (ADR-0036). Pure and deterministic.
///
/// Built from the timeline's counted entries, so the film never disagrees with the timeline or the dad's XP. Quests
/// without a photo are left out; every first is kept. A film over `SagaPacing.maxSeconds` loses, each evenly and
/// keeping the first and the last, quest photos, then bosses without a photo, then bosses with one. Only then do
/// firsts get shorter, down to `firstFloor`; firsts alone can take a film past its length.
public struct SagaStoryboard: Hashable, Sendable {
    public let period: SagaPeriod
    /// The moment the film tells the saga as of: the end of its period, or now if the period is still going. The
    /// opening draws the hero and the child as they were then.
    public let asOf: Date
    public let scenes: [SagaScene]

    public var seconds: TimeInterval {
        scenes.reduce(0) { $0 + $1.seconds }
    }

    /// `nil` when the period has no interval for this child (see `SagaPeriod.interval`).
    public static func make(
        events: [ProgressEvent],
        child: Child,
        period: SagaPeriod,
        catalog: ContentCatalog,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent,
        pacing: SagaPacing = .standard
    ) -> SagaStoryboard? {
        guard let interval = period.interval(for: child, catalog: catalog, now: now, calendar: calendar) else {
            return nil
        }
        let entries = Timeline.countedEntries(from: events, catalog: catalog)
            .filter { $0.childID == child.id && interval.holds($0.date) }
        let credits = SagaCredits(
            questsDone: entries.count { if case .quest = $0.kind { true } else { false } },
            bossesBeaten: entries.count { if case .boss = $0.kind { true } else { false } }
        )
        let shown = entries.filter { if case .quest = $0.kind { $0.photoID != nil } else { true } }
        let worlds = Dictionary(uniqueKeysWithValues: shown.compactMap { entry in
            UnlockRules.currentWorld(
                in: catalog, ageInMonths: child.sagaCompleted(.month, at: entry.date, calendar: calendar)
            ).map { (entry.id, $0) }
        })
        let cutter = Cutter(shown: shown, worlds: worlds, pacing: pacing, credits: credits)
        return SagaStoryboard(period: period, asOf: min(interval.end, now), scenes: cutter.cut())
    }
}

/// Fits a film's entries into its length.
private struct Cutter {
    let shown: [TimelineEntry]
    /// The child's world at each entry, by age.
    let worlds: [UUID: World]
    let pacing: SagaPacing
    let credits: SagaCredits

    func cut() -> [SagaScene] {
        let tiers: [[TimelineEntry]] = [
            shown.filter { if case .quest = $0.kind { true } else { false } },
            shown.filter { if case .boss = $0.kind { $0.photoID == nil } else { false } },
            shown.filter { if case .boss = $0.kind { $0.photoID != nil } else { false } }
        ]
        var dropped: Set<UUID> = []
        for tier in tiers {
            let scenes = { (keep: Int) in compose(dropping: dropped.union(Self.dropped(from: tier, keeping: keep))) }
            if let keep = Self.largest(upTo: tier.count, where: { Self.seconds(of: scenes($0)) <= pacing.maxSeconds }) {
                return scenes(keep)
            }
            dropped.formUnion(tier.map(\.id))
        }
        return shortenFirsts(compose(dropping: dropped))
    }

    /// The opening, the entries with a chapter card at each change of world, and the credits.
    private func compose(dropping dropped: Set<UUID>) -> [SagaScene] {
        let kept = shown.filter { !dropped.contains($0.id) }
        let hasChapters = Set(kept.compactMap { worlds[$0.id]?.id }).count > 1
        var scenes = [SagaScene(kind: .opening, seconds: pacing.opening)]
        var worldID: String?
        var chapter = 0
        for entry in kept {
            if hasChapters, let world = worlds[entry.id], world.id != worldID {
                worldID = world.id
                chapter += 1
                scenes.append(SagaScene(kind: .chapter(world, number: chapter), seconds: pacing.chapter))
            }
            scenes.append(SagaScene(kind: .entry(entry), seconds: seconds(of: entry)))
        }
        scenes.append(SagaScene(kind: .credits(credits), seconds: pacing.credits))
        return scenes
    }

    private func seconds(of entry: TimelineEntry) -> TimeInterval {
        switch entry.kind {
        case .quest: pacing.questPhoto
        case .boss: pacing.boss
        case .first: entry.photoID == nil ? pacing.firstWithoutPhoto : pacing.firstWithPhoto
        }
    }

    /// Shares the time left between the firsts: none gets more than its own length, the shortest keep theirs, and the
    /// rest get an equal cap, never below `firstFloor`.
    private func shortenFirsts(_ scenes: [SagaScene]) -> [SagaScene] {
        let isFirst: (SagaScene) -> Bool = {
            if case .entry(let entry) = $0.kind, case .first = entry.kind { true } else { false }
        }
        var left = pacing.maxSeconds - Self.seconds(of: scenes.filter { !isFirst($0) })
        var count = scenes.count(where: isFirst)
        var cap = TimeInterval.infinity
        for seconds in scenes.filter(isFirst).map(\.seconds).sorted() {
            let share = left / Double(count)
            if seconds > share {
                cap = share
                break
            }
            left -= seconds
            count -= 1
        }
        return scenes.map { scene in
            guard isFirst(scene) else { return scene }
            return SagaScene(kind: scene.kind, seconds: max(pacing.firstFloor, min(scene.seconds, cap)))
        }
    }

    /// The largest `keep` in `0...count` that fits, by bisection; `nil` when even none fits.
    private static func largest(upTo count: Int, where fits: (Int) -> Bool) -> Int? {
        if fits(count) { return count }
        guard fits(0) else { return nil }
        var fitting = 0
        var tooMany = count
        while tooMany - fitting > 1 {
            let middle = (fitting + tooMany) / 2
            if fits(middle) { fitting = middle } else { tooMany = middle }
        }
        return fitting
    }

    /// The ids left out when keeping `keep` of `items`, spread evenly, the first and the last kept.
    private static func dropped(from items: [TimelineEntry], keeping keep: Int) -> Set<UUID> {
        guard keep < items.count else { return [] }
        let kept: [Int] = switch keep {
        case ..<1: []
        case 1: [0]
        default: (0..<keep).map { Int((Double($0) * Double(items.count - 1) / Double(keep - 1)).rounded()) }
        }
        let keptIDs = Set(kept.map { items[$0].id })
        return Set(items.map(\.id)).subtracting(keptIDs)
    }

    private static func seconds(of scenes: [SagaScene]) -> TimeInterval {
        scenes.reduce(0) { $0 + $1.seconds }
    }
}
