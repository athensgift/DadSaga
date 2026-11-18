import Application
import Domain
import Foundation
import Testing

@Suite("Weekly reminder use cases")
struct WeeklyReminderUseCaseTests {
    typealias Fixture = WeeklyHighlightsUseCaseTests
    static func text(_ value: String) -> LocalizedText { LocalizedText(el: value, en: value) }

    /// One world, three quests, so the weeks show different quests.
    static let catalog = ContentCatalog(
        worlds: [World(id: "w1", order: 1, title: text("w"), tagline: text("w"), minAgeMonths: 0, maxAgeMonths: 24)],
        quests: ["q1", "q2", "q3"].map {
            Quest(id: $0, worldID: "w1", title: text($0), description: text($0), skill: .care, xp: 15, minAgeMonths: 0)
        },
        bosses: [],
        firsts: []
    )

    /// Wednesday 18 November 2026, noon UTC.
    let today = Fixture.date(2026, 11, 18)
    let lena = Child(name: "Lena", birthDate: Fixture.date(2026, 1, 1))
    let nikos = Child(name: "Nikos", birthDate: Fixture.date(2025, 6, 1))
    let older = Child(name: "Eleni", birthDate: Fixture.date(2018, 1, 1))
    let profiles = SpyProfileRepository()
    let progress = SpyProgressRepository()
    let settings = FakeReminderSettings()

    func schedule(
        _ scheduler: FakeNotificationScheduler,
        calendar: Calendar = Fixture.calendar
    ) -> DefaultScheduleWeeklyRemindersUseCase {
        DefaultScheduleWeeklyRemindersUseCase(
            settings: settings,
            scheduler: scheduler,
            profileRepository: profiles,
            highlights: DefaultGetWeeklyHighlightsUseCase(
                contentRepository: StubContentRepository(result: .success(Self.catalog)),
                profileRepository: profiles,
                progressRepository: progress,
                photoStore: SpyPhotoStore(),
                calendar: calendar
            ),
            text: EchoReminderText(),
            calendar: calendar
        )
    }

    func update(_ scheduler: FakeNotificationScheduler) -> DefaultUpdateWeeklyReminderUseCase {
        DefaultUpdateWeeklyReminderUseCase(settings: settings, scheduler: scheduler, schedule: schedule(scheduler))
    }

    func onboard(_ children: [Child]) async throws {
        try await profiles.save(PlayerProfile(children: children, heroClassID: "chef"))
    }

    func enable() async {
        var reminder = WeeklyReminder.default
        reminder.isEnabled = true
        await settings.save(reminder)
    }

    /// The wall-clock time a note is due: that day at 10:00, with no time zone.
    static func tenOClock(_ year: Int, _ month: Int, _ day: Int) -> DateComponents {
        DateComponents(year: year, month: month, day: day, hour: 10, minute: 0)
    }

    /// The quest the widget shows for this child in the week of `date`.
    func weeklyQuest(for child: Child, on date: Date) -> String? {
        let week = WeeklyQuest.week(containing: date, calendar: Fixture.calendar)
        return WeeklyQuest.pick(from: Self.catalog.quests, childID: child.id, week: week, calendar: Fixture.calendar)?.id
    }

