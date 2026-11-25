import Domain
import Foundation

/// The reminder settings together with what iOS allows, for the offer on home and the settings screen (ADR-0024).
public struct WeeklyReminderStatus: Hashable, Sendable {
    public let reminder: WeeklyReminder
    public let authorization: NotificationAuthorization

    public init(reminder: WeeklyReminder, authorization: NotificationAuthorization) {
        self.reminder = reminder
        self.authorization = authorization
    }

    /// The offer on home: only while the dad has not answered it and iOS has never asked him.
    public var canOffer: Bool {
        !reminder.wasOffered && authorization == .notDetermined
    }
}

public protocol GetWeeklyReminderUseCase: Sendable {
    func execute() async -> WeeklyReminderStatus
}

public struct DefaultGetWeeklyReminderUseCase: GetWeeklyReminderUseCase {
    private let settings: any ReminderSettingsRepository
    private let scheduler: any NotificationScheduler

    public init(settings: any ReminderSettingsRepository, scheduler: any NotificationScheduler) {
        self.settings = settings
        self.scheduler = scheduler
    }

    public func execute() async -> WeeklyReminderStatus {
        WeeklyReminderStatus(reminder: await settings.fetch(), authorization: await scheduler.authorization())
    }
}

/// Saves the dad's choice, asks iOS once if he turned it on, and reschedules.
public protocol UpdateWeeklyReminderUseCase: Sendable {
    func execute(_ reminder: WeeklyReminder, on date: Date) async -> WeeklyReminderStatus
}

public struct DefaultUpdateWeeklyReminderUseCase: UpdateWeeklyReminderUseCase {
    private let settings: any ReminderSettingsRepository
    private let scheduler: any NotificationScheduler
    private let schedule: any ScheduleWeeklyRemindersUseCase
    /// Runs one change at a time, in the order the dad made them, so an older change can never be saved after a newer
    /// one. Shared by every copy of this use case; the app keeps one instance.
    private let queue = SerialQueue()

    public init(
        settings: any ReminderSettingsRepository,
        scheduler: any NotificationScheduler,
        schedule: any ScheduleWeeklyRemindersUseCase
    ) {
        self.settings = settings
        self.scheduler = scheduler
        self.schedule = schedule
    }

    public func execute(_ reminder: WeeklyReminder, on date: Date) async -> WeeklyReminderStatus {
        await queue.run { await update(reminder, on: date) }
    }

    private func update(_ reminder: WeeklyReminder, on date: Date) async -> WeeklyReminderStatus {
        var reminder = reminder
        reminder.wasOffered = true
        await settings.save(reminder)
        var authorization = await scheduler.authorization()
        if reminder.isEnabled, authorization == .notDetermined {
            authorization = await scheduler.requestAuthorization() ? .allowed : .denied
        }
        await schedule.execute(on: date)
        return WeeklyReminderStatus(reminder: reminder, authorization: authorization)
    }
}

/// Schedules the next four weekly notifications, each with the quest of its own week (ADR-0024). A week that has had
/// its note gets no other, whatever the dad changes.
/// Run whenever the app leaves the foreground, after every settings change, and when permission or the family changed.
public protocol ScheduleWeeklyRemindersUseCase: Sendable {
    func execute(on date: Date) async
}

public struct DefaultScheduleWeeklyRemindersUseCase: ScheduleWeeklyRemindersUseCase {
    /// A dad who stops opening the app gets this many notes, then silence.
    public static let weeksAhead = 4

    private let settings: any ReminderSettingsRepository
    private let scheduler: any NotificationScheduler
    private let profileRepository: any ProfileRepository
    private let highlights: any GetWeeklyHighlightsUseCase
    private let text: any ReminderTextProvider
    private let calendar: Calendar
    /// Runs one reschedule at a time, so a slow run can never add its notifications after a newer run cleared them.
    /// Shared by every copy of this use case; the app keeps one instance.
    private let queue = SerialQueue()

