# ADR-0060: Nothing has shipped before the first App Store release: one store version, no shipped content, TestFlight testers start over, and the guards recorded at that release

**Status:** Accepted (2026-11-22). The owner (2026-11-22): "keep in mind there is no live app, and delete whatever that
affects." His decisions of the same day are final:
- ADR-0055's gear from before titles goes.
- His phone and every other device running `develop` hold only test data, which he doesn't mind losing.
- The `formerIDs` and `retired` mechanisms stay, with no data in them (§4).
- The baseline is tightened: `childID`, `hasPartner` and the look columns become non-optional (§2).
- `SchemaV1` changes in place until something ships (§2).
- "Shipped" means an App Store release only, not TestFlight. Until the first one, TestFlight testers start over
  whenever the store or the ids change. What ships is recorded at that release (§1, §5, §6).

Drafted by the architect. It changes:
- **ADR-0026** §2 and §4: until the first App Store release the store has one version, `SchemaV1`, changed in place.
  The fixture from before versions and the widget test before V2 go, and `childID` is non-optional now. §1 and §3 stay.
- **ADR-0034** §6: the widget test against older stores goes until a second version exists.
- **ADR-0042** §2, **ADR-0044** §6, **ADR-0048** §3, **ADR-0053** §8 and **ADR-0055** §5: versions 2 to 7, their
  stages and the `StoreV1`, `StoreV3`, `StoreV4`, `StoreV5` and `StoreV6` fixtures are folded into the one version.
- **ADR-0048** §5, and **ADR-0005** through it: an id ships with the first App Store release, not with `develop`.
  Today's former ids and `ShippedContentIDs.json` go; the file and its tests are written at that release.
- **ADR-0053** §6 and §7: the four retired cards and the seven former ids go. The rule for retiring a card stays, for
  after the first App Store release.
- **ADR-0055** §3, §4, §5, §9, §11 and choice 5, and **ADR-0014** through it: no gear from before titles. Recording
  keeps nothing; only a deletion keeps the title.
- **ADR-0057** §3 and §4: format 1 of a copy of the saga is frozen from the first App Store release, not before. Its
  `standing.gearIDs` goes. The fixture copy has no such key, so it still reads unchanged.
- **ADR-0059** §1 and §2: the shipped title orders and skill curves are recorded at the first App Store release.
- **ADR-0051:** the release checklist records what ships at the first App Store release, and each TestFlight build
  before it says whether its testers delete the app first.
- **ADR-0048** is marked Accepted: it was merged while still Proposed.

## Context
- **No build has left the owner's hands.** There is no App Store or TestFlight build. The stores on his phone and on
  the devices running `develop` hold test data only.
- **What exists only for those stores:**
  - Seven schema versions (`SchemaV1` … `SchemaV7`) and six stages in `DadSagaMigrationPlan`. Three of the stages are
    custom: `copyPhotoIDs`, and `fillBirthDays` twice.
  - Six fixture stores (`StoreBeforeV1`, `StoreV1`, `StoreV3` … `StoreV6`): eighteen binary files, each folder with a
    file describing it. They are opened by `StoreMigrationTests`, `WidgetBeforeMigrationTests` and some of the tests in
    `StoreVersioningTests` and `TitlesStoreTests`.
  - Columns that are optional only because older rows lacked them: the look (rows from version 3), `hasPartner`
    (version 5) and `ProgressEventRecord.childID` (rows from before ADR-0023). Each has a nil branch in a mapper.
  - The gear from before titles: `keptGearIDs`, `GearItem.skillXPBeforeTitles` with its eight values in `gear.json`,
    `GearRules.earnedBeforeTitles`, `KeptStanding.gearIDs`, the freeze at the first change in `DadStanding` and
    `StandingKeeper`, and a line on each privacy page.
  - In the content, seven former ids (six quests and `f-celebration`) and four retired cards (`q-w1-tummy-time`,
    `q-w2-rough-play`, `q-w3-ten-breaths` and `f-sleepover`). They are kept because ADR-0048 §5 counted `develop` as
    the place where an id ships.
  - `ShippedContentIDs.json` and `ShippedContentIDsTests`: every id, XP value, skill, threshold, title order and curve
    that was ever in `develop`. Before a release they stop the card reviews from renaming, deleting or lowering
    anything.
