# ADR-0023: Home-screen widget with the weekly quest and the latest legendary moment

**Status:** Accepted (2026-11-17). The owner approved all four choices: a child per widget, the photo on by default with
a switch, "✓ Done this week", and no lock-screen widget in v1.

## Context
Phase 3 of the roadmap lists a home-screen widget with "the weekly quest + the latest legendary moment". Neither exists
as such in the model:

- **There is no weekly quest.** Home shows every card of the selected child's world
  (`UnlockRules.quests(for:in:ageInMonths:)`: the world's own quests, then earlier evergreen ones, ADR-0020). Bosses are
  real events (a fever, a tantrum), not something to suggest.
- **A legendary moment** is a `ProgressEvent` of kind `.first` (ADR-0015). `DadProgress.moments(for:)` lists a child's
  moments newest first, by the day it happened. A moment may have a photo, a JPEG on the device (ADR-0016).
- **Everything is per child** (ADR-0012), and a family has up to four.
- **The data is out of the widget's reach.** The SwiftData store (`LocalStore.live()`, default location) and the photos
  (`FilePhotoStore.appDefault()`) live in the app's own Application Support. A widget extension is another process with
  its own container.
- The app covers ages 0–6. Past 6, home shows "coming soon".

ADR-0006 applies in full. A widget sits on the home screen all day, so it is where pressure would hurt most: no streaks,
no countdowns, nothing "missed" or "left".

## Decision

### 1. What the widget shows
- **One widget, two sizes.** `systemSmall` shows the weekly quest. `systemMedium` shows the weekly quest on the left and
  the latest legendary moment on the right.
- **One child per widget, chosen in the widget's settings**. `AppIntentConfiguration` with a
  "Child" parameter that defaults to the first child. A dad with two children can add two widgets. If the chosen child
  was removed from the family, the widget falls back to the first child. The name is shown only when there are several
  children, as in the timeline (ADR-0017).
- **The weekly quest** is one of the cards home shows for that child, the same all week:
  - Pool: `UnlockRules.quests(for: currentWorld, …)` for the child's age **at the start of the week**, so a birthday in
    the middle of the week does not swap the card. Never a boss.
  - Order: a fixed shuffle per child (a stable FNV-1a hash of child id + quest id; never `Hasher`, which is seeded per
    process, and the app and the widget are two processes). Week *n* shows card *n* mod count, so every card comes up
    once before any repeats.
  - The week is the user's calendar week (`Calendar.current`, Monday in Greece).
  - Shown: the title and "+15 XP · Care", like the card on home. If the dad did it with this child this week, a calm
    "✓ Done this week". If he did not, nothing: no "not yet", no days left, no count of weeks.
  - Past 6 (`UnlockRules.isBeyondContent`): home's "coming soon" line instead of a quest.
- **The latest legendary moment** is `DadProgress.moments(for: child).first`: emoji, title, date, and its photo if it
  has one. Never the note. With no moment yet: "Legendary moments you capture show up here." No expectation, no age,
  nothing compared (ADR-0006 rule 4).
- **Before onboarding, or if the store cannot be read:** "Open DadSaga to start the adventure."
- **The photo**: shown by default, with a "Show photo" switch in the widget's settings. Marked
  `privacySensitive()`. It appears only in the medium size, so never in StandBy or CarPlay (small only). The widget
  gallery shows sample content, never the family's data. The widget receives a copy of at most 600 px, made with ImageIO;
  the full 2048 px JPEG is never decoded in the extension (about 30 MB of memory).
- **Taps open the matching screen and record nothing.** The dad still taps "I did it" in the app.
  - Quest: Adventure tab, that child, the quest sheet (`dadsaga://quest/<quest id>?child=<uuid>`). It opens even if the
    child has since moved to the next world; earlier worlds stay playable (ADR-0019).
  - Moment: that child's moment sheet (`dadsaga://moment/<event id>?child=<uuid>`).
  - No moment, or "coming soon": home with that child (`dadsaga://child/<uuid>`).
- **Liquid Glass.** On tinted and clear home screens WidgetKit uses the accented rendering mode: the header is
  `widgetAccentable()`, the photo uses `.widgetAccentedRenderingMode(.desaturated)`, the background is set with
  `containerBackground(for: .widget)` so the system can remove it. The small size is marked as disfavored in CarPlay
  (a tap cannot open the app there).

### 2. The store and photos move to an App Group
- App and extension share the App Group `group.com.athinodoros.dadsaga` (entitlement on both targets).
- `SharedContainer.directory()` (Data) returns `Library/Application Support` inside the group container. If the group is
  missing (a build signed without the entitlement), it falls back to the process's own Application Support: the app
  still works and the widget shows "Open DadSaga".
- `LocalStore.live(in:readOnly:)` names the file explicitly: `ModelConfiguration(url: …/DadSaga.store, allowsSave:)`.
  It does not rely on SwiftData's `.automatic` group detection, which moves the store on its own as soon as an App Group
  entitlement appears.
- Photos move to `…/MomentPhotos` in the same directory. `FilePhotoStore.appDefault()` is deleted.
- **The extension opens the store read-only**, so only the app ever writes or migrates it.
- **No migration.** The app is in development: the old store stays behind in the old folder and the dad onboards again
  (or the app is reinstalled). For the same reason `LegacyProfileMigration` and the legacy `childName`/`birthDate`
  columns of `ProfileRecord` are deleted: a new store can never hold a profile from before families. This supersedes the
  migration bullet of ADR-0012.

### 3. Where the code goes
| Layer | Adds |
|---|---|
| Domain | `WeeklyQuest`: the week containing a date, the pick for a child and week, and "done this week". |
| Application | `GetWeeklyHighlightsUseCase` → `WeeklyHighlights` (child, quest slot, latest moment, photo thumbnail, valid until). `PhotoStore.thumbnail(id:maxPixelSize:)`. `AppLink`, the deep-link contract. |
| Data | `SharedContainer`, `LocalStore.live(in:readOnly:)`, `FilePhotoStore` thumbnails. |
| WidgetPresentation (new package target) | `HomeWidgetPresenter` → `HomeWidgetContent`: el/en text, links, photo data. Depends on Application and Domain only, no SwiftUI, so `swift test` covers it. |
| Presentation | Opening an `AppLink`: tab, child, sheet. |
| DesignSystem | `Image(imageData:)`, moved from Presentation so the widget can use it. |
| Widget extension (`Widget/`, Xcode target `DadSagaWidget`) | WidgetKit and AppIntents glue, the SwiftUI views (DesignSystem tokens), and `WidgetContainer`, its own composition root. |

- `AppLink` lives in Application because the widget builds the links and the app reads them, and neither presentation
  target may depend on the other.
- The extension links Domain, Application, Data, DesignSystem and WidgetPresentation. It never links Presentation and
  never builds `AppContainer`.
- `WeeklyHighlights` is not widget-specific: the weekly notification (next Phase 3 item) can use the same quest, so the
  widget and the notification never disagree.

### 4. When the widget refreshes
- **The app reloads the widget when it leaves the foreground** (`scenePhase` leaves `.active`), in one place in
  `DadSagaApp`. That covers every write, now and later: completing, undoing, deleting, moments, notes and photos,
  family edits, the developer reset. On iPhone the widget is only visible once the app is off screen. Apple does not
  count reloads requested while the app is in the foreground against the widget's budget.
- A reload call after each use case was rejected: six call sites, easy to miss in the next feature.
- **The widget asks for its next timeline at the start of the next week.** A failed read retries after an hour.

### 5. Language
- Widget text (quest titles, headers, empty states) comes from the presenter with `LocalizedText` el/en, the same way
  `HomeStrings` works.
- The few strings AppIntents and the widget gallery need as `LocalizedStringResource` (the "Child" and "Show photo"
  parameters, the widget's name and description) go in a String Catalog in the extension, with el and en.
- The extension's Info.plist lists `el` and `en`, with `el` as the development region, so its `Locale.current` matches
  the app's.

### Deferred
Lock-screen widgets (a to-do that never leaves the screen is closer to pressure; the owner said no for v1), the large
size, an "I did it" button in the widget (interactive widgets), marking the weekly quest on home, showing the note,
"on this day" moments (ADR-0020), Smart Stack relevance, push updates.

## Implementation order
One PR. Each step stays green (`swiftlint --strict`, `swift test`, the simulator build) before the next.

1. **Domain:** `WeeklyQuest` with tests: the same quest for every day of a week, every card once before a repeat,
   a known quest for fixed inputs (so the order is stable across processes), different orders for siblings, done only
   for this child and this week, Sunday night belongs to the week that started on Monday.
2. **Application:** `AppLink` (round trip; bad scheme, missing child or bad UUID give `nil`),
   `PhotoStore.thumbnail`, `GetWeeklyHighlightsUseCase` with stub repositories: no profile gives `nil`, an unknown child
   falls back to the first, a mid-week birthday does not change the quest, past 6 is "coming soon" and still shows the
   latest moment, only this child's newest moment, a missing photo gives no thumbnail, valid until the next week.
3. **Data:** `SharedContainer`, `LocalStore.live(in:readOnly:)`, `FilePhotoStore.moments(in:)` and thumbnails; delete
   `appDefault()` and the legacy migration. Tests: a store written in a temp folder is read by a second, read-only
   `LocalStore` (app and widget); a read-only store cannot save; a thumbnail's longest side is at most the limit.
4. **WidgetPresentation:** target, presenter, display model. Tests in el and en for every state: quest, done, coming
   soon, no moment, moment with and without photo, photo switched off, no profile, name only with siblings, the links.
5. **Presentation:** `RootViewModel` keeps the selected tab and a pending link; `RootView` handles `onOpenURL`;
   `HomeViewModel.open(_:)`. Tests: a quest link for the second child selects them and opens that quest, also from an
   earlier world; a link to a deleted moment opens home with no sheet; a link during onboarding is ignored.
6. **App and extension:** `project.yml` (entitlements, URL scheme `dadsaga`, the `DadSagaWidget` app extension embedded
   in the app), `AppContainer` on the shared directory, the reload in `DadSagaApp`, the `Widget/` sources and String
   Catalog, `Widget` added to `.swiftlint.yml`.
7. **Verify in the simulator** (iPhone 17 Pro, iOS 26): the store is in the group container; small and medium widgets
   for two children; every empty state; the weekly quest flips to "Done" after completing it and back after undo; a
   new moment and a deleted one; each tap lands on the right sheet; Greek and English; light, dark and tinted home
   screens; the photo switch.

## Consequences
- The widget is derived from the same events as XP and the timeline, so it can never disagree with the app.
- The dad's data now lives in the App Group container. It is still on the device only (ADR-0004) and is backed up by
  default; check restore of an offloaded app before the first TestFlight build.
- A real device needs the App Group registered to a developer team. The simulator does not: Xcode signs it locally with
  simulated entitlements. CI builds with signing off, which still builds the extension.
- A second package target and an Xcode target to maintain, and a String Catalog for a handful of strings.
- Existing development data is not carried over to the new store.
