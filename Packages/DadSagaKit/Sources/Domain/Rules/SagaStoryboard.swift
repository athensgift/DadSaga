import Foundation

/// What the parent making the film did in its period, for its credits: their own entries only, never totals for the
/// two parents (ADR-0065 §3.5), nor of XP or levels (ADR-0006).
public struct SagaCredits: Hashable, Sendable {
    public let questsDone: Int
    public let bossesBeaten: Int

    public init(questsDone: Int, bossesBeaten: Int) {
        self.questsDone = questsDone
        self.bossesBeaten = bossesBeaten
    }
}

/// Who a saga film is about: the hero of the parent making it and one of the family's children. The scenes are the
/// family's; the credits are the hero's (ADR-0065 §3.5).
public struct SagaCast: Hashable, Sendable {
    public let hero: PlayerProfile
    public let child: Child

    public init(hero: PlayerProfile, child: Child) {
        self.hero = hero
        self.child = child
    }
}

/// One scene of a saga film and how long it lasts.
public struct SagaScene: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case opening
        /// The child's world changed, by age. Numbered from 1 within the film; only in a film that spans two or more
        /// worlds.
        case chapter(World, number: Int)
        /// A first, a boss, or a quest with a photo: drawn over the entry's cover, if it has one.
        case entry(TimelineEntry)
        /// One of the entry's further photos, alone and without words, right after the entry's own scene (ADR-0042 §6).
        case photo(TimelineEntry, id: String)
        case credits(SagaCredits)
    }

    public let kind: Kind
    public let seconds: TimeInterval
}

/// The scenes of a saga film, oldest first (ADR-0036). Pure and deterministic.
///
/// Built from the family's entries, whoever recorded them, with a first once per child, the earlier capture (ADR-0065
/// §3.2, §3.3); the credits count only the entries of the parent making it. Quests
/// without a photo are left out; every first is kept. An entry's scene is followed by up to
/// `SagaPacing.morePhotosPerEntry` of its further photos, in the dad's order. A film over `SagaPacing.maxSeconds`
/// loses, each evenly and keeping the first and the last, further photos, then quests, then bosses without a photo,
/// then bosses with one. Only then do firsts get shorter, down to `firstFloor`; firsts alone can take a film past its
/// length.
public struct SagaStoryboard: Hashable, Sendable {
    public let period: SagaPeriod
    /// The moment the film tells the saga as of: the end of its period, or now if the period is still going. The
    /// opening draws the hero and the child as they were then.
    public let asOf: Date
    /// The child's age at the last moment of the period, or now: how the film draws them. Before the birth for a film
    /// of a child not born yet, or of the world before birth (ADR-0053 §2).
    public let childAge: ChildAge
    /// The days the film covers, for the opening's dates (ADR-0041 §2): from the start of its period to its last
    /// moment, or to now while it is still going. The whole saga starts on the child's birth day, or on the first
    /// entry's day if one is earlier; for a child not born yet, on the first entry's day.
    public let span: DateInterval
    public let scenes: [SagaScene]

    public var seconds: TimeInterval {
        scenes.reduce(0) { $0 + $1.seconds }
    }

    /// `nil` when the period has no interval for this child (see `SagaPeriod.interval`).
    public static func make(
        events: [ProgressEvent],
        cast: SagaCast,
        period: SagaPeriod,
        catalog: ContentCatalog,
        now: Date,
        timeZone: TimeZone = .autoupdatingCurrent,
        pacing: SagaPacing = .standard
    ) -> SagaStoryboard? {
        let child = cast.child
        guard let interval = period.interval(for: child, catalog: catalog, now: now, timeZone: timeZone) else {
            return nil
        }
        let entries = Timeline.familyEntries(from: events, catalog: catalog)
            .filter { $0.childID == child.id && interval.holds($0.date) }
        let own = entries.filter { $0.authorID == cast.hero.id }
        let credits = SagaCredits(
            questsDone: own.count { if case .quest = $0.kind { true } else { false } },
            bossesBeaten: own.count { if case .boss = $0.kind { true } else { false } }
        )
        let shown = entries.filter { if case .quest = $0.kind { !$0.photoIDs.isEmpty } else { true } }
        // An entry dated before the birth day is before birth: it belongs to the world before birth.
        let worlds = Dictionary(uniqueKeysWithValues: shown.compactMap { entry in
            UnlockRules.currentWorld(in: catalog, age: child.age(on: CalendarDay(entry.date, in: timeZone)))
                .map { (entry.id, $0) }
        })
        let cutter = Cutter(shown: shown, worlds: worlds, pacing: pacing, credits: credits)
        let asOf = min(interval.end, now)
        let lastMoment = asOf == interval.end ? asOf.addingTimeInterval(-1) : asOf
        let firstDay = entries.map(\.date).min().map { CalendarDay($0, in: timeZone).start(in: timeZone) }
        let birth = child.birthDay?.start(in: timeZone) ?? firstDay ?? lastMoment
        let start = min(max(interval.start, birth), firstDay ?? .distantFuture)
        return SagaStoryboard(
            period: period,
            asOf: asOf,
            childAge: child.age(on: CalendarDay(lastMoment, in: timeZone)),
            span: DateInterval(start: start, end: max(start, lastMoment)),
            scenes: cutter.cut()
        )
    }
}

/// Fits a film's entries into its length.
private struct Cutter {
    /// One scene the cutter may leave out: an entry's own scene, or one of its further photos.
    struct Shot: Hashable {
        let entryID: UUID
        /// `nil` for the entry's own scene.
        let photoID: String?
    }

    let shown: [TimelineEntry]
    /// The child's world at each entry, by age.
    let worlds: [UUID: World]
    let pacing: SagaPacing
    let credits: SagaCredits

