import Application
import Domain
import Foundation
import Testing

/// One note a week, whatever the dad changes after this week's has arrived (ADR-0024 §1).
extension WeeklyReminderUseCaseTests {
    /// Saturday 21 November, an hour after the note arrived at 10:00.
    var saturdayAfterTheNote: Date { Fixture.date(2026, 11, 21, 11) }

    /// The reminder was on since Wednesday, and this Saturday's note has arrived.
    func noteArrived(_ scheduler: FakeNotificationScheduler) async throws {
        try await onboard([lena])
        await enable()
        await schedule(scheduler).execute(on: today)
        await scheduler.deliverNext()
    }

    func changed(_ change: (inout WeeklyReminder) -> Void) async -> WeeklyReminder {
        var reminder = await settings.fetch()
        change(&reminder)
        return reminder
    }

    @Test("Given this week's note arrived, when the dad moves it to later this week, then the next comes next week")
    func laterTheSameWeek() async throws {
        let scheduler = FakeNotificationScheduler(status: .allowed)
        try await noteArrived(scheduler)
        let sunday = await changed { $0.weekday = 1 }

        _ = await update(scheduler).execute(sunday, on: saturdayAfterTheNote)

        #expect(await scheduler.pending.first?.time == Self.tenOClock(2026, 11, 29))

        // Leaving the app afterwards reschedules again.
        await schedule(scheduler).execute(on: saturdayAfterTheNote)
        #expect(await scheduler.pending.first?.time == Self.tenOClock(2026, 11, 29))
    }

    @Test("Given this week's note arrived, when the dad turns it off and on at a later hour, then none comes this week")
    func offAndOnAgain() async throws {
        let scheduler = FakeNotificationScheduler(status: .allowed)
        try await noteArrived(scheduler)

        _ = await update(scheduler).execute(await changed { $0.isEnabled = false }, on: saturdayAfterTheNote)
        #expect(await scheduler.pending.isEmpty)
        let evening = await changed { $0.isEnabled = true; $0.hour = 20 }
        _ = await update(scheduler).execute(evening, on: saturdayAfterTheNote)

        #expect(await scheduler.pending.first?.time == DateComponents(year: 2026, month: 11, day: 28, hour: 20, minute: 0))
    }

    @Test("Given this week's note hasn't arrived, when the dad moves it, then it still comes this week, once")
    func movedBeforeItArrives() async throws {
        try await onboard([lena])
        await enable()
        let scheduler = FakeNotificationScheduler(status: .allowed)
        await schedule(scheduler).execute(on: today)
        let sunday = await changed { $0.weekday = 1 }

        _ = await update(scheduler).execute(sunday, on: today)

        #expect(await scheduler.pending.map(\.time) == [
            Self.tenOClock(2026, 11, 22), Self.tenOClock(2026, 11, 29),
            Self.tenOClock(2026, 12, 6), Self.tenOClock(2026, 12, 13)
        ])
    }

    @Test("Given the entries cannot be read, when rescheduling, then the notes already waiting stay as they were")
    func unreadableEntriesKeepNotes() async throws {
        try await onboard([lena])
        await enable()
        let scheduler = FakeNotificationScheduler(status: .allowed)
        await schedule(scheduler).execute(on: today)
        let waiting = await scheduler.pending
        let unreadable = DefaultScheduleWeeklyRemindersUseCase(
            settings: settings,
            scheduler: scheduler,
            profileRepository: profiles,
            highlights: UnreadableHighlights(),
            text: EchoReminderText(),
            calendar: Fixture.calendar
        )

        await unreadable.execute(on: today)

        #expect(!waiting.isEmpty)
        #expect(await scheduler.pending == waiting)
    }
}

/// No note names a child who left the family.
extension WeeklyReminderUseCaseTests {
    @Test("Given waiting notes and one shown, when a child is removed, then no note names them")
    func removingAChildTakesTheirNotes() async throws {
        try await onboard([lena, nikos])
        await enable()
        let scheduler = FakeNotificationScheduler(status: .allowed)
        let schedule = schedule(scheduler)
        await schedule.execute(on: today)
        await scheduler.deliverNext()
        let family = DefaultUpdateFamilyUseCase(
            profileRepository: profiles,
            renewReminders: DefaultRenewWeeklyRemindersUseCase(schedule: schedule, scheduler: scheduler)
        )

        try await family.execute(FamilyEdit(removedIDs: [nikos.id]), on: today)

        #expect(await scheduler.delivered.isEmpty)
        let pending = await scheduler.pending
        #expect(!pending.isEmpty)
        #expect(pending.allSatisfy { $0.link.childID == lena.id && !$0.body.contains(nikos.name) })
    }

    @Test("Given notes of the family, when a removed child is deleted for good, then the notes are renewed")
    func deletingForGoodTakesTheirNotes() async throws {
        await profiles.seed(PlayerProfile(children: [lena], heroClassID: "chef", removedChildren: [nikos]))
        await enable()
        let scheduler = FakeNotificationScheduler(status: .allowed)
        await scheduler.deliver(PendingReminder(
            time: Self.tenOClock(2026, 11, 14), title: "", body: nikos.name, link: .child(nikos.id)
        ))
        let sut = DefaultDeleteChildForGoodUseCase(
            contentRepository: StubContentRepository(result: .success(Self.catalog)), profileRepository: profiles,
            progressRepository: progress, standingRepository: InMemoryStanding(), photoStore: SpyPhotoStore(),
            renewReminders: DefaultRenewWeeklyRemindersUseCase(schedule: schedule(scheduler), scheduler: scheduler)
        )

        try await sut.execute(childID: nikos.id, on: today)

        #expect(await scheduler.delivered.isEmpty)
        #expect(await scheduler.pending.count == 4)
    }
}

/// A saga whose entries cannot be read.
private struct UnreadableHighlights: GetWeeklyHighlightsUseCase {
    func execute(childID: UUID?, on date: Date, photoMaxPixelSize: Int?) async throws -> WeeklyHighlights? {
        throw StubError.boom
    }
}