    @Test("Given the reminder is on and allowed, when scheduling, then the next four Saturdays carry their week's quest")
    func fourWeeks() async throws {
        try await onboard([lena])
        await enable()
        let scheduler = FakeNotificationScheduler(status: .allowed)

        await schedule(scheduler).execute(on: today)

        let pending = await scheduler.pending
        let saturdays = [21, 28].map { Fixture.date(2026, 11, $0, 10) } + [5, 12].map { Fixture.date(2026, 12, $0, 10) }
        #expect(pending.map(\.time) == saturdays.map {
            Fixture.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: $0)
        })
        #expect(pending.map(\.link) == saturdays.map { .quest(id: weeklyQuest(for: lena, on: $0) ?? "", childID: lena.id) })
        #expect(pending.first?.title == "This week's quest")
        #expect(pending.first?.body == weeklyQuest(for: lena, on: saturdays[0]))
    }

    @Test("Given this week's quest is done, when scheduling, then this Saturday is skipped and the next three stay")
    func doneThisWeek() async throws {
        try await onboard([lena])
        await enable()
        let questID = try #require(weeklyQuest(for: lena, on: today))
        try await progress.add(ProgressEvent(kind: .quest(id: questID), childID: lena.id, date: today))
        let scheduler = FakeNotificationScheduler(status: .allowed)

        await schedule(scheduler).execute(on: today)

        #expect(await scheduler.pending.map(\.time) == [Self.tenOClock(2026, 11, 28)] + [5, 12].map {
            Self.tenOClock(2026, 12, $0)
        })
    }

    @Test("Given the reminder is off, or iOS does not allow it, when scheduling, then nothing is waiting")
    func offOrDenied() async throws {
        try await onboard([lena])
        let off = FakeNotificationScheduler(status: .allowed)
        await schedule(off).execute(on: today)
        #expect(await off.pending.isEmpty)

        await enable()
        let denied = FakeNotificationScheduler(status: .denied)
        await schedule(denied).execute(on: today)
        #expect(await denied.pending.isEmpty)
    }

    @Test("Given no family yet, when scheduling, then nothing is waiting")
    func noProfile() async {
        await enable()
        let scheduler = FakeNotificationScheduler(status: .allowed)
        await schedule(scheduler).execute(on: today)
        #expect(await scheduler.pending.isEmpty)
    }

    @Test("Given two children, when scheduling, then the weeks take turns and the body names the child")
    func siblingsTakeTurns() async throws {
        try await onboard([lena, nikos])
        await enable()
        let scheduler = FakeNotificationScheduler(status: .allowed)

        await schedule(scheduler).execute(on: today)

        let pending = await scheduler.pending
        #expect(pending.count == 4)
        let children = pending.map(\.link.childID)
        #expect(Set(children) == [lena.id, nikos.id])
        #expect(zip(children, children.dropFirst()).allSatisfy { $0 != $1 })
        for reminder in pending {
            let child = reminder.link.childID == lena.id ? lena : nikos
            let date = try #require(Fixture.calendar.date(from: reminder.time))
            #expect(reminder.body == "\(child.name) · \(weeklyQuest(for: child, on: date) ?? "")")
        }
    }

    @Test("Given one child past every world, when scheduling, then every week goes to the child who has quests")
    func skipsChildBeyondContent() async throws {
        try await onboard([older, lena])
        await enable()
        let scheduler = FakeNotificationScheduler(status: .allowed)

        await schedule(scheduler).execute(on: today)

        #expect(await scheduler.pending.map(\.link.childID) == Array(repeating: lena.id, count: 4))
    }

    @Test("Given iOS never asked, when the dad turns it on, then iOS asks once and the notifications are scheduled")
    func enablingAsksOnce() async throws {
        try await onboard([lena])
        let scheduler = FakeNotificationScheduler(status: .notDetermined)
        var reminder = WeeklyReminder.default
        reminder.isEnabled = true

        let status = await update(scheduler).execute(reminder, on: today)
        _ = await update(scheduler).execute(reminder, on: today)

        #expect(await scheduler.promptCount == 1)
        #expect(status.isActive)
        #expect(!status.canOffer)
        #expect(await scheduler.pending.count == 4)
    }

    @Test("Given the dad says no to the offer, when saving, then iOS is not asked and the offer never comes back")
    func decliningNeverAsks() async {
        let scheduler = FakeNotificationScheduler(status: .notDetermined)

        let status = await update(scheduler).execute(.default, on: today)

        #expect(await scheduler.promptCount == 0)
        #expect(!status.canOffer)
        #expect(!(await DefaultGetWeeklyReminderUseCase(settings: settings, scheduler: scheduler).execute().canOffer))
    }

    @Test("Given iOS refuses, when the dad turns it on, then it is saved on but not active")
    func refused() async {
        let scheduler = FakeNotificationScheduler(status: .notDetermined, allowsWhenAsked: false)
        var reminder = WeeklyReminder.default
        reminder.isEnabled = true

        let status = await update(scheduler).execute(reminder, on: today)

        #expect(status.authorization == .denied)
        #expect(!status.isActive)
        #expect(await scheduler.pending.isEmpty)
    }

    @Test("Given Saturday after 10:00, when scheduling, then the first note is next Saturday with next week's quest")
    func afterTheTimeThisWeek() async throws {
        try await onboard([lena])
        await enable()
        let scheduler = FakeNotificationScheduler(status: .allowed)

        await schedule(scheduler).execute(on: Fixture.date(2026, 11, 21, 11))

        let first = try #require(await scheduler.pending.first)
        #expect(first.time == Self.tenOClock(2026, 11, 28))
        #expect(first.link == .quest(id: weeklyQuest(for: lena, on: Fixture.date(2026, 11, 28)) ?? "", childID: lena.id))
    }

    @Test("Given a dad in Athens, when scheduling, then each note is due at 10:00 on the clock, with no fixed time zone")
    func wallClockTime() async throws {
        try await onboard([lena])
        await enable()
        var athens = Fixture.calendar
        athens.timeZone = TimeZone(identifier: "Europe/Athens") ?? .gmt
        let scheduler = FakeNotificationScheduler(status: .allowed)
        await schedule(scheduler, calendar: athens).execute(on: today)

        let first = try #require(await scheduler.pending.first)
        #expect(first.time == Self.tenOClock(2026, 11, 21))
        #expect(first.time.timeZone == nil)
    }

    @Test("Given three children and the middle one past every world, when scheduling, then only the other two come up")
    func threeChildren() async throws {
        try await onboard([lena, older, nikos])
        await enable()
        let scheduler = FakeNotificationScheduler(status: .allowed)

        await schedule(scheduler).execute(on: today)

        let children = Set(await scheduler.pending.map(\.link.childID))
        #expect(await scheduler.pending.count == 4)
        #expect(children.isSubset(of: [lena.id, nikos.id]))
    }

    @Test("Given a slow run that started first, when a newer run turns it off, then nothing is left pending")
    func runsOneAtATime() async throws {
        try await onboard([lena])
        await enable()
        let scheduler = SlowFirstScheduler()
        let slow = DefaultScheduleWeeklyRemindersUseCase(
            settings: settings,
            scheduler: scheduler,
            profileRepository: profiles,
            highlights: DefaultGetWeeklyHighlightsUseCase(
                contentRepository: StubContentRepository(result: .success(Self.catalog)),
                profileRepository: profiles,
                progressRepository: progress,
                photoStore: SpyPhotoStore(),
                calendar: Fixture.calendar
            ),
            text: EchoReminderText(),
            calendar: Fixture.calendar
        )

        let first = Task { await slow.execute(on: today) }
        while await scheduler.calls == 0 { await Task.yield() }
        await settings.save(.default)
        await slow.execute(on: today)
        await first.value

        #expect(await scheduler.pending.isEmpty)
    }

    @Test("Given a profile with reminder settings and notifications, when resetting, then both are gone")
    func resetClearsReminder() async throws {
        try await onboard([lena])
        await enable()
        let scheduler = FakeNotificationScheduler(status: .allowed)
        await schedule(scheduler).execute(on: today)

        try await DefaultResetProfileUseCase(
            profileRepository: profiles,
            progressRepository: progress,
            photoStore: SpyPhotoStore(),
            outfitRepository: SpyOutfitRepository(),
            reminderSettings: settings,
            notificationScheduler: scheduler
        ).execute()

        #expect(await settings.fetch() == .default)
        #expect(await scheduler.pending.isEmpty)
    }
}

