import Foundation

/// A day worth a saga film: a birthday, or the child growing into the next world (ADR-0036).
public struct SagaOccasion: Hashable, Identifiable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// The child turned `years`. The film tells the year that ended.
        case birthday(years: Int)
        /// The child grew out of `left`, by age. Never about quests or bosses done (ADR-0006).
        case newWorld(left: World)
    }

    /// Stable, so an answer to the offer is remembered for this occasion only.
    public let id: String
    /// `id`, and the ids this occasion had before its world was renamed: an answer given under any of them still holds
    /// (ADR-0048 §5).
    public let answerIDs: Set<String>
    public let kind: Kind
    public let childID: UUID
    /// The start of the day it happens.
    public let date: Date
    /// What the film offered for this occasion tells.
    public let period: SagaPeriod

    public init(
        id: String,
        kind: Kind,
        childID: UUID,
        date: Date,
        period: SagaPeriod,
        formerIDs: [String] = []
    ) {
        self.id = id
        answerIDs = Set([id] + formerIDs)
        self.kind = kind
        self.childID = childID
        self.date = date
        self.period = period
    }

    /// On the same day, leaving a world comes before a birthday: its film tells the longer story.
    fileprivate var rank: Int {
        switch kind {
        case .birthday: 0
        case .newWorld: 1
        }
    }
}

/// When home may gently offer a film (ADR-0036, ADR-0006): from the occasion's day for `windowDays` days, only if the
/// dad has something from that period with the child. Never a deadline: the offer just stops showing.
public enum SagaOccasions {
    public static let windowDays = 30

    /// The one occasion to offer on `now`: the newest showing, unless the dad has answered it. An older occasion never
    /// takes the place of an answered one, so there is only ever one offer at a time.
    public static func latest(
        for child: Child,
        events: [ProgressEvent],
        catalog: ContentCatalog,
        on now: Date,
        answered: Set<String> = [],
        timeZone: TimeZone = .autoupdatingCurrent,
        windowDays: Int = windowDays
    ) -> SagaOccasion? {
        let dates = Timeline.countedEntries(from: events, catalog: catalog)
            .filter { $0.childID == child.id }
            .map(\.date)
        let newest = occasions(for: child, catalog: catalog, now: now, timeZone: timeZone)
            .filter { occasion in
                let closes = CalendarDay(occasion.date, in: timeZone).adding(days: windowDays).start(in: timeZone)
                guard occasion.date <= now,
                      now < closes,
                      let interval = occasion.period.interval(for: child, catalog: catalog, now: now, timeZone: timeZone)
                else { return false }
                return dates.contains(where: interval.holds)
            }
            .max { ($0.date, $0.rank) < ($1.date, $1.rank) }
        guard let newest, answered.isDisjoint(with: newest.answerIDs) else { return nil }
        return newest
    }

    /// The one occasion to offer a family on `now` (ADR-0037 §5): the newest of any child. On the same day children go
    /// in family order, so twins are offered one after the other. An older occasion never takes the place of an
    /// answered one, whichever child it belongs to.
    public static func latest(
        forFamily children: [Child],
        events: [ProgressEvent],
        catalog: ContentCatalog,
        on now: Date,
        answered: Set<String> = [],
        timeZone: TimeZone = .autoupdatingCurrent,
        windowDays: Int = windowDays
    ) -> SagaOccasion? {
        let newest = children.compactMap {
            latest(for: $0, events: events, catalog: catalog, on: now, timeZone: timeZone, windowDays: windowDays)
        }
        guard let date = newest.map(\.date).max() else { return nil }
        return newest.first { $0.date == date && answered.isDisjoint(with: $0.answerIDs) }
    }

    /// Every birthday so far, and the end of every world: a world before birth ends on the birth day (ADR-0051 §2).
    /// None before the birth.
    private static func occasions(
        for child: Child,
        catalog: ContentCatalog,
        now: Date,
        timeZone: TimeZone
    ) -> [SagaOccasion] {
        guard let birthDay = child.birthDay, let months = child.age(on: CalendarDay(now, in: timeZone)).months else {
            return []
        }
        let birthdays = (0..<(months / 12)).map { index in
            let years = index + 1
            return SagaOccasion(
                id: "\(child.id.uuidString)/birthday/\(years)",
                kind: .birthday(years: years),
                childID: child.id,
                date: birthDay.adding(months: 12 * years).start(in: timeZone),
                period: .year(years)
            )
        }
        let worldEnds = catalog.worlds.compactMap { world -> SagaOccasion? in
            let ends: CalendarDay
            switch world.span {
            case .beforeBirth: ends = birthDay
            case .months(_, let max?): ends = birthDay.adding(months: max + 1)
            case .months(_, nil): return nil
            }
            let id = { (worldID: String) in "\(child.id.uuidString)/world/\(worldID)" }
            return SagaOccasion(
                id: id(world.id),
                kind: .newWorld(left: world),
                childID: child.id,
                date: ends.start(in: timeZone),
                period: .world(id: world.id),
                formerIDs: world.formerIDs.map(id)
            )
        }
        return birthdays + worldEnds
    }
}
