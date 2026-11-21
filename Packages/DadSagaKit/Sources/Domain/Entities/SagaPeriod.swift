import Foundation

/// The stretch of a child's life a saga film tells (ADR-0036).
///
/// Every boundary is at the start of a day in the phone's time zone, on the day the child turns that many months
/// (`Child.day(atMonths:)`), so periods agree with the child's age everywhere (ADR-0048 §2).
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
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> DateInterval? {
        let start: Date
        let end: Date
        switch self {
        case .year(let number):
            guard number >= 1 else { return nil }
            start = child.day(atMonths: 12 * (number - 1)).start(in: timeZone)
            end = child.day(atMonths: 12 * number).start(in: timeZone)
        case .world(let id):
            guard let world = catalog.world(id: id) else { return nil }
            start = child.day(atMonths: world.minAgeMonths).start(in: timeZone)
            end = world.maxAgeMonths.map { child.day(atMonths: $0 + 1).start(in: timeZone) } ?? .distantFuture
        case .everything:
            start = .distantPast
            end = .distantFuture
        }
        guard start < end, start <= now else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// The periods a film can tell today: every year so far (the current one included) and every world the child has
    /// been in, each only with something the dad did with the child in it, and everything. A film is never offered
    /// for a stretch with nothing in it (ADR-0006).
    public static func available(
        for child: Child,
        events: [ProgressEvent],
        catalog: ContentCatalog,
        now: Date,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> [SagaPeriod] {
        let dates = Timeline.countedEntries(from: events, catalog: catalog)
            .filter { $0.childID == child.id }
            .map(\.date)
        let years = child.ageInMonths(on: CalendarDay(now, in: timeZone)) / 12
        let candidates = (1...(years + 1)).map(SagaPeriod.year)
            + catalog.worlds.map { SagaPeriod.world(id: $0.id) }
        return candidates.filter { period in
            guard let interval = period.interval(for: child, catalog: catalog, now: now, timeZone: timeZone) else {
                return false
            }
            return dates.contains(where: interval.holds)
        } + [.everything]
    }
}

extension DateInterval {
    /// Whether `date` falls in the interval, its end excluded.
    func holds(_ date: Date) -> Bool {
        start <= date && date < end
    }
}
