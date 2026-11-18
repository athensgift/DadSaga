import Application
import Domain
import Foundation
import Presentation
import Testing

extension ReminderUseCases {
    /// iOS already said no, so home never offers the reminder.
    static var neverOffered: ReminderUseCases {
        let fake = FakeReminder(authorization: .denied)
        return ReminderUseCases(get: fake, update: fake)
    }
}

/// The reminder settings and what iOS allows, as the use cases would report them.
actor FakeReminder: GetWeeklyReminderUseCase, UpdateWeeklyReminderUseCase {
    var reminder = WeeklyReminder.default
    var authorization: NotificationAuthorization
    /// What iOS answers if it is asked.
    let allows: Bool
    private(set) var updates: [WeeklyReminder] = []

    init(authorization: NotificationAuthorization = .notDetermined, allows: Bool = true) {
        self.authorization = authorization
        self.allows = allows
    }

    func execute() async -> WeeklyReminderStatus {
        WeeklyReminderStatus(reminder: reminder, authorization: authorization)
    }

    func execute(_ reminder: WeeklyReminder, on date: Date) async -> WeeklyReminderStatus {
        var saved = reminder
        saved.wasOffered = true
        self.reminder = saved
        updates.append(saved)
        if saved.isEnabled, authorization == .notDetermined { authorization = allows ? .allowed : .denied }
        return WeeklyReminderStatus(reminder: saved, authorization: authorization)
    }
}

@MainActor
@Suite("Weekly reminder on home and in settings")
struct WeeklyReminderPresentationTests {
    let progress = FakeProgress()

    func makeHome(_ fake: FakeReminder, locale: String = "el_GR") -> HomeViewModel {
        makeHomeViewModel(
            profile: HeroStub.profile,
            progress: progress,
            locale: locale,
            reminder: ReminderUseCases(get: fake, update: fake)
        )
    }

    func completeFirstQuest(_ sut: HomeViewModel) async {
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
    }

    @Test("Given no quest done yet, when home opens, then there is no offer; after the first quest, there is")
    func offerAfterFirstQuest() async {
        let sut = makeHome(FakeReminder())
        await sut.onAppear()
        #expect(sut.reminderOffer == nil)

        await completeFirstQuest(sut)

        #expect(sut.reminderOffer?.title == "Μια υπενθύμιση την εβδομάδα;")
        #expect(sut.reminderOffer?.message.contains("Σάββατο 10:00") == true)
        #expect(sut.reminderOffer?.accept == "Ναι, στείλε μου")
        #expect(sut.reminderOffer?.decline == "Όχι, ευχαριστώ")
    }

    @Test("Given the offer, when the dad says yes, then the reminder is on and the offer never comes back")
    func acceptTurnsOn() async {
        let fake = FakeReminder()
        let sut = makeHome(fake)
        await sut.onAppear()
        await completeFirstQuest(sut)

        await sut.answerReminderOffer(accept: true)
        await sut.reload()

        #expect(sut.reminderOffer == nil)
        #expect(await fake.updates.map(\.isEnabled) == [true])
        #expect(await fake.authorization == .allowed)
    }

    @Test("Given the offer, when the dad says no, then nothing is turned on and the offer never comes back")
    func declineHidesForGood() async {
        let fake = FakeReminder()
        let sut = makeHome(fake)
        await sut.onAppear()
        await completeFirstQuest(sut)

        await sut.answerReminderOffer(accept: false)
        await sut.reload()

        #expect(sut.reminderOffer == nil)
        #expect(await fake.updates.map(\.isEnabled) == [false])
        #expect(await fake.authorization == .notDetermined)
    }

    @Test("Given iOS already answered (e.g. after a reinstall), when the first quest is done, then there is no offer")
    func noOfferWhenIOSAlreadyAsked() async {
        let sut = makeHome(FakeReminder(authorization: .denied))
        await sut.onAppear()
        await completeFirstQuest(sut)
        #expect(sut.reminderOffer == nil)
    }

    @Test("Given English, when the offer shows, then it is in English")
    func english() async {
        let sut = makeHome(FakeReminder(), locale: "en_US")
        await sut.onAppear()
        await completeFirstQuest(sut)
        #expect(sut.reminderOffer?.message.hasPrefix("Once a week (Saturday 10:00\u{202F}AM), this week's quest.") == true)
    }

