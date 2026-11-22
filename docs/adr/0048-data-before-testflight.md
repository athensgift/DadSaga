# ADR-0048: The saga's data before TestFlight: failed saves leave nothing behind, a birth date is a day, no silent new store, content ids that never go, and a careful sweep of orphan photos

**Status:** Accepted (2026-11-21; merged while still marked Proposed, recorded as Accepted on 2026-11-22). Changed by
[ADR-0060](0060-nothing-ships-before-the-first-app-store-release.md): an id ships with the first App Store release, not
with `develop` (§5), and version 5 is folded, with the others, into the one `SchemaV1` until that release (§3).

From the review of 2026-11-21 (its second pass, which overrides the first where they
differ). The owner asked for these five in one PR before the first TestFlight build; drafted by the architect. Changes
ADR-0005 (an id that has shipped never leaves the content; renames go through `formerIDs`), ADR-0023 §2 (no fallback
folder in a release build), ADR-0026 §1–§2 (the folder is found when the store opens; version 5), ADR-0028 §1
(`Adventure` takes a day, not a calendar), ADR-0030 §5 and §8 ("My family" no longer checks the hero; leftover photos
are swept), ADR-0036 §2 (periods and occasions count from a birth day, on the Gregorian calendar) and ADR-0042 (orphan
photos are swept at launch, not left for export).

## Context
- **A failed save stays pending.** Each SwiftData repository inserts or changes rows and then calls `save()`. Only
  `SwiftDataSagaEraser` calls `rollback()` when that fails. A context the app creates doesn't save on its own
  (`autosaveEnabled` defaults to `false`), so the failed change waits in the context until the next save, which commits
  it. Fetches include unsaved changes by default (`FetchDescriptor.includePendingChanges`). With a full disk the screen
  says the save failed and the photos written for it are deleted, but the entry is saved later with photo ids that no
  longer exist. A boss or a first can't be tried again in that session: the pending row makes
  `addUnlessRecorded` answer "already recorded". The review reproduced this by running it.
- **A birth date is an instant.** `Child.birthDate: Date` keeps the time of day it was entered, and onboarding starts it
  at `now`. Noon on 15 March in New Zealand is 14 March in Los Angeles. `Child.ageInMonths(at:)`, which unlocks worlds,
  counts from the instant; `SagaPeriod` and `SagaOccasions`, which tell the film's periods and when to offer one, count
  from the start of the birth day. So on the day a child grows into the next world, the film is offered hours before
  home shows that world.
- **Ages use the device's calendar.** The same child is 56 months old by the Gregorian calendar and 58 by the Islamic or
  Hebrew one (the review, by running it): worlds open early on those phones. The content's ages (`minAgeMonths`,
  `maxAgeMonths`) are Gregorian months.
- **A missing App Group opens a new, empty saga.** `SharedContainer.directory()` falls back to the app's own Application
  Support when iOS has no container for the group, and to `tmp` if that fails. A release build signed without the
  entitlement would send the dad to onboarding, and anything he then recorded could go with `tmp`. On iOS,
  `containerURL(forSecurityApplicationGroupIdentifier:)` returns `nil` for a group the build isn't entitled to; on macOS
  it returns a URL whatever the entitlement, so the rule can't be tested through it.
- **Renaming content loses data.** Events whose content id the catalog doesn't know are skipped (ADR-0005): their XP, the
  gear that XP earned and their place in the timeline and the film are gone. A renamed hero makes "My family" throw
  `unknownHeroClass`, because editing the family checks the stored hero. The next PR corrects and moves cards.
- **Photos can be left behind for good.** Photos are written before their entry (ADR-0042 §1); starting over deletes the
  store, then the photos (ADR-0030 §8). A kill between the two steps leaves files nothing points to, and nothing ever
  removes them.
