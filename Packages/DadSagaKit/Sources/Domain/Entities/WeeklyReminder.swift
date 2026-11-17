import Foundation

/// The dad's choice about the one weekly notification with the quest of the week (ADR-0024).
public struct WeeklyReminder: Hashable, Sendable {
    /// Off until the dad says yes.
    public var isEnabled: Bool
    /// 1 = Sunday … 7 = Saturday, as `Calendar` counts weekdays.
    public var weekday: Int { didSet { weekday = min(max(weekday, 1), 7) } }
    public var hour: Int { didSet { hour = min(max(hour, 0), 23) } }
    public var minute: Int { didSet { minute = min(max(minute, 0), 59) } }
    /// Whether the dad already answered the offer on home, either way. It is never shown twice.
    public var wasOffered: Bool

    /// Saturday 10:00, off, not offered yet.
    public static let `default` = WeeklyReminder(isEnabled: false, weekday: 7, hour: 10, minute: 0, wasOffered: false)

    public init(isEnabled: Bool, weekday: Int, hour: Int, minute: Int, wasOffered: Bool) {
        self.isEnabled = isEnabled
        self.weekday = min(max(weekday, 1), 7)
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
        self.wasOffered = wasOffered
    }

    /// The next `count` times it is due, strictly after `date`, one a week, in the calendar's time zone.
    public func nextDates(after date: Date, count: Int, calendar: Calendar) -> [Date] {
        let components = DateComponents(hour: hour, minute: minute, weekday: weekday)
        var dates: [Date] = []
        var cursor = date
        while dates.count < count,
              let next = calendar.nextDate(after: cursor, matching: components, matchingPolicy: .nextTime) {
            dates.append(next)
            cursor = next
        }
        return dates
    }
}
