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

    /// Whether a notification will actually arrive.
    public var isActive: Bool {
        reminder.isEnabled && authorization == .allowed
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

/// Schedules the next four weekly notifications, each with the quest of its own week (ADR-0024).
/// Run whenever the app leaves the foreground and after every settings change.
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
        calendar: Calendar = .current
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
        let reminder = await settings.fetch()
        guard reminder.isEnabled, await scheduler.authorization() == .allowed,
              let children = (try? await profileRepository.fetchProfile())?.children, !children.isEmpty
        else {
            await scheduler.replacePending(with: [])
            return
        }
        var pending: [PendingReminder] = []
        for fireDate in reminder.nextDates(after: date, count: Self.weeksAhead, calendar: calendar) {
            if let item = await pendingReminder(on: fireDate, children: children) { pending.append(item) }
        }
        await scheduler.replacePending(with: pending)
    }

    /// The weeks take turns between the children; a child with no quest (past every world) gives the turn to the next.
    /// `nil` when the quest of the week is already done, or no child has a quest.
    private func pendingReminder(on fireDate: Date, children: [Child]) async -> PendingReminder? {
        let week = WeeklyQuest.week(containing: fireDate, calendar: calendar)
        let start = WeeklyQuest.weekNumber(of: week, calendar: calendar)
        for offset in children.indices {
            let child = children[((start + offset) % children.count + children.count) % children.count]
            guard let found = try? await highlights.execute(childID: child.id, on: fireDate, photoMaxPixelSize: nil),
                  case .suggested(let quest, let isDone) = found.quest
            else { continue }
            if isDone { return nil }
            return PendingReminder(
                date: fireDate,
                title: text.title(),
                body: text.body(questTitle: quest.title, childName: children.count > 1 ? child.name : nil),
                link: .quest(id: quest.id, childID: child.id)
            )
        }
        return nil
    }
}

/// Runs async work strictly one after another, in the order it was asked for.
actor SerialQueue {
    private var last: Task<Void, Never>?

    func run(_ work: @escaping @Sendable () async -> Void) async {
        let previous = last
        let task = Task {
            await previous?.value
            await work()
        }
        last = task
        await task.value
    }
}