- **What Apple documents (checked 2026-11-21):** `ModelContext.rollback()` "discards pending inserts and deletes,
  restores changed models to their most recent committed state". `ModelContext.transaction(block:)` says nothing about
  what happens to pending changes when the block or the save throws. `delete(model:where:)` removes the rows "during the
  next save operation", and nothing says whether `rollback()` undoes it. `MigrationStage.custom`'s page has only its
  declaration: what each closure sees and what a throw leaves behind are not documented. The `#Unique` page doesn't say
  what a conflicting insert does; Apple's WWDC23 session "Model your schema with SwiftData" describes an upsert.
  `Calendar.startOfDay(for:)` returns, on a day without a midnight, "the first moment that did exist". A file's
  modification date (`URLResourceKey.contentModificationDateKey`) is a required-reason API: reason `C617.1` covers files
  "inside the app container, app group container, or the app's CloudKit container".
- ADR-0006: XP for the dad's actions, nothing lost, worlds by age only.

## Decision

### 1. A save that fails leaves nothing behind
- Every write in Data runs through one helper, `ModelContext.saveAllOrNothing(_:)`: it makes the changes and saves; if a
  change or the save throws, it calls `rollback()` and rethrows. That covers `SwiftDataProgressRepository` (`add`,
  `addUnlessRecorded`, `update`, `delete`), `SwiftDataProfileRepository.save`, `SwiftDataOutfitRepository.setChoice`
  and `SwiftDataSagaEraser.eraseAll`, whose own `do`/`catch` goes.
- Not `transaction(block:)`: its failure behaviour isn't documented.
- `setChoice` fetches and deletes the slot's row on the context, as the eraser does, instead of `delete(model:where:)`.
- Tested on a store that can't be written: a copy opened read-only, as the widget opens it, whose `save()` throws
  (`SharedStoreTests` already shows it). After each failed write the repository reads back exactly what is stored, and a
  first whose save failed is tried again, not called "already recorded". Production code gets no test seam.
- Migration closures need nothing: a throw there fails the migration.

### 2. A birth date is a calendar day, with one age rule on the Gregorian calendar
- **Domain:** `CalendarDay` (year, month, day on the Gregorian calendar, no time and no zone) and `Child.birthDay`,
  which replaces `birthDate`.
- **One age rule.** `Child.ageInMonths(on:)` counts completed months. Month *n* is completed on
  `Child.day(atMonths: n)`: the birth day plus *n* months, its day clamped to the month's length (31 January + 1 month is
  28 February, or the 29th in a leap year; 29 February + 12 months is 28 February). Years are months divided by 12, and
  the *n*th birthday is `day(atMonths: 12 × n)`. Worlds and quests (`UnlockRules`), home's companions, the weekly quest
  and reminder, the film's periods, its offers and the age it draws the child at all use it.
  `Child.ageInMonths(at:calendar:)`, `sagaDate(adding:_:calendar:)` and `sagaCompleted(_:at:calendar:)` are deleted.
- **The device gives only its time zone,** to know what day it is: today is `CalendarDay(now, in: timeZone)`. A period
  or an occasion starts at the first moment of its day in that zone (`CalendarDay.start(in:)`, through
  `Calendar.startOfDay`). An entry, still an instant, is in a period when it falls between those bounds. A world changes
  and its film is offered at the same moment.
- **No API that works out an age takes a calendar.** Home's, the film's and the profile's use cases take a `TimeZone`
  where they took a `Calendar`. The weekly highlights keep the device's calendar for the week (ADR-0023 §1, ADR-0024)
  and take only its time zone for the day. Dates shown on screen and in the film keep the device's calendar.
- **Entering:** the date pickers still edit a `Date` in the device's zone. `ChildDraft` stores the day the picker shows
  and gives it back as that day's start, so the time of day onboarding used to keep is gone. A birth day may be today,
  not later (`birthDay <= today`).

