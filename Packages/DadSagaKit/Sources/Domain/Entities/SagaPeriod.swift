import Foundation

/// The stretch of a child's life a saga film tells (ADR-0036).
///
/// Every boundary is at the start of a day, counted from the start of the child's birth day: a birth date keeps the
/// time of day it was entered, and a birthday must not begin in the afternoon.
public enum SagaPeriod: Hashable, Sendable {
    /// The nth year of life, from birthday n − 1 to birthday n. The first year starts at birth.
    case year(Int)
    /// The months the child spends in a world, by age: from its minimum age to the month after its maximum.
    case world(id: String)
    /// The whole saga.
    case everything

    /// When the period starts and ends; the end is not part of it. `nil` for a period that hasn't started, a year below
    /// one, or a world that isn't in the catalog or has no months.
    public func interval(
        for child: Child,
        catalog: ContentCatalog,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval? {
        let start: Date?
        let end: Date?
        switch self {
        case .year(let number):
            guard number >= 1 else { return nil }
            start = child.sagaDate(adding: .year, number - 1, calendar: calendar)
            end = child.sagaDate(adding: .year, number, calendar: calendar)
        case .world(let id):
            guard let world = catalog.worlds.first(where: { $0.id == id }) else { return nil }
            start = child.sagaDate(adding: .month, world.minAgeMonths, calendar: calendar)
            end = world.maxAgeMonths.map { child.sagaDate(adding: .month, $0 + 1, calendar: calendar) } ?? .distantFuture
        case .everything:
            start = .distantPast
            end = .distantFuture
        }
        guard let start, let end, start < end, start <= now else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// The periods a film can tell today: every year so far (the current one included), every world the child has
    /// been in, and everything.
    public static func available(
        for child: Child,
        catalog: ContentCatalog,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [SagaPeriod] {
        let candidates = (1...(child.sagaCompleted(.year, at: now, calendar: calendar) + 1)).map(SagaPeriod.year)
            + catalog.worlds.map { SagaPeriod.world(id: $0.id) }
        return candidates.filter { $0.interval(for: child, catalog: catalog, now: now, calendar: calendar) != nil }
            + [.everything]
    }
}

extension DateInterval {
    /// Whether `date` falls in the interval, its end excluded.
    func holds(_ date: Date) -> Bool {
        start <= date && date < end
    }
}

extension Child {
    /// The start of the day `value` units after the child's birth day.
    func sagaDate(adding unit: Calendar.Component, _ value: Int, calendar: Calendar) -> Date? {
        calendar.date(byAdding: unit, value: value, to: calendar.startOfDay(for: birthDate))
    }

    /// Completed units of age at `date`, counted from the start of the birth day. Never negative.
    func sagaCompleted(_ unit: Calendar.Component, at date: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: birthDate)
        return max(0, calendar.dateComponents([unit], from: start, to: date).value(for: unit) ?? 0)
    }
}
