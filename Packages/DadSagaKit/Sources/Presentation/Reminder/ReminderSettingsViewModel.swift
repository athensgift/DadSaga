import Application
import Domain
import Foundation
import Localization
import Observation

/// The use cases behind the weekly reminder, shared by home's offer and the settings screen.
public struct ReminderUseCases: Sendable {
    let get: any GetWeeklyReminderUseCase
    let update: any UpdateWeeklyReminderUseCase

    public init(get: any GetWeeklyReminderUseCase, update: any UpdateWeeklyReminderUseCase) {
        self.get = get
        self.update = update
    }
}

/// Presenter for the weekly reminder settings: on/off, day and time (ADR-0024).
@MainActor
@Observable
public final class ReminderSettingsViewModel: Identifiable {
    public private(set) var isLoaded = false
    public private(set) var isEnabled = false
    public private(set) var weekday = WeeklyReminder.default.weekday
    public private(set) var hour = WeeklyReminder.default.hour
    public private(set) var minute = WeeklyReminder.default.minute
    /// Shown when the dad wants it but iOS does not allow notifications.
    public private(set) var deniedMessage: String?
    public let labels: ReminderSettingsLabels
    public let weekdays: [WeekdayOption]

    private let useCases: ReminderUseCases
    private let text: WeeklyReminderText
    private let strings: Strings
    private let now: @Sendable () -> Date
    private var reminder = WeeklyReminder.default
    /// Each save takes a number; only the latest one may update the screen, so a slow earlier save that finishes last
    /// cannot put back an older day or time.
    private var saveGeneration = 0

    public init(
        useCases: ReminderUseCases,
        locale: Locale = .current,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.useCases = useCases
        self.now = now
        let text = WeeklyReminderText(locale: locale)
        self.text = text
        let strings = Strings(locale: locale)
        self.strings = strings
        weekdays = text.weekdays(calendar: calendar)
        labels = ReminderSettingsLabels(
            title: strings.text("Weekly reminder"),
            toggle: strings.text("This week's quest"),
            explanation: strings.text(
                """
                One notification a week with this week's quest. If you've already done it that week, you won't get \
                it.
                """
            ),
            day: strings.text("Day"),
            time: strings.text("Time"),
            openSettings: strings.text("Open iPhone Settings")
        )
    }

    public func onAppear() async {
        let generation = saveGeneration
        let status = await useCases.get.execute()
        guard generation == saveGeneration else { return }
        apply(status)
    }

    public func setEnabled(_ enabled: Bool) async {
        reminder.isEnabled = enabled
        await save()
    }

    public func setWeekday(_ weekday: Int) async {
        reminder.weekday = weekday
        await save()
    }

    public func setTime(hour: Int, minute: Int) async {
        reminder.hour = hour
        reminder.minute = minute
        await save()
    }

    private func save() async {
        saveGeneration += 1
        let generation = saveGeneration
        isEnabled = reminder.isEnabled
        weekday = reminder.weekday
        hour = reminder.hour
        minute = reminder.minute
        let status = await useCases.update.execute(reminder, on: now())
        guard generation == saveGeneration else { return }
        apply(status)
    }

    private func apply(_ status: WeeklyReminderStatus) {
        reminder = status.reminder
        isEnabled = status.reminder.isEnabled
        weekday = status.reminder.weekday
        hour = status.reminder.hour
        minute = status.reminder.minute
        deniedMessage = status.reminder.isEnabled && status.authorization == .denied
            ? strings.text("DadSaga notifications are turned off in iPhone Settings.")
            : nil
        isLoaded = true
    }
}

public struct ReminderSettingsLabels: Equatable, Sendable {
    public let title: String
    public let toggle: String
    public let explanation: String
    public let day: String
    public let time: String
    public let openSettings: String
}