### 3. Stored as a day: schema version 5
- `SchemaV5` (5.0.0) is version 4 with three optional `Int` columns on `ChildRecord`: `birthYear`, `birthMonth` and
  `birthDay`. It is `CurrentSchema`. V4 → V5 is `.custom` with a `didMigrate` only: on version 5, where the old
  `birthDate` and the new columns both exist, each child without a day gets the day its `birthDate` falls on in the
  device's time zone, then one save. It captures nothing and can run twice.
- **Which time zone: the device's, when the app migrates.** The stored instant came from a date picker in the device's
  zone, so the day it falls on there is the day the dad picked, and the day "My family" shows him today. UTC would move
  the day for anyone who entered it before 02:00 in Athens, or at most hours in New Zealand. The zone it was entered in
  was never stored. A dad who has travelled since keeps the day his phone shows him now, and can change it in "My
  family".
- **`birthDate` stays a column in version 5.** What a throw in `didMigrate` leaves behind is not documented, so a row
  without a day reads the day of its `birthDate` by the same rule, and the next family save writes it. New rows write
  the start of their day in the device's zone, so the two never disagree. The column is dropped by the next version
  that changes `ChildRecord`, in the same way ADR-0042 §2 dropped `photoID`.
- **Optional columns,** as in ADR-0044 §6: that a default reaches existing rows is not documented.
- **No `#Unique`, no indexes and no non-optional `childID`** in this version (ADR-0042 §2). An upsert replaces a row
  without a word, and a migration that meets a duplicate fails, which ends at the "couldn't open" screen. They come with
  the sync ADR, after a stage that removes duplicates.
- **Tests:** a new fixture, `Tests/DataTests/Fixtures/StoreV4`, written by the version 4 build before the schema changes
  and never regenerated: a dad with a chosen look, one child born at 12:00 UTC and one at 23:30 UTC, entries with
  photos and a note, and a wardrobe choice. The app opens a copy read-write and finds everything as it was, each child
  with the day its old date falls on where the test runs. The widget opens a copy read-only at version 5, throws, and
  leaves the database and its write-ahead log byte for byte as they were; once the app has migrated, it reads it. A
  store left at version 5 with a day missing reads it from `birthDate`. The earlier fixtures still open.
- An older build cannot open a version 5 store; it shows the calm "couldn't open" screen (ADR-0026).

### 4. No silent new store in a release build
- `SharedContainer.directory()` throws `SharedContainerError.appGroupUnavailable` when iOS has no container for the
  group. Only debug builds fall back to the app's own Application Support, then `tmp`, as before.
- **The folder is found when the store opens.** `LocalStore.shared(readOnly:)` and `FilePhotoStore.sharedMoments()` look
  it up on first use, inside `StoreConnection.open()` and in each photo call. A missing group then takes the path of
  every other store that can't open (ADR-0026 §1): it is logged, the call throws and the next one tries again; the app
  shows "We couldn't open your saga" with "Try again"; the widget shows "Open DadSaga"; the weekly reschedule leaves
  notifications alone; the photo sweep (§6) doesn't run. Nothing new on screen, and the copy stays: what he recorded is
  still on the iPhone, in the group's folder.
- The rule is a function of what iOS returned, `SharedContainer.directory(group:fallback:)`, so tests check it without
  an entitlement. `SharedContainer` becomes internal to Data: the app and the widget stop passing folders.
- CI builds Debug only, so the release branch is checked by a local Release build before the PR.

### 5. Content ids that have shipped never go
- An id that has been in `develop` stays in the content, as an item's `id` or in its `formerIDs`. The owner's phone runs
  `develop` builds, so `develop` is where an id ships.
- **Renaming:** give the item its new `id` and put the old one in `formerIDs` (an optional array on worlds, quests,
  bosses, firsts, heroes and gear). Wherever the app looks up an id it stored, a former id finds the item: an event's
  content (through `Timeline`, so XP, gear, the timeline and the film), the dad's hero, a wardrobe choice, the world in
  an answered film offer, and the quest in a link from a notification or the widget. Stored rows are never rewritten.
- **An id is a name, not an address:** moving a card to another world or age keeps its id (`q-w2-car-seat` can live in
  the first world).
