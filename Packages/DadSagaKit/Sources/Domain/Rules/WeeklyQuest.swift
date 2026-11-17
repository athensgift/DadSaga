import Foundation

/// One quest suggested for a child for a whole calendar week (ADR-0023). Pure and the same in every process, so the app,
/// the widget and the weekly notification always agree on it.
///
/// Every card of the pool comes up once before any repeats. The order is a fixed shuffle per child, so siblings get
/// different quests. Nothing here looks at what was left undone: the suggestion never chases the dad.
public enum WeeklyQuest {
    /// The calendar week that contains `date`, as the user's calendar defines it (Monday to Sunday in Greece).
    public static func week(containing date: Date, calendar: Calendar) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 24 * 60 * 60)
    }

    /// The quest for this child in this week, or `nil` when the pool is empty.
    public static func pick(from pool: [Quest], childID: UUID, week: DateInterval, calendar: Calendar) -> Quest? {
        guard !pool.isEmpty else { return nil }
        let order = pool.sorted { lhs, rhs in
            let left = rank(lhs, childID: childID)
            let right = rank(rhs, childID: childID)
            return left == right ? lhs.id < rhs.id : left < right
        }
        let index = weekNumber(of: week, calendar: calendar) % order.count
        return order[(index + order.count) % order.count]
    }

    /// Whether the dad completed this quest with this child at some point in this week.
    public static func isDone(_ quest: Quest, childID: UUID, week: DateInterval, events: [ProgressEvent]) -> Bool {
        events.contains { event in
            event.kind == .quest(id: quest.id) && event.childID == childID
                && event.date >= week.start && event.date < week.end
        }
    }

    /// Weeks elapsed since a fixed reference week, counted by the calendar so daylight saving never shifts it.
    static func weekNumber(of week: DateInterval, calendar: Calendar) -> Int {
        let reference = Self.week(containing: Date(timeIntervalSinceReferenceDate: 0), calendar: calendar).start
        return calendar.dateComponents([.weekOfYear], from: reference, to: week.start).weekOfYear ?? 0
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