- **What a released app still needs:**
  - the calm "couldn't open" screen and a store that is never replaced (ADR-0026 §1, ADR-0048 §4);
  - the widget opening the store read-only, without the plan (ADR-0053 §8);
  - a versioned baseline, since SwiftData runs a staged migration only from a version it knows (ADR-0026);
  - `formerIDs`, retiring a card, and the guards on shipped content (ADR-0048 §5, ADR-0053 §6, ADR-0055 §11,
    ADR-0059);
  - the orphan-photo sweep (ADR-0048 §6), for an app killed between saving a photo and saving its entry, and for a
    start over cut short;
  - the kept title and the title last seen (ADR-0055 §3, §6).
- **TestFlight** (`docs/RELEASE.md`): builds are uploaded from the release branch, and each takes a build number. A
  TestFlight build that is never released gets no tag. A TestFlight build has the App Store build's bundle id, so it
  installs over the app on a tester's phone and opens the store already there.
- **A precedent:** ADR-0023 §2 left development data behind once ("the old store stays behind in the old folder and the
  dad onboards again") and deleted `LegacyProfileMigration`.
- **What Apple documents (checked 2026-11-22):**
  - `SchemaMigrationPlan`, `VersionedSchema` and `ModelContainer.init(for:migrationPlan:configurations:)` have only
    abstracts and declarations. Nothing says what happens to a store whose version or shape matches no schema in the
    plan. The initializer only `throws`.
  - `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`: on iOS, "when all the apps in a given app group
    are removed from the device, the system detects this condition and removes the corresponding group directory as
    well." Deleting DadSaga, which carries its widget, removes the store and the photos.
  - This store has already started from one version with no stages (ADR-0026 §2). Opening an older store read-only
    throws and leaves it unchanged, which the fixtures measured (ADR-0034 §6, ADR-0053 §8).
  - Nothing here needs an API newer than iOS 26.
- ADR-0006: XP for the dad's actions, nothing lost, no streaks, no deadlines. No dad has a saga yet, so nothing here
  takes anything from one.

## Decision

### 1. Shipped means released on the App Store
- A build **ships** when it is released on the App Store. A TestFlight build doesn't ship (the owner's decision).
- **Before the first App Store release,** nothing has shipped. No stored shape and no content id has to be kept for
  anyone, TestFlight testers included. The schema, ids, XP values, titles and curves change as the work needs. A
  TestFlight tester starts over when a build changes the store or an id (§6).
- **A copy of the saga** (ADR-0057) follows the same rule: format 1 changes in place until that release. Its
  `standing.gearIDs` goes (§3). A copy made by an earlier `develop` build still reads, since an unknown key is ignored,
  and the `SagaCopyV1` fixture has no such key, so it isn't regenerated. The hand-written format-1 test keeps a
  `gearIDs` key to pin that.
- **From the first App Store release,** the rules of ADR-0026 §2, ADR-0048 §5, ADR-0053 §6, ADR-0055 §11 and ADR-0059
  §1–§2 apply to what that build carried (§5).

### 2. One stored version: `SchemaV1`
- **`SchemaV1`** (1.0.0) is the only version. It has the shape the app would have had from the start (the owner's
  decision):

  | Record | Columns |
  |---|---|
  | `ProfileRecord` | `heroClassID`, `dadSkinTone`, `hairStyle`, `hairColor`, `beard`, `glasses`: `String`; `hasPartner: Bool`; `heldTitleID`, `seenTitleID`: `String?` |
  | `ChildRecord` | `childID: UUID`; `name: String`; `birthYear`, `birthMonth`, `birthDay`: `Int?` (all three nil: not born yet); `gender`, `skinTone`: `String`; `order: Int` |
  | `ProgressEventRecord` | `eventID: UUID`; `kind`, `contentID`: `String`; `childID: UUID`; `date: Date`; `note: String?`; `photoIDs: [String]` |
  | `OutfitRecord` | `skill`, `choice`: `String` |

  - A column is optional only where nil means something: a child not born yet, no title kept yet, no title card
    closed yet, an entry without a note.
  - There are no literal defaults. `dadSkinTone`'s and `photoIDs`' defaults came from earlier stages.
  - There is no `#Unique` and no index (deferred, as in ADR-0048 §3).
