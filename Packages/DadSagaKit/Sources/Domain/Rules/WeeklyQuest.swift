import Foundation

/// One quest suggested for a child for a whole calendar week (ADR-0023). Pure and the same in every process, so the app,
/// the widget and the weekly notification always agree on it.
///
/// It is the card on offer that came up longest ago, one that never came up first (ADR-0072). Between cards that never
/// came up a fixed shuffle per child decides, so siblings get different quests. Nothing here looks at what was left
/// undone: the suggestion never chases the dad.
public enum WeeklyQuest {
    /// The calendar week that contains `date`, as the user's calendar defines it (Monday to Sunday in Greece).
    public static func week(containing date: Date, calendar: Calendar) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 24 * 60 * 60)
    }

    /// The quest for this child in this week, or `nil` when none is on offer: no world fits the child's age.
    ///
    /// When a card came up is worked out, not stored: the weeks are walked from the birth week to this one. Before the
    /// birth the cards on offer don't change with age, so there it is week number mod count.
    public static func pick(
        for child: Child,
        family: FamilyFacts,
        in catalog: ContentCatalog,
        week: DateInterval,
        calendar: Calendar
    ) -> Quest? {
        var pools = Pools(child: child, family: family, catalog: catalog)
        let offered = pools.pool(at: age(of: child, weekStarting: week.start, calendar: calendar))
        guard !offered.isEmpty else { return nil }
        let number = weekNumber(of: week, calendar: calendar)
        guard let birthDay = child.birthDay else { return cycled(offered, number) }
        let birthWeek = Self.week(containing: birthDay.start(in: calendar.timeZone), calendar: calendar)
        let first = weekNumber(of: birthWeek, calendar: calendar)
        guard number >= first else { return cycled(offered, number) }

        var lastShown: [String: Int] = [:]
        for past in first..<number {
            guard let start = calendar.date(byAdding: .weekOfYear, value: past - number, to: week.start) else { continue }
            let pool = pools.pool(at: age(of: child, weekStarting: start, calendar: calendar))
            if let shown = longestAgo(pool, lastShown) { lastShown[shown.id] = past }
        }
        return longestAgo(offered, lastShown)
    }

    /// Whether this quest was completed with this child at some point in this week, in `events`: the parent's own, as a
    /// partner's quest is never the dad's (ADR-0065 §3.3).
    public static func isDone(_ quest: Quest, childID: UUID, week: DateInterval, events: [ProgressEvent]) -> Bool {
        events.contains { event in
            guard case .quest(let id) = event.kind, quest.has(id: id) else { return false }
            return event.childID == childID
                && event.date >= week.start && event.date < week.end
        }
    }

    /// Weeks elapsed since the week of a fixed day, 1 January 2001, counted by the calendar so daylight saving never
    /// shifts it. The day is the same one in every time zone, so a trip changes no week's number.
    public static func weekNumber(of week: DateInterval, calendar: Calendar) -> Int {
        let gmtDay = CalendarDay(Date(timeIntervalSinceReferenceDate: 0), in: .gmt)
        let reference = Self.week(containing: gmtDay.start(in: calendar.timeZone), calendar: calendar).start
        return calendar.dateComponents([.weekOfYear], from: reference, to: week.start).weekOfYear ?? 0
    }

    /// The age a week's quest is picked at: on the day the week starts, so a birthday mid-week does not swap the card;
    /// in the week of the birth, on the birth day, so a baby already here gets no card for before the birth.
    private static func age(of child: Child, weekStarting start: Date, calendar: Calendar) -> ChildAge {
        let firstDay = CalendarDay(start, in: calendar.timeZone)
        guard let birthDay = child.birthDay, birthDay > firstDay, birthDay < firstDay.adding(days: 7) else {
            return child.age(on: firstDay)
        }
        return child.age(on: birthDay)
    }

    /// The first of `pool`, in its order, that came up longest ago. One that never came up beats all that have.
    private static func longestAgo(_ pool: [Quest], _ lastShown: [String: Int]) -> Quest? {
        var found: (quest: Quest, week: Int)?
        for quest in pool {
            guard let week = lastShown[quest.id] else { return quest }
            if found.map({ week < $0.week }) ?? true { found = (quest, week) }
        }
        return found?.quest
    }

    private static func cycled(_ pool: [Quest], _ number: Int) -> Quest {
        pool[(number % pool.count + pool.count) % pool.count]
    }

    /// The cards on offer to a child at each age, in the child's shuffle. Each age is worked out once: a walk crosses
    /// hundreds of weeks and few ages.
    private struct Pools {
        let child: Child
        let family: FamilyFacts
        let catalog: ContentCatalog
        private var byAge: [ChildAge: [Quest]] = [:]

        init(child: Child, family: FamilyFacts, catalog: ContentCatalog) {
            self.child = child
            self.family = family
            self.catalog = catalog
        }

        /// Only a quest offered to this family: never a retired one or one for someone else (ADR-0053).
        mutating func pool(at age: ChildAge) -> [Quest] {
            if let pool = byAge[age] { return pool }
            var pool: [Quest] = []
            if !UnlockRules.isBeyondContent(catalog, age: age), let world = UnlockRules.currentWorld(in: catalog, age: age) {
                let offered = UnlockRules.quests(for: world, in: catalog, age: age, family: family)
                let ranked: [(quest: Quest, rank: UInt64)] = offered.map { ($0, WeeklyQuest.rank($0, childID: child.id)) }
                pool = ranked.sorted { lhs, rhs in (lhs.rank, lhs.quest.id) < (rhs.rank, rhs.quest.id) }.map(\.quest)
            }
            byAge[age] = pool
            return pool
        }
    }

    /// A stable position for a quest in a child's shuffle. FNV-1a, because `Hasher` is seeded per process, then a
    /// finalizer: ids often differ only in their last character, and plain FNV-1a would order them the same way for
    /// every child.
    static func rank(_ quest: Quest, childID: UUID) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in "\(childID.uuidString)/\(quest.id)".utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        hash ^= hash >> 33
        hash = hash &* 0xff51_afd7_ed55_8ccd
        hash ^= hash >> 33
        hash = hash &* 0xc4ce_b9fe_1a85_ec53
        hash ^= hash >> 33
        return hash
    }
}
