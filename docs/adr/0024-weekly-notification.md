# ADR-0024: One gentle weekly notification with the quest of the week

**Status:** Accepted (2026-11-17). The owner chose the content (the quest of the week), the time (Saturday 10:00,
adjustable), "no notification if the quest is already done", and asking for permission only after the first quest.

## Context
Phase 3 of the roadmap lists "gentle local notifications (max one a week)". ADR-0023 built `WeeklyQuest` and
`GetWeeklyHighlightsUseCase` so that the widget and this notification suggest the same quest. ADR-0006 applies in full:
a notification is the loudest thing the app can do, so it must never count, chase or blame.

## Decision

### 1. What it says and when
- **At most one notification a week**, on the dad's chosen weekday and time; Saturday 10:00 by default.
- Title "Η αποστολή της εβδομάδας" / "This week's quest". Body: the quest title. With several children the body starts
  with the child's name ("Λένα · Διάβασε ένα βιβλίο μαζί"). No XP, no counts, no "you haven't", no days left.
- **Tap** opens that quest's sheet for that child through the existing `AppLink.quest` (ADR-0023). Nothing is recorded.
- **Already done this week → no notification that week.** "Done" is `WeeklyQuest.isDone`, the same as the widget's
  "✓ Done this week".
- **Several children:** the weeks rotate through the children (week number mod child count), so each child comes up in
  turn and the quest matches that child's widget. A child past 6 ("coming soon") is skipped in favour of the next
  child; with no child in range there is no notification.
- If the app is open when it fires, it still shows as a banner.
- The notification plays the default sound. The child's name (only with siblings) and the quest title can show on
  the lock screen; it stays on the device (ADR-0004).

### 2. How it is scheduled
- Local notifications only (ADR-0004: nothing leaves the device). Non-repeating `UNCalendarNotificationTrigger`s, one
  per week, for **the next four occurrences**, each with the quest of its own week. A repeating trigger cannot change
  its text or skip a week.
- **Rescheduled when the app leaves the foreground**, in the same place as the widget reload (ADR-0023 §4), and after
  every settings change. Completing the quest and leaving the app therefore removes this week's notification; undo
  brings it back.
- Four weeks, then silence: a dad who stops opening the app gets four gentle notes and nothing more. That is on
  purpose (ADR-0006: nothing chases him).
- Every reschedule removes the pending DadSaga requests and adds the new ones (ids `weekly-quest-0…3`).
- **One reschedule at a time.** The app keeps a single schedule use case and its runs queue behind each other, so a
  slow run can never add its notifications after a newer run (a settings change, leaving the app) cleared them.
- The developer reset also removes the pending notifications.

### 3. Permission
- **Never at onboarding.** Once the dad has completed at least one quest, home shows one calm card at the top of the
  list: "Μία φορά την εβδομάδα (Σάββατο 10:00), η αποστολή της εβδομάδας. Τίποτα παραπάνω. Αν την έχεις ήδη κάνει,
  δεν έρχεται." with "Ναι, στείλε μου" and "Όχι, ευχαριστώ". The day and time are the dad's current settings.
- The card shows only while the dad has not answered it and iOS has not been asked (`notDetermined`). Either answer
  hides it for good; "Yes" then shows the iOS prompt.
- **Settings** (bell button on home): on/off switch, weekday, time. Turning it on asks iOS if it was never asked. If iOS
  denies, the screen says once that notifications are off in the iPhone settings and offers a button to open them. The
  app never asks again on its own.

### 4. Where the code goes
| Layer | Adds |
|---|---|
| Domain | `WeeklyReminder` (enabled, weekday, hour, minute, wasOffered; `nextDates(after:count:calendar:)`), `WeeklyQuest.weekNumber` made public for the rotation. |
| Application | Ports `ReminderSettingsRepository`, `NotificationScheduler` (authorization, request, replace pending), `ReminderTextProvider`. Use cases `GetWeeklyReminderUseCase`, `UpdateWeeklyReminderUseCase`, `ScheduleWeeklyRemindersUseCase` (built on `GetWeeklyHighlightsUseCase`). The developer reset also clears the settings. |
| Data | `UserDefaultsReminderSettingsRepository` (the app's own defaults: only the app reads them), `UserNotificationScheduler`. |
| Presentation | `WeeklyReminderText` (el/en), the offer card on home, `ReminderSettingsViewModel` + `ReminderSettingsView`. |
| App | Wiring, reschedule on leaving the foreground, `UNUserNotificationCenterDelegate` that hands the tapped link to `RootView` through a small inbox (on a cold launch the tap arrives before the scene exists, so it is not sent back through the URL scheme). |

- The settings are not part of `PlayerProfile`: the family sheet saves the whole profile and would overwrite them.
- Presentation never imports UserNotifications; the view only opens the system settings URL.

### Deferred
Notifications for bosses, moments or new worlds; more than one a week; a lock-screen or Live Activity version.

## Implementation order
1. **Domain:** `WeeklyReminder.nextDates` (next Saturday 10:00 from a Wednesday; from Saturday 10:00 itself it is the
   following week; a custom weekday/time; four dates a week apart across a daylight-saving change).
2. **Application:** schedule use case with stubs: disabled or not allowed → nothing pending; no profile → nothing;
   four weeks with their own quests; done this week → that week skipped, the next three kept; two children rotate;
   a child past 6 is skipped; text only with a name when there are siblings; the link opens the right quest. Update
   use case: enabling asks permission only when never asked; any answer marks the offer as answered.
3. **Data:** the defaults repository round trip.
4. **Presentation:** the offer card appears only after the first quest and only while unanswered; "Yes" and "No" hide
   it; settings screen states for allowed, denied and off; el/en text.
5. **App:** delegate, wiring, reschedule.
6. **Verify on iPhone 17 Pro:** the card after the first quest, the iOS prompt, the pending requests
   (`getPendingNotificationRequests` in the debugger or a short trigger in a debug build), a delivered notification
   and its tap opening the quest (also with the app killed), done → this week's request gone, the settings screen in Greek and English, denied.

## Consequences
- The notification and the widget can never disagree: both read `GetWeeklyHighlightsUseCase`.
- A dad who never opens the app again gets at most four notifications.
- The settings live in the app's UserDefaults, so they reset with a reinstall, like the permission itself.
