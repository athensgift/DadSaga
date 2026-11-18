import Application
import Domain
import Foundation
import Localization

/// The words of the weekly notification and of everything around it, in the dad's language (ADR-0024).
/// No counts, no "you haven't", nothing left: it only suggests (ADR-0006).
public struct WeeklyReminderText: ReminderTextProvider {
    let locale: Locale

    public init(locale: Locale = .current) {
        self.locale = locale
    }

    public func title() -> String {
        strings.text("This week's quest")
    }

    public func body(questTitle: LocalizedText, childName: String?) -> String {
        let quest = questTitle.resolved(for: locale)
        return childName.map { "\($0) · \(quest)" } ?? quest
    }

    /// The days of the week in the calendar's order for this language, Monday first in Greece.
    func weekdays(calendar: Calendar) -> [WeekdayOption] {
        var calendar = calendar
        calendar.locale = locale
        let names = calendar.standaloneWeekdaySymbols
        return (0..<7).map { offset in
            let weekday = (calendar.firstWeekday - 1 + offset) % 7 + 1
            return WeekdayOption(id: weekday, name: names[weekday - 1].capitalized(with: locale))
        }
    }

    /// e.g. "Σάββατο 10:00", "Saturday 10:00 AM": the time as the language writes it.
    func when(weekday: Int, hour: Int, minute: Int, calendar: Calendar) -> String {
        let day = weekdays(calendar: calendar).first { $0.id == weekday }?.name ?? ""
        var timeCalendar = calendar
        timeCalendar.locale = locale
        let date = timeCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: hour, minute: minute))
        let time = date.map {
            $0.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: timeCalendar,
                                          timeZone: timeCalendar.timeZone))
        } ?? ""
        return day + " " + time
    }

    var strings: Strings { Strings(locale: locale) }
}

public struct WeekdayOption: Hashable, Identifiable, Sendable {
    /// 1 = Sunday … 7 = Saturday.
    public let id: Int
    public let name: String
}