- `ContentValidator` checks former ids with the current ones: no id, current or former, appears twice in the catalog.
- **The fixture** `Tests/DataTests/Fixtures/ShippedContentIDs.json` lists every id in `develop` today by kind (4 worlds,
  6 heroes, 55 quests, 16 bosses, 24 firsts, 8 gear items), with what an entry earned: the skill and XP of each quest and
  boss, the XP of each first, the skill and threshold of each gear item. It is appended to, never edited. Tests, on the
  bundled content:
  1. every shipped id is in it, as an id or a former id of an item of the same kind;
  2. every id in it is in the fixture, so content added in a PR is recorded in that PR;
  3. every former id in it is a shipped id, so a typo can't protect nothing;
  4. a shipped quest, boss or first keeps its skill and earns no less XP, and a shipped gear item keeps its skill and
     needs no more XP. Lowering one would take XP away, and moving a skill could take gear off the hero (ADR-0006 rule 2).
- **Retiring a card without a successor of the same kind** is stopped by these tests. A quest folded into a boss can't
  take its events with it: a quest counts every time, a boss once. Retiring needs its own decision when the first such
  card comes.
- **A hero the content doesn't know**, even by a former id, is shown as the first hero, which is also how its look is
  drawn (ADR-0029): on home, in the wardrobe, in the film, and on "Your hero", where it is the one selected.
  `ProfileRules.validatedChildren` checks only the children, so "My family" saves the family and leaves the stored hero
  as it is. The hero changes only when the dad changes something on "Your hero". No message, and nothing to choose again
  (ADR-0006).
- Not covered: the film's music choice, a preference that already falls back to the first track (ADR-0046 §4), and the
  look options, which are Domain cases the validator ties to the content (ADR-0044 §3).