    func cut() -> [SagaScene] {
        let entries = { (include: (TimelineEntry) -> Bool) in
            shown.filter(include).map { Shot(entryID: $0.id, photoID: nil) }
        }
        let tiers: [[Shot]] = [
            shown.flatMap { entry in morePhotos(of: entry).map { Shot(entryID: entry.id, photoID: $0) } },
            entries { if case .quest = $0.kind { true } else { false } },
            entries { if case .boss = $0.kind { $0.photoIDs.isEmpty } else { false } },
            entries { if case .boss = $0.kind { !$0.photoIDs.isEmpty } else { false } }
        ]
        var dropped: Set<Shot> = []
        for tier in tiers {
            let scenes = { (keep: Int) in compose(dropping: dropped.union(Self.dropped(from: tier, keeping: keep))) }
            if let keep = Self.largest(upTo: tier.count, where: { Self.seconds(of: scenes($0)) <= pacing.maxSeconds }) {
                return scenes(keep)
            }
            dropped.formUnion(tier)
        }
        return shortenFirsts(compose(dropping: dropped))
    }

    /// The further photos that may follow the entry's scene.
    private func morePhotos(of entry: TimelineEntry) -> [String] {
        Array(entry.photoIDs.dropFirst().prefix(pacing.morePhotosPerEntry))
    }

    /// The opening, the entries with a chapter card at each change of world and their further photos, and the credits.
    /// An entry left out takes its further photos with it.
    private func compose(dropping dropped: Set<Shot>) -> [SagaScene] {
        let kept = shown.filter { !dropped.contains(Shot(entryID: $0.id, photoID: nil)) }
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
            for photoID in morePhotos(of: entry) where !dropped.contains(Shot(entryID: entry.id, photoID: photoID)) {
                scenes.append(SagaScene(kind: .photo(entry, id: photoID), seconds: pacing.photo))
            }
        }
        scenes.append(SagaScene(kind: .credits(credits), seconds: pacing.credits))
        return scenes
    }

    private func seconds(of entry: TimelineEntry) -> TimeInterval {
        switch entry.kind {
        case .quest: pacing.photo
        case .boss: pacing.boss
        case .first: entry.photoIDs.isEmpty ? pacing.firstWithoutPhoto : pacing.firstWithPhoto
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

    /// The shots left out when keeping `keep` of `items`, spread evenly, the first and the last kept.
    private static func dropped(from items: [Shot], keeping keep: Int) -> Set<Shot> {
        guard keep < items.count else { return [] }
        let kept: [Int] = switch keep {
        case ..<1: []
        case 1: [0]
        default: (0..<keep).map { Int((Double($0) * Double(items.count - 1) / Double(keep - 1)).rounded()) }
        }
        return Set(items).subtracting(kept.map { items[$0] })
    }

    private static func seconds(of scenes: [SagaScene]) -> TimeInterval {
        scenes.reduce(0) { $0 + $1.seconds }
    }
}

/// An entry with more further photos than places in its film (ADR-0047 §2): the photos the device may choose among.
public struct SagaPhotoChoice: Hashable, Sendable {
    public let entryID: UUID
    /// The entry's further photos, in the dad's order.
    public let candidates: [String]
    /// The photos that fill its places by position, in the film's order.
    public let chosen: [String]
}

public extension SagaStoryboard {
    /// The entries whose further photos don't all fit in the film, oldest first.
    var photoChoices: [SagaPhotoChoice] {
        var entries: [TimelineEntry] = []
        var chosen: [UUID: [String]] = [:]
        for scene in scenes {
            guard case .photo(let entry, let id) = scene.kind else { continue }
            if chosen[entry.id] == nil {
                entries.append(entry)
            }
            chosen[entry.id, default: []].append(id)
        }
        return entries.compactMap { entry in
            let candidates = Array(entry.photoIDs.dropFirst())
            let places = chosen[entry.id] ?? []
            guard places.count < candidates.count else { return nil }
            return SagaPhotoChoice(entryID: entry.id, candidates: candidates, chosen: places)
        }
    }

    /// The same film with each entry's places filled by its best rated further photos: moments before utility photos,
    /// then the higher score, played in the dad's order. Every scene keeps its place and its length. An entry keeps its
    /// photos as they are when any of its candidates has no rating, or all of them rate the same.
    func choosingPhotos(by ratings: [String: PhotoRating]) -> SagaStoryboard {
        var refill: [UUID: [String]] = [:]
        for choice in photoChoices {
            let rated = choice.candidates.compactMap { ratings[$0] }
            guard rated.count == choice.candidates.count, Set(rated).count > 1 else { continue }
            refill[choice.entryID] = zip(choice.candidates.indices, rated)
                .sorted { first, second in
                    let (one, two) = (first.1, second.1)
                    if one.isUtility != two.isUtility { return !one.isUtility }
                    if one.score != two.score { return one.score > two.score }
                    return first.0 < second.0
                }
                .prefix(choice.chosen.count)
                .map(\.0)
                .sorted()
                .map { choice.candidates[$0] }
        }
        guard !refill.isEmpty else { return self }
        var next: [UUID: Int] = [:]
        let refilled = scenes.map { scene -> SagaScene in
            guard case .photo(let entry, _) = scene.kind, let photos = refill[entry.id] else { return scene }
            let index = next[entry.id, default: 0]
            next[entry.id] = index + 1
            return SagaScene(kind: .photo(entry, id: photos[index]), seconds: scene.seconds)
        }
        return SagaStoryboard(
            period: period, asOf: asOf, childAge: childAge, span: span, scenes: refilled
        )
    }
}