    public init(
        settings: any ReminderSettingsRepository,
        scheduler: any NotificationScheduler,
        profileRepository: any ProfileRepository,
        highlights: any GetWeeklyHighlightsUseCase,
        text: any ReminderTextProvider,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.settings = settings
        self.scheduler = scheduler
        self.profileRepository = profileRepository
        self.highlights = highlights
        self.text = text
        self.calendar = calendar
    }

    public func execute(on date: Date) async {
        await queue.run { await reschedule(on: date) }
    }

    private func reschedule(on date: Date) async {
        let arrived = await arrivedThisWeek(on: date)
        // A saga that cannot be read is not an empty one: the notes already waiting stay as they are (ADR-0026).
        guard let pending = try? await pendingReminders(after: date, weekHasNote: !arrived.isEmpty) else { return }
        await scheduler.replacePending(with: pending)
        await settings.saveNoteTimes(arrived + pending.map(\.time))
    }

    /// The notes that were scheduled for this week and are due by now. By the clock on the wall, as iOS delivers them.
    private func arrivedThisWeek(on date: Date) async -> [DateComponents] {
        let week = WeeklyQuest.week(containing: date, calendar: calendar)
        return await settings.noteTimes().filter { time in
            guard let due = calendar.date(from: time) else { return false }
            return due >= week.start && due <= date
        }
    }

    private func pendingReminders(after date: Date, weekHasNote: Bool) async throws -> [PendingReminder] {
        let reminder = await settings.fetch()
        guard reminder.isEnabled, await scheduler.authorization() == .allowed,
              let children = try await profileRepository.fetchProfile()?.children, !children.isEmpty
        else { return [] }
        let thisWeek = WeeklyQuest.week(containing: date, calendar: calendar)
        var pending: [PendingReminder] = []
        for fireDate in reminder.nextDates(after: date, count: Self.weeksAhead, calendar: calendar) {
            if weekHasNote, fireDate < thisWeek.end { continue }
            if let item = try await pendingReminder(on: fireDate, children: children) { pending.append(item) }
        }
        return pending
    }

    /// The weeks take turns between the children; a child with no quest (past every world) gives the turn to the next.
    /// `nil` when the quest of the week is already done, or no child has a quest.
    private func pendingReminder(on fireDate: Date, children: [Child]) async throws -> PendingReminder? {
        let week = WeeklyQuest.week(containing: fireDate, calendar: calendar)
        let start = WeeklyQuest.weekNumber(of: week, calendar: calendar)
        for offset in children.indices {
            let child = children[((start + offset) % children.count + children.count) % children.count]
            guard let found = try await highlights.execute(childID: child.id, on: fireDate, photoMaxPixelSize: nil),
                  case .suggested(let quest, let isDone) = found.quest
            else { continue }
            if isDone { return nil }
            return PendingReminder(
                time: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                title: text.title(),
                body: text.body(questTitle: quest.title, childName: children.count > 1 ? child.name : nil),
                link: .quest(id: quest.id, childID: child.id)
            )
        }
        return nil
    }
}

/// Schedules the weekly notes again and takes away those already shown, when the family they name is no longer the
/// same: a note names a child and links to them.
public protocol RenewWeeklyRemindersUseCase: Sendable {
    func execute(on date: Date) async
}

public struct DefaultRenewWeeklyRemindersUseCase: RenewWeeklyRemindersUseCase {
    private let schedule: any ScheduleWeeklyRemindersUseCase
    private let scheduler: any NotificationScheduler

    /// - Parameter schedule: the app's one reschedule, so a run already under way cannot put notes back after this one
    ///   cleared them.
    public init(schedule: any ScheduleWeeklyRemindersUseCase, scheduler: any NotificationScheduler) {
        self.schedule = schedule
        self.scheduler = scheduler
    }

    public func execute(on date: Date) async {
        await schedule.execute(on: date)
        await scheduler.removeDelivered()
    }
}

/// Runs async work strictly one after another, in the order it was asked for.
actor SerialQueue {
    private var last: Task<Void, Never>?

    func run<Result: Sendable>(_ work: @escaping @Sendable () async -> Result) async -> Result {
        let previous = last
        let task = Task {
            await previous?.value
            return await work()
        }
        last = Task { _ = await task.value }
        return await task.value
    }
}