- `SchemaV2` … `SchemaV7` are deleted. `DadSagaMigrationPlan` lists `[SchemaV1]` and no stages, as ADR-0026 §2 first
  had it, so `copyPhotoIDs` and `fillBirthDays` go. `CurrentSchema` stays the one name the rest of Data uses.
- **What stays:**
  - A store that can't be opened stops at the calm screen, and nothing on disk changes (ADR-0026 §1).
  - A release build without its App Group opens nothing (ADR-0048 §4).
  - The widget opens the store read-only, without the plan (ADR-0053 §8).
  - Every configuration passes `cloudKitDatabase: .none` (ADR-0026 §3).
- **Mappers:**
  - A profile reads its look and partner answer as stored. An unknown look value still reads as the standard look for
    the skin tone: the look is stored as strings, not as enums (ADR-0044 §6).
  - An event of a kind the build doesn't know is still skipped. The skip for a row without a child goes.
- **Until the first App Store release, `SchemaV1` is changed in place** (the owner's decision). A PR that changes it
  says so in its description. Devices running `develop` delete the app before installing it, and the next TestFlight
  build's notes say the same (§6).

### 3. No gear from before titles (the owner's decision)
- Gear comes only with titles. The hero has what his title brings and what every title below it brings
  (`DadStanding.gear`).
- **What goes:**
  - `GearItem.skillXPBeforeTitles`, its eight values in `gear.json`, and `GearRules.earnedBeforeTitles`.
  - `KeptStanding.gearIDs`, and `KeptStanding.fresh`: a new saga is `KeptStanding()`.
  - The gear from before titles in `DadStanding`'s initializer, in `asOf`, which no longer takes what was kept, and in
    the title card's list.
  - The freeze at the first change: `DadStanding.toKeepBeforeRecording`, the only thing recording kept. Recording now
    keeps nothing, so `StandingKeeper` goes, and `ProgressRecorder` and the three use cases that record (a quest, a
    boss, a first) no longer take a `StandingRepository`.
- **Before a deletion,** `DadStanding.titleToKeep` (it replaces `toKeepBeforeDeleting`) is the title the dad holds
  when it is higher than the kept one. `DeleteEventUseCase` keeps it before deleting; if that write fails, nothing is
  deleted.
- **`StandingRepository.keep(titleID:)`** writes the title only, at most once per title.
- **What stays:** the kept title and the title last seen (ADR-0055 §3, §6). A skill names its slot and grows its mark
  (ADR-0059), and unlocks nothing.
- **The privacy pages** drop "the gear you already had before titles" and «τον εξοπλισμό που είχες ήδη πριν από τους
  τίτλους» (ADR-0051). The manifests don't change.

### 4. Content: nothing has shipped
- **The seven former ids go:** `q-w1-first-aid` (on `q-w0-first-aid`), `q-w2-car-seat`, `q-w4-check-in`,
  `q-w2-date-night`, `q-w2-toothbrush`, `q-w4-swim` and `f-christmas`. The cards keep the ids they have now.
- **The four retired cards go:** `q-w1-tummy-time`, `q-w2-rough-play`, `q-w3-ten-breaths` and `f-sleepover`. ADR-0053
  §6 deletes a card that hasn't shipped, and none has.
- **`ShippedContentIDs.json` and `ShippedContentIDsTests` go.** They are written again at the first App Store release
  (§5).
- **The mechanisms stay, with no data in them** (the owner's decision), and with their tests on made-up content:
  - `formerIDs` on the seven kinds: `ContentItem.has(id:)`, the catalog's lookups by any id, `canonical(_:)`, the film
    offer's `answerIDs`, and the validator's check that ids are unique;
  - `retired` on quests and firsts;
  - a hero the content doesn't know, shown as the first hero.
- **Until the first App Store release, a rename or a removal changes the id** and adds no former id, and a dropped card
  is deleted, not retired. After that release, a rename or a retirement uses the mechanisms without a new design.

### 5. At the first App Store release: record what ships
This is done once, on the first release branch, for the build submitted for review (`docs/RELEASE.md`). It reaches
`develop` when `main` is merged back. If review asks for another build, the record follows that build. It is fixed once
the build is released. It adds:
- **`Tests/DataTests/Fixtures/ShippedContentIDs.json`,** from the bundled content:
  - every world, hero, quest, boss, first, gear item and title id;
  - each quest's and boss's skill and XP, and each first's XP;
  - each gear item's skill;
  - each title's order, cards, XP and gear;
  - each skill's `halfGrownXP`.

  From then on it only grows.
- **`ShippedContentIDsTests`,** as this decision deletes it, without the `skillXPBeforeTitles` checks. It checks that:
  - every shipped id stays, as an id or a former id;
  - every current id is listed;
  - every former id and every retired card shipped;
  - nothing earned goes down or moves skill;
  - no title asks for more or moves;
  - no curve grows slower.
- **`Tests/DataTests/Fixtures/StoreV1`,** written by that build and never regenerated. It holds:
  - a dad with a look and a partner answer;
  - a child who is born and one who is not born yet;
  - a quest, a boss and a first, with photos and a note;
  - a wardrobe choice;
  - a kept title and a closed title card.
- **Its tests:**
  - The app opens a copy read-write and finds everything.
  - The widget opens a copy read-only and reads it. While `SchemaV1` is current, this is the test that shows the
    released shape hasn't been edited: the app's read-write open would migrate an edited shape silently whenever
    SwiftData can infer the change (§6), so only the read-only open, which never migrates, fails on it. The first
    `SchemaV2` turns it into the test of ADR-0034 §6: the widget fails without touching the store until the app has
    migrated it.
- **`Tests/DataTests/Fixtures/SagaCopyV1`,** the copy of the saga in format 1 (ADR-0057 §4), recorded again with that
  build and fixed from then on, never recorded again.
- **The two rule files** (`.claude/rules/domain-and-data.md`, `.claude/agents/content.md`) lose their "until the first
  App Store release" rules.
- **From then on,** every stored change is a new version with a stage and a fixture (ADR-0026 §2). Content follows
  ADR-0048 §5 and ADR-0053 §6.

### 6. Starting over before the first App Store release
- **A build "changes the store or the ids"** when, since the last uploaded build, `SchemaV1` has changed, or a content
  id has been renamed or removed. Adding cards, or changing words, XP, titles or curves, needs no start over.
- **TestFlight testers:**
  - The release branch's commit that set the last uploaded build number is the build to compare with.
  - When a build changes the store or the ids, its notes for testers ("What to Test") say, in Greek and English, to
    delete DadSaga before installing it, and that what was recorded in earlier builds isn't kept.
  - Deleting the app removes the store, the photos and the app's defaults: iOS removes the group's folder once its
    apps are gone.
- **A tester who installs without deleting:**
  - If the store changed, what happens depends on his rows (measured on 2026-11-22, `OlderStoreTests`). The app opens
    the store with a plan of `[SchemaV1]` only, so SwiftData migrates it by inference when it can: a column made
    non-optional is inferred whenever no row holds nil in it, and a dropped column is dropped. A `develop` store
    from before this change opens that way, silently, without `keptGearIDs`. When a row holds nil in a column that is
    now required, opening throws, the store is left unchanged, and the app shows "We couldn't open your saga" with
    only Try again. Deleting the app is the way out. Nothing on that screen deletes the store (ADR-0026 §1).
  - The widget opens the store read-only, without the plan, so it never migrates: on a changed store it always
    fails and leaves the store as it was, until the app has opened it.
  - So a silent migration is not a promise either: "delete the app first" stays the rule for every build that
    changes the store.
  - If only an id changed, the app opens. Entries under the old id drop out of the timeline, the XP and the film, as
    for any id the content doesn't know (ADR-0005). His kept title stays, unless that title's id changed.
- **Devices running `develop`:** delete DadSaga before installing the build with this change, and again whenever a
  `develop` build changes the store. Running from Xcode installs over the app and keeps its data, so delete the app
  first. The simulators that `ui-check` and the snapshots use are cleared the same way.
- **Why neither outcome is promised:** what SwiftData does with a store whose shape no schema in the plan has is not
  documented. What `OlderStoreTests` pins, from a test-only older schema: the widget's read-only open throws and
  changes nothing, and a nil in a column `SchemaV1` requires makes the app's open throw.
- **The first TestFlight build** is installed on phones with no `develop` build, so it starts from onboarding as a
  dad's would.

### 7. Where the code goes
| Layer | Removes | Changes |
|---|---|---|
| Domain | `GearItem.skillXPBeforeTitles`; `GearRules.earnedBeforeTitles`; `KeptStanding.gearIDs` and `.fresh`; `DadStanding.gearBeforeTitles` and `toKeepBeforeRecording` | `DadStanding`'s initializer, `asOf(_:catalog:)` (no `kept`), `news`; `toKeepBeforeDeleting` becomes `titleToKeep` |
| Application | `StandingKeeper`; the gear argument of `StandingRepository.keep`; the `StandingRepository` of `ProgressRecorder`, `DefaultCompleteQuestUseCase`, `DefaultDefeatBossUseCase` and `DefaultCaptureMomentUseCase` | `DeleteEventUseCase` keeps `titleToKeep`; `GetSagaFilmUseCase`'s call to `asOf` |
| Data | `SchemaV2` … `SchemaV7` (version 7's models become `SchemaV1`'s), the six stages, `copyPhotoIDs`, `fillBirthDays`; `GearItemDTO.skillXPBeforeTitles`; the former ids and retired cards in `quests.json` and `firsts.json`; the eight thresholds in `gear.json` | `SchemaV1` (§2); `DadSagaMigrationPlan`; `CurrentSchema`; the `ProfileRecord` and `ProgressEventRecord` mappings; `SwiftDataProgressRepository` (its predicate's `UUID?`); `SwiftDataStandingRepository`; `ConnectedStandingRepository`; `SwiftDataWholeSagaRepository`; `SagaCopyV1DTO` (no `standing.gearIDs`); the gear mapper |
| Data tests | `StoreMigrationTests`; `WidgetBeforeMigrationTests` with `StoreFiles`; `StoreFixture`, `StoreV1Fixture`, `StoreV3Fixture` … `StoreV6Fixture` and the six `Fixtures/Store…` folders; `ShippedContentIDs.json` and `ShippedContentIDsTests`; `CalendarDay.migrated`; in `StoreVersioningTests`, the two tests of the store from before versions and the one of an event without a child; the three version 6 tests in `TitlesStoreTests` | the rest of `TitlesStoreTests` saves a profile of its own; `OrphanPhotoSweepTests` keeps its row of an unknown kind and loses the row without a child; `BundledContentRepositoryTests` loses its list of retired cards and counts the cards left; the copy's tests of gear never frozen and of gear none go, and the hand-written format 1 has no `gearIDs`; the test of an unknown look part stores an unknown beard, not a missing one; new: `OlderStoreTests`, from a test-only older schema and no fixture (the widget's read-only open throws and changes nothing; a nil in a required column makes the app's open throw), and three `StoreVersioningTests` of updating a stored child's birth day and the dad's look and partner answer, which the migration tests used to cover |
| Other tests | `GearRulesTests`' three tests of the old rule; the tests "from before titles" in `TitleTests` and `StandingUseCaseTests` | made-up `GearItem`s lose `skillXPBeforeTitles:`; `KeptStanding.fresh` becomes `KeptStanding()` (`FakeProgress`, `UseCaseTests` and others); a failed keep is tested on a deletion only |
| Presentation | | none. Nothing on screen changes |
| App | | `AppContainer` and the snapshots' `SagaFixture`: the recording use cases without a `StandingRepository` |
| Web and docs | | both privacy pages (§3); `docs/RELEASE.md` (below); `docs/ROADMAP.md` (the draft V2 item, the calm screen's check on a device, and the sync item, which no longer needs a non-optional `childID`); the two rule files (§5); ADR-0048's status |

**`docs/RELEASE.md`:**
- **Once, at the first App Store release:** record what ships (§5), for the build submitted for review, on the release
  branch.
- **Every TestFlight build before it:** compare with the last uploaded build (§6). If the build changes the store or
  the ids, its notes say, in Greek and English, to delete DadSaga before installing it.
- **Step 6 (TestFlight):** install the build on a phone without a `develop` build.

## Rejected
- **Keeping versions 1 to 7 and adding an eighth without `keptGearIDs`:** six versions, three custom stages and
  eighteen fixture files for stores no dad has, and one fixture more.
- **A baseline numbered 8:** a number that points at versions that are gone.
- **A reset on the calm screen in debug or TestFlight builds, or deleting a store that doesn't fit:** ADR-0026 §1
  keeps that screen from touching the disk, and a path the App Store build never takes is not what ships. Deleting the
  app does the same, and iOS removes the group's folder with it.
- **A screen that tells a TestFlight tester to delete the app:** the same path. The build's notes say it.
- **Counting TestFlight builds as shipped:** the store's shape and every id would be fixed at the first tester (the
  owner chose the App Store release).
- **Resetting `ShippedContentIDs.json` to today's content:** it would freeze ids, XP values, titles and curves before
  anything has shipped, while the card reviews still change them.
- **Keeping the retired cards' words:** they are there for entries no one has.

## Deferred
- **TestFlight after the first App Store release.** A tester's TestFlight build then opens the saga his App Store app
  wrote, so starting over would lose a real saga. Whether a schema version or an id that has only been in TestFlight
  builds since that release may still change is decided before the first update goes to TestFlight.
- `#Unique` and indexes, with the sync ADR (ADR-0026 §6, ADR-0048 §3). A new store has no duplicates, but an upsert
  would still replace a row without a word.
- A check that fails when the step at the first App Store release (§5) was skipped. The checklist covers it once.

## Verification status
Not yet checked on a device. To check:
- **On one device still on a `develop` build,** install over it once. Its store most likely migrates silently (§6):
  check that the saga reads back, and that the widget shows "Open DadSaga" until the app has opened once. Then
  delete the app.
- **The calm screen** needs a store that can't be opened: a row with nil in a column `SchemaV1` requires (a debug
  build can write one), or a junk store file. Check it in Greek and English, with Try again, and trying again on
  returning to the foreground. This is also the screen's first check on a device (ROADMAP, "not checked on a
  device: it needs a damaged store").
- **On every device running `develop`:** delete the app, install, and check onboarding, a first quest (Level 1 and the
  mug), a first with photos, the widget, the film and start over.

## Consequences
- Data has one schema file and no stages. Three test suites (`StoreMigrationTests`, `WidgetBeforeMigrationTests`,
  `ShippedContentIDsTests`), about twenty more tests and eighteen binary files go.
  `gear.json`, `quests.json` and `firsts.json` lose what only `develop` stores needed.
- Every device running `develop` starts over once, and again whenever `SchemaV1` changes before the first App Store
  release.
- Until that release, a card can be renamed, moved, given other XP or deleted, and titles and curves can be tuned, with
  nothing to keep in step.
- TestFlight testers keep their saga from build to build only while the store and the ids stay as they are. A build
  that changes either asks them in its notes to delete the app first.
- A tester who misses that note and installs over a changed store may keep his saga through a silent migration, or
  see the calm screen, whose copy speaks of free storage. Then only deleting the app helps him.
- The first App Store release has one more step. If it is missed, the first rename after release goes unguarded.
- After it, everything ADR-0026 and ADR-0048 promise holds again, from a shorter start: the first migration starts
  from `StoreV1`.
- The "couldn't open" screen gets its first check on a device.
