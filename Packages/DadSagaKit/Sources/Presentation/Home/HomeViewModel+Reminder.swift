import Application
import Domain
import Foundation
import Localization

/// The one calm offer of a weekly reminder, shown on home once the dad has done his first quest (ADR-0024).
public struct ReminderOffer: Equatable, Sendable {
    public let title: String
    public let message: String
    public let accept: String
    public let decline: String
}

extension HomeViewModel {
    /// The offer, only after a first quest, while the dad has not answered it and iOS has never asked him.
    func makeReminderOffer(children: [Child], progress: DadProgress) async -> ReminderOffer? {
        let reminder = useCases.reminder
        guard !reminderAnswered,
              children.contains(where: { !progress.questCompletions(for: $0.id).isEmpty })
        else { return nil }
        let status = await reminder.get.execute()
        guard status.canOffer else { return nil }
        let text = WeeklyReminderText(locale: locale)
        let settings = status.reminder
        let when = text.when(
            weekday: settings.weekday, hour: settings.hour, minute: settings.minute, calendar: .autoupdatingCurrent
        )
        return ReminderOffer(
            title: strings.text("A reminder once a week?"),
            message: strings.text(
                """
                Once a week (\(when)), this week's quest. Nothing more. If you've already done it, you won't get it \
                that week.
                """
            ),
            accept: strings.text("Yes, send it"),
            decline: strings.text("No, thanks")
        )
    }

    /// Either answer hides the offer for good. "Yes" turns the reminder on, which shows the iOS prompt.
    public func answerReminderOffer(accept: Bool) async {
        let reminder = useCases.reminder
        guard reminderOffer != nil else { return }
        // Remembered at once, so a reload that runs while the answer is being saved cannot bring the card back.
        reminderAnswered = true
        reminderOffer = nil
        var settings = await reminder.get.execute().reminder
        settings.isEnabled = accept
        _ = await reminder.update.execute(settings, on: now())
    }
}