    @Test("Given the settings screen, when turning it on and changing day and time, then each change is saved")
    func settingsSave() async {
        let fake = FakeReminder()
        let sut = ReminderSettingsViewModel(
            useCases: ReminderUseCases(get: fake, update: fake),
            locale: Locale(identifier: "el_GR"),
            calendar: Self.greekCalendar
        )
        await sut.onAppear()
        #expect(sut.labels.title == "Εβδομαδιαία υπενθύμιση")
        #expect(!sut.isEnabled)
        #expect(sut.weekdays.first?.name == "Δευτέρα")
        #expect(sut.weekdays.map(\.id) == [2, 3, 4, 5, 6, 7, 1])

        await sut.setEnabled(true)
        await sut.setWeekday(1)
        await sut.setTime(hour: 18, minute: 30)

        #expect(sut.isEnabled)
        #expect(sut.deniedMessage == nil)
        #expect(await fake.reminder == WeeklyReminder(isEnabled: true, weekday: 1, hour: 18, minute: 30, wasOffered: true))
    }

    @Test("Given iOS refuses, when turning it on, then the screen says notifications are off in iPhone Settings")
    func denied() async {
        let fake = FakeReminder(allows: false)
        let sut = ReminderSettingsViewModel(
            useCases: ReminderUseCases(get: fake, update: fake),
            locale: Locale(identifier: "el_GR"),
            calendar: Self.greekCalendar
        )
        await sut.onAppear()

        await sut.setEnabled(true)

        #expect(sut.deniedMessage == "Οι ειδοποιήσεις του DadSaga είναι κλειστές στις ρυθμίσεις του iPhone.")
        await sut.setEnabled(false)
        #expect(sut.deniedMessage == nil)
    }

    @Test("Given a quest title, when writing the notification, then a name leads only when there are siblings")
    func notificationText() {
        let text = WeeklyReminderText(locale: Locale(identifier: "el_GR"))
        let quest = LocalizedText(el: "Διάβασε ένα βιβλίο μαζί", en: "Read a book together")
        #expect(text.title() == "Η αποστολή της εβδομάδας")
        #expect(text.body(questTitle: quest, childName: nil) == "Διάβασε ένα βιβλίο μαζί")
        #expect(text.body(questTitle: quest, childName: "Λένα") == "Λένα · Διάβασε ένα βιβλίο μαζί")
        #expect(WeeklyReminderText(locale: Locale(identifier: "en_US")).title() == "This week's quest")
    }

    static var greekCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        return calendar
    }

    @Test("Given a slow first save, when a newer change finishes first, then the screen keeps the newer time")
    func lateResultDoesNotWin() async {
        let fake = SlowFirstReminder()
        let sut = ReminderSettingsViewModel(
            useCases: ReminderUseCases(get: fake, update: fake),
            locale: Locale(identifier: "el_GR"),
            calendar: Self.greekCalendar
        )
        await sut.onAppear()

        let first = Task { await sut.setTime(hour: 11, minute: 0) }
        while await fake.calls == 0 { await Task.yield() }
        await sut.setTime(hour: 11, minute: 30)
        await first.value

        #expect(sut.hour == 11)
        #expect(sut.minute == 30)
    }

    @Test("Given English with a Sunday-first calendar, when the settings open, then Sunday comes first")
    func englishWeekdays() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        let fake = FakeReminder()
        let sut = ReminderSettingsViewModel(
            useCases: ReminderUseCases(get: fake, update: fake),
            locale: Locale(identifier: "en_US"),
            calendar: calendar
        )
        #expect(sut.weekdays.map(\.name).prefix(2) == ["Sunday", "Monday"])
        #expect(sut.labels.title == "Weekly reminder")
    }
}

/// Settings use cases whose first save is slow, so a later save finishes before it.
actor SlowFirstReminder: GetWeeklyReminderUseCase, UpdateWeeklyReminderUseCase {
    private(set) var calls = 0

    func execute() async -> WeeklyReminderStatus {
        WeeklyReminderStatus(reminder: .default, authorization: .allowed)
    }

    func execute(_ reminder: WeeklyReminder, on date: Date) async -> WeeklyReminderStatus {
        calls += 1
        if calls == 1 { try? await Task.sleep(for: .milliseconds(200)) }
        return WeeklyReminderStatus(reminder: reminder, authorization: .allowed)
    }
}