extension WeeklyReminderUseCaseTests {
    @Test("Given the family cannot be read, when rescheduling, then the notes already waiting stay as they were")
    func unreadableFamilyKeepsNotes() async throws {
        try await onboard([lena])
        await enable()
        let scheduler = FakeNotificationScheduler(status: .allowed)
        await schedule(scheduler).execute(on: today)
        let waiting = await scheduler.pending
        let unreadable = DefaultScheduleWeeklyRemindersUseCase(
            settings: settings,
            scheduler: scheduler,
            profileRepository: UnreadableProfiles(),
            highlights: DefaultGetWeeklyHighlightsUseCase(
                contentRepository: StubContentRepository(result: .success(Self.catalog)),
                profileRepository: profiles,
                progressRepository: progress,
                photoStore: SpyPhotoStore(),
                calendar: Fixture.calendar
            ),
            text: EchoReminderText(),
            calendar: Fixture.calendar
        )

        await unreadable.execute(on: today)

        #expect(!waiting.isEmpty)
        #expect(await scheduler.pending == waiting)
    }

    @Test("Given a slow first change, when the dad changes the time again meanwhile, then the newer time is saved")
    func newestChangeIsSaved() async throws {
        try await onboard([lena])
        let slowSettings = SlowFirstSettings()
        let scheduler = FakeNotificationScheduler(status: .allowed)
        let sut = DefaultUpdateWeeklyReminderUseCase(settings: slowSettings, scheduler: scheduler, schedule: schedule(scheduler))
        var eleven = WeeklyReminder.default
        eleven.isEnabled = true
        eleven.hour = 11
        var halfPast = eleven
        halfPast.minute = 30

        let first = Task { await sut.execute(eleven, on: today) }
        while await slowSettings.calls == 0 { await Task.yield() }
        _ = await sut.execute(halfPast, on: today)
        _ = await first.value

        #expect(await slowSettings.fetch().minute == 30)
    }
}