### 6. Orphan photos are swept at launch, carefully
- `SweepOrphanPhotosUseCase` runs once per launch, off the main actor, in the app only: the widget never writes.
- **Kept:** every photo id on every stored entry, whatever its child, kind or content, including entries the app doesn't
  show (a removed child's, unknown content, rows the mapper skips). They are read by
  `ProgressRepository.referencedPhotoIDs()` from the rows themselves, not through `fetchEvents()`, whose mapping
  decides what is shown and will change.
- **Deleted:** files in `MomentPhotos` named `<UUID>.jpg` that no entry points to and that are at least 24 hours old.
  Anything else in the folder is left alone.
- **It never runs when the saga can't be read.** If reading the profile or the photo ids throws, nothing is deleted: a
  store that can't be read would otherwise look like one that points to no photo.
- **It never runs without a profile.** An empty store may be one that was lost, and then its photos are all that is
  left. After a start over that was cut short, the leftovers go at the first launch after onboarding.
- **It never deletes a recent file: 24 hours.** A photo is written before its entry. For about a second it is in the
  folder and in no entry, while the sweep may be running: it starts with the app, and the dad may save at once. The
  first save can also wait for the store to open and migrate. A day covers that and a clock set by hand; a file without
  a date, or dated in the future, is kept. An orphan waits a day, about a megabyte; a deleted photo is lost for good.
- **Files first, entries second.** The sweep lists the files, then reads the entries, so a listed file is deleted only
  if no entry pointed to it after it was listed. No write points an entry at a file already on disk unless the entry
  has it already: an edit keeps only the ids the entry has (ADR-0042 §1).
- Modification dates are a required-reason API. The app has no privacy manifest yet: this change adds the use, and the
  manifest that the release-prep work adds must declare `NSPrivacyAccessedAPICategoryFileTimestamp` with `C617.1`,
  beside `UserDefaults`'s `CA92.1`, before any upload to App Store Connect.

### 7. Where the code goes

| Layer | Adds | Changes or removes |
|---|---|---|
| Domain | `CalendarDay`; `ContentItem` (`id`, `formerIDs`, `has(id:)`); `ContentCatalog` lookups by stored id (`quest(id:)`, `boss(id:)`, `first(id:)`, `world(id:)`, `gearItem(id:)`, `heroClass(id:)`, `hero(for:)`, `canonical(_:)`); `ProfileRules.validatedChildren` | `Child.birthDay` replaces `birthDate`; `ageInMonths(on:)` and `day(atMonths:)` replace `ageInMonths(at:calendar:)`, `sagaDate` and `sagaCompleted`; `SagaPeriod`, `SagaOccasions`, `SagaStoryboard` take a time zone; `Timeline`, `GearRules.equipped`, `WeeklyQuest.isDone` find former ids; `formerIDs` on six entities |
| Application | `SweepOrphanPhotosUseCase`; `PhotoStore.storedPhotos()` with `StoredPhoto`; `ProgressRepository.referencedPhotoIDs()`; `HomeOverview.today` | `Adventure(for:childCount:catalog:on:)` takes a `CalendarDay`; home, film and profile use cases take a `TimeZone`; `UpdateFamilyUseCase` no longer reads the content; `GetHeroChoiceUseCase`, `GetWardrobeUseCase` and `ProgressRecorder` resolve former ids |
| Data | `ModelContext.saveAllOrNothing`; `SchemaV5` and its stage; `SharedContainerError`; `LocalStore.shared`; `FilePhotoStore.sharedMoments` and `storedPhotos`; `formerIDs` in the DTOs; the `StoreV4` and `ShippedContentIDs.json` fixtures | every SwiftData write; `ChildRecord`'s mapping; `SharedContainer` (throws in release, internal); `StoreConnection` finds its folder when it opens; `ContentValidator` |
| Presentation | | `ChildDraft` converts between the picker's date and the day; home's companions use `HomeOverview.today`; the moment date pickers start at the birth day; a quest link finds a former id |
| App and widget | `AppContainer.sweepOrphanPhotos()`, called at launch | `DeviceData` carries the photo store, not a folder; `WidgetContainer` opens `LocalStore.shared(readOnly: true)` |

### Deferred
- Dropping `ChildRecord.birthDate`: with the next version that changes the child.
- `#Unique`, indexes and the non-optional `childID`: with the sync ADR (ADR-0026 §6).
- Retiring a card without a successor; former ids for the film's music.
- Corrected age for children born early: its own decision.
- Export and backup (ADR-0004).

## Verification status
Not yet checked on a device. To check:
- installing over a version 4 build: every child's date of birth as before in "My family", home's world and age
  unchanged; the widget before the app opens (it shows "Open DadSaga" until the app has migrated) and after;
- the time zone set to Auckland and to Los Angeles: the same date of birth, age and world;
- the region's calendar set to Islamic and to Hebrew: the same age and world as on the Gregorian calendar, and dates
  shown in the chosen calendar;
- a Release build without the App Group: the "couldn't open" screen, never onboarding;
- the app killed while saving an entry with photos: its photos are still there at the next launch and gone a day after.

## Consequences
- A failed save can be retried at once, and nothing half-written reaches the store later.
- Every age in the app comes from one function, by the day, on the Gregorian calendar: a world, its film offer and the
  weekly quest change on the same day for everyone, wherever the phone is and whatever calendar it uses. On a phone
  that uses another calendar, a world that opened early by its months closes again until the Gregorian age reaches it.
  No release is installed yet, so no dad sees that.
- One stored version more, a column kept for one version, and three more small binary files for the `StoreV4` fixture.
- A release build that can't find its App Group stops at the calm screen instead of starting a new saga.
- Every new card, hero, gear item or world adds a line to `ShippedContentIDs.json` in the same PR; a rename keeps the
  old id in `formerIDs` for good, and a card's skill and XP can't move against the dad.
- Photos nothing points to are removed a day after they are left, never while the saga can't be read and never before
  onboarding. The privacy manifest, still to be added before the first upload, must carry a file-timestamp reason.
