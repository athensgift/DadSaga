# Plan: the v1 card set

Implements [ADR-0051](../adr/0051-v1-card-set-before-birth-audiences-and-retired-cards.md). Inputs: the owner's review of
the card set (2026-11-21, two rounds) and the set itself (190 cards). Every kept card ships in v1, World 0 included.

## Decisions taken
1. **A child "not born yet"** is a switch under the name in the child editor (onboarding and "My family"), as the owner
   asked. While it is on, no date is kept: no due date, no countdown (ADR-0051 §1). `Child.birthDay` is optional;
   `Child.age(on:)` returns `.beforeBirth` or `.months(n)`, one rule for everything.
2. **Unticking it and saving a day** makes the child born that day: same child, so everything recorded before the birth
   stays theirs. World 1 opens by age; World 0 becomes a visited world. Ticking a born child again is allowed.
3. **World 0 is `w0-harbour`**, order 0, `"beforeBirth": true` and no ages (A1/A2: `w0-base-camp` never shipped).
   It is the current world before birth and a visited world after it; its cards have `minAgeMonths` 0.
4. **In the film** World 0 is a period and a chapter; its film is offered on the birth day for 30 days, if there is an
   entry in it. A child not born yet is drawn as a small mark beside the hero (an SF Symbol; `HeroArt` doesn't change).
5. **Firsts before birth** carry `"beforeBirth": true` (A8): `f-found-out`, `f-first-picture`. Before the birth only
   they are offered; they can be dated any day up to today. Orders renumbered 1–34.
6. **Who a card is for:** one field, `onlyFor`, with `partner`, `olderSibling`, `youngerSibling`. It replaces
   `requiresSibling`. `requiresBirthPartner` becomes `partner`. `twoHomes` and `requiresPregnancy` are not added (both
   two-homes cards were dropped; A14).
   - `partner`: `q-w1-invisible-jobs`, `q-w1-check-in`, `q-w1-close-again`, `q-w1-date-night`, `q-w0-the-talk` (A15),
     `b-w1-fourth-trimester`.
   - `olderSibling`: `q-w1-meet-the-crew` (owner: only with an older child). Twins have no older sibling.
   - `youngerSibling`: `b-w3-new-sibling`, narrowed from "more than one child"; a sibling on the way counts.
7. **The facts the dad gives:** whether each child is born (the switch), and one family answer, "I'm raising them with
   a partner" (on by default; every existing profile reads yes). Siblings come from the birth days.
8. **Situational bosses** (`b-w4-two-homes`, `b-w4-big-goodbye`, `b-w4-big-move`) sit in one closed row at the end of
   the world's cards, "When life changes". **Evergreen bosses** (`b-w1-double-shift`, `b-w2-long-grind`, found in the
   set's meta lines) show in later worlds like evergreen quests.
9. **Retiring a shipped card:** `"retired": true` keeps it in the content (words, skill, XP) for past entries and
   never offers it again. Retired: `q-w1-tummy-time`, `q-w2-rough-play`, `q-w3-ten-breaths` (folded into the boss
   `b-w3-red-mist`, another kind), `f-sleepover`. Moves within a kind use `formerIDs`: `q-w2-car-seat → q-w1-car-seat`,
   `q-w2-toothbrush → q-w1-toothbrush`, `q-w2-date-night → q-w1-date-night`, `q-w4-swim → q-w2-swim`,
   `q-w4-check-in → q-w1-check-in`, `f-christmas → f-celebration`. All keep skill and XP (ADR-0051 §6 table).
10. **Schema V6:** `ChildRecord.birthDate` goes (after a `willMigrate` fills any missing day); empty day columns mean
    "not born yet"; `ProfileRecord.hasPartner: Bool?`.
11. **When no world fits** (a child older than every world, or not born with no world before birth in the content),
    home and the weekly quest say "coming soon", as today for a child over six.

## Questions for the owner
**Answered 2026-11-21: the owner chose the recommendation on all four** (first aid folds into `q-w0-first-aid` and is
evergreen; tracks of at least 130 s in their own PR; the partner question, on by default; "When life changes").

1. **`q-w1-first-aid` is in `develop` too** (care, 35 XP), though decisions.md marks only tummy time and rough play as
   existing. It can't disappear. *Recommended:* `q-w0-first-aid` takes it as a former id (same skill and XP), and
   becomes `evergreen` with "baby and child first aid" wording, so a dad who starts after the birth still has first aid
   on home. *Otherwise:* retire it; first aid then lives only in World 0, which a born child's dad reaches from the map.
2. **More firsts than the music:** an "everything" film can reach about 124 s (33 firsts and the retired one at 3 s,
   five chapter cards, opening, credits); the tracks are 95 s and loop. *Recommended:* make every track at least 130 s,
   with a test that fails when the content outgrows the music; firsts are never dropped. *Otherwise:* keep the loop, or
   cap the firsts in a film (against ADR-0036 §2).
3. **The partner question:** ask "I'm raising them with a partner" once in onboarding and in "My family", on by
   default, no reason asked. *Recommended:* yes. *Otherwise:* the six partner cards show to everyone, as date night and
   check-in do today.
4. **"When life changes":** the three situational bosses in one closed row at the end of the world's cards.
   *Recommended:* yes. *Otherwise:* they show like every other boss.

## The numbers
| | Offered | Retired (kept) | Entries in the JSON | New ids for `ShippedContentIDs.json` |
|---|---|---|---|---|
| Worlds | 5 | | 5 | 1 (`w0-harbour`) |
| Quests | 95 (W0 15, W1 29, W2 13, W3 21, W4 17) | 3 (4 if Q1 is "retire") | 98 | 49 |
| Bosses | 35 (W0 2, W1 10, W2 7, W3 8, W4 8) | 0 | 35 | 19 |
| Firsts | 33 (2 before birth) | 1 (`f-sleepover`) | 34 | 11 |

## Pull requests
CLAUDE.md: work that touches the same files goes in one PR. Two PRs, plus one for the music if the owner chooses it.

1. **`feature/card-model-v1`: the model, the rules, the store and the screens.** Every Swift change, the strings, the
   `StoreV5` fixture, and the one JSON field the model forces (`b-w3-new-sibling`: `requiresSibling` → `onlyFor`).
   Until PR 2, the content has no World 0: a child marked "not born yet" sees "Adventures for your child's age are
   coming soon." (decision 11), which is calm and true.
2. **`feature/card-set-v1`: the card set.** All four content files, `ShippedContentIDs.json`, the content counts. The
   content agent can start it in its own worktree branched from PR 1's branch; it merges after PR 1.
3. **(If Q2 is "lengthen") `feature/saga-music-length`:** `Tools/SagaMusic`, the five `.m4a` files and
   `soundtracks.json` in `SagaMusic`, and the length test. Independent of 1 and 2; before the first TestFlight build.

The only files both PR 1 and PR 2 touch are `bosses.json` (one field) and `BundledContentRepositoryTests.swift`, one
after the other.

## PR 1, step by step
Each step green (its suite with `--filter`) before the next; the whole package, `swiftlint --strict` and the Xcode
build before the PR.

### Step 0: the `StoreV5` fixture, first commit, with the code as it is
- `Tests/DataTests/StoreV5Fixture.swift` and `Tests/DataTests/Fixtures/StoreV5/` written by the version 5 build: a dad
  with a look, one child with day columns, one whose day columns are empty (written through `SchemaV5.ChildRecord`
  directly, with a `birthDate` late in the evening UTC), entries with photos and a note, a wardrobe choice. Never
  regenerated.

### Step 1: Domain
| File | Change |
|---|---|
| `Domain/Entities/ChildAge.swift` (new) | `enum ChildAge: Hashable, Sendable { case beforeBirth, months(Int) }` |
| `Domain/Entities/Child.swift` | `birthDay: CalendarDay?`; `isBorn`; `age(on:) -> ChildAge` replaces `ageInMonths(on:)`; `day(atMonths:) -> CalendarDay?` |
| `Domain/Entities/World.swift` | `span: WorldSpan` (`.beforeBirth`, `.months(min:max:)`) replaces `minAgeMonths`, `maxAgeMonths` |
| `Domain/Entities/Audience.swift` (new) | `enum Audience: String, CaseIterable, Sendable { case partner, olderSibling, youngerSibling }` |
| `Domain/Rules/FamilyFacts.swift` (new) | `FamilyFacts(profile:child:)`: `hasPartner`, `hasOlderSibling`, `hasYoungerSibling`; `allows(_: Set<Audience>) -> Bool` |
| `Domain/Entities/Quest.swift` | `onlyFor: Set<Audience>`, `isRetired` |
| `Domain/Entities/BossFight.swift` | `onlyFor`, `isSituational`, `isEvergreen`; `requiresSibling` goes |
| `Domain/Entities/FirstMoment.swift` | `isBeforeBirth`, `isRetired` |
| `Domain/Entities/PlayerProfile.swift` | `hasPartner: Bool`, default `true` |
| `Domain/Rules/UnlockRules.swift` | Rewritten on `ChildAge` and `FamilyFacts`: `unlockedWorlds(in:age:)`, `currentWorld(in:age:)`, `isBeyondContent(_:age:)`, `quests(for:in:age:family:)`, `bosses(for:in:age:family:)` (own and evergreen from earlier worlds, situational included and flagged), `isOffered(_:age:family:)` (not retired, reached, audience holds), `firsts(in:age:)`. `availableBosses` and `isPossible` go |
| `Domain/Rules/ProfileRules.swift` | `birthDateInFuture` only for a born child |
| `Domain/Entities/SagaPeriod.swift` | `.world` of the world before birth: up to the birth day (or open while not born); `.year` is `nil` before birth; `available` lists years only once born |
| `Domain/Rules/SagaOccasions.swift` | No birthdays before birth; the world before birth ends on the birth day |
| `Domain/Rules/SagaStoryboard.swift` | `childAge: ChildAge` replaces `childAgeInMonths`; an entry's world by `age(on:)`, so entries before the birth get World 0's chapter; the span of a film of a child not born starts at the first entry's day |
| `Domain/Rules/DadProgress.swift` | `progress(in:catalog:childID:)` counts every boss beaten; `childCount` goes |

### Step 2: Application
| File | Change |
|---|---|
| `UseCases/Adventure.swift` | `age: ChildAge`, `init(for:family:catalog:on:)`; `isBeyondContent` becomes "no world fits this age" (decision 11); `availableBosses` goes |
| `UseCases/GetHomeOverviewUseCase.swift` | `HomeOverview.family: FamilyFacts`; `quests` and `bosses` from `UnlockRules` with the family; `situationalBosses` split from `bosses` |
| `UseCases/GetWeeklyHighlightsUseCase.swift` | The weekly quest by `age(on:)` and the family: never a card for someone else |
| `UseCases/EditProfileUseCases.swift` | `UpdateFamilyUseCase.execute(children:hasPartner:on:)` |
| `UseCases/GetSagaFilmUseCase.swift` | Follows the storyboard's `childAge` |

### Step 3: Data
| File | Change |
|---|---|
| `DTOs/ContentDTOs.swift` | `WorldDTO.beforeBirth`, optional ages; `QuestDTO.onlyFor`, `retired`; `BossFightDTO.onlyFor`, `situational`, `evergreen` (`requiresSibling` goes); `FirstMomentDTO.beforeBirth`, `retired` |
| `Mappers/ContentMappers.swift` | `WorldDTO.toDomain() throws` (the span); audience words parsed like skills |
| `Repositories/BundledContentRepository.swift` | `ContentDataError.unknownAudience(itemID:audience:)`, `.invalidWorldAges(worldID:)`, `.misplacedBeforeBirthWorld(worldID:)`, `.agedBeforeBirth(itemID:)` |
| `Validation/ContentValidator.swift` | One world before birth at most, lowest order; its cards at `minAgeMonths` 0 |
| `Resources/bosses.json` | `b-w3-new-sibling`: `"onlyFor": ["youngerSibling"]` |
| `Persistence/Schema/SchemaV6.swift` (new) | V5 without `ChildRecord.birthDate`, with `ProfileRecord.hasPartner: Bool?` |
| `Persistence/Schema/DadSagaMigrationPlan.swift` | `SchemaV6` in `schemas`; `.custom(fromVersion: SchemaV5.self, toVersion: SchemaV6.self, willMigrate: { try fillBirthDays(in: $0, timeZone: .autoupdatingCurrent) }, didMigrate: nil)`; `CurrentSchema = SchemaV6` |
| `Persistence/ProfileRecord.swift` | Day columns from `birthDay` or empty; empty reads "not born yet"; `hasPartner` nil reads `true` |

### Step 4: Presentation
| File | Change |
|---|---|
| `Shared/FamilyDraft.swift` | `ChildDraft.isBorn`; its `birthDay` stays for the picker (today for a child without one); `child` gives `nil` when not born; `FamilyDraft.hasPartner`; `ChildEditorLabels` gains the new labels |
| `Shared/ChildEditor.swift` | The "Not born yet" `Toggle` under the name; while on, the date, gender and skin rows are hidden and the name reads "Name or nickname"; the header shows the mark |
| `Shared/PartnerRow.swift` (new) | The partner `Toggle` with its line, used by onboarding and "My family" |
| `Onboarding/OnboardingViewModel.swift`, `OnboardingView.swift`, `OnboardingViewState.swift` | The partner row on the children step; the profile carries the answer |
| `Family/FamilyViewModel.swift`, `FamilyView.swift` | The partner row; saving passes it; both switches count as unsaved changes through `FamilyDraft` (ADR-0050) |
| `Shared/Companion.swift` | `CompanionStage.onTheWay`, `init(age:)` |
| `Shared/OnTheWayMark.swift` (new) | The mark, sized like a companion; VoiceOver "<name>, on the way" |
| `Shared/HeroLook+Avatar.swift`, `Home/FamilyStage.swift` | `.onTheWay` draws the mark instead of a `ChildAvatar` |
| `Home/HomeViewState.swift` | `HomeContent.arrivalLine: String?`, `HomeContent.situational: SituationalCards?` (title and cards) |
| `Home/HomeViewModel.swift` | The age line, companions, the arrival line for a child not born yet, situational cards, "coming soon" when no world fits |
| `Home/HomeView.swift`, `Home/HomeComponents.swift` | The arrival line under the world header; a closed `DisclosureGroup` "When life changes" after the cards |
| `Home/HomeStrings.swift` | `ageText(_: ChildAge)`, `ageRange(_: WorldSpan)`, "Opens after the birth" |
| `Home/HomeViewModel+WorldMap.swift` | Spans; "Opens after the birth" for a child not born yet; counts without `childCount` |
| `Home/HomeViewModel+Links.swift` | `UnlockRules.isOffered` instead of the age check |
| `Home/MomentsFormatter.swift`, `Home/MomentChoiceStep.swift`, `Home/HomeViewState.swift` | Options from `UnlockRules.firsts(in:age:)`; each `MomentOption` has its own earliest date (before-birth firsts any day, others from the birth day); "complete" counts what can be offered; a before-birth empty line |
| `SagaFilm/SagaFilmScriptBuilder.swift`, `SagaFilm/Rendering/SagaFilmCardView.swift` | The opening draws the mark for a child not born yet |
| `Localization/Resources/Localizable.xcstrings` | The words below, el and en, `translated`, `extractionState: manual` |

| Where | en | el (draft, for the owner) |
|---|---|---|
| Child editor switch | Not born yet | Δεν έχει γεννηθεί ακόμα |
| Name, while it is on | Name or nickname | Όνομα ή χαϊδευτικό |
| Partner switch | I'm raising them with a partner | Τα μεγαλώνω μαζί με τον άνθρωπό μου |
| Under it | Shows the cards for the two of you. | Δείχνει και τις κάρτες για τους δυο σας. |
| Age line | on the way | έρχεται |
| World 0's ages | before birth | πριν τη γέννα |
| A locked world, before the birth | Opens after the birth | Ανοίγει μετά τη γέννα |
| Arrival line | When they arrive, untick "Not born yet" in My family. | Όταν έρθει, κλείσε το «Δεν έχει γεννηθεί ακόμα» στο «Η οικογένειά μου». |
| Situational row | When life changes | Όταν αλλάζει η ζωή |
| Moments, before the birth | The day you found out, the first picture… Capture them here. | Η μέρα που το έμαθες, η πρώτη εικόνα… Κράτα τες εδώ. |
| VoiceOver, the mark | %@, on the way | %@, έρχεται |

### Step 5: App
- `App/DI/AppContainer.swift`: no new dependency; it compiles as it is or with the use cases' new parameters.

### Step 6: check
- `ui-check`: onboarding with the switch on and off, in Greek and English; "My family": untick, pick a day, save, home in
  World 1; the partner row; home for a child not born yet ("coming soon" until PR 2); iPhone Duo half-open for
  onboarding and "My family"; the accessibility text sizes on the child editor.
- `reviewer` before the PR.

## PR 2, step by step (content agent)
1. Branch from `feature/card-model-v1`.
2. `worlds.json`: World 0 (`w0-harbour`, order 0, `beforeBirth`); the English tagline is still to be written.
3. `quests.json`, `bosses.json`, `firsts.json` from the set, with the owner's edits:
   - G1, as the owner answered it: the doctor first everywhere, and the emergency number directly only for immediate
     danger (not breathing or turning blue or grey, won't wake, a seizure, a swallowed button battery; for the mother
     heavy bleeding, can't breathe, chest pain, fainting), calmly, as a plain instruction. G2: no "wanting not to live";
     no self-harm step in `b-w1-the-wall`.
   - Every "keep with edits" line of decisions.md, and the set's checker notes (Έλεγχος, Τόνος).
   - `b-w3-tiny-brawler` only; the six dropped firsts out (`f-sleepover` retired, the other five never shipped).
   - Moves with `formerIDs`, retired entries, `onlyFor`, `evergreen`, `situational`, `beforeBirth`, as in decisions 6–9
     and the ADR's §6 table; Q1's answer for `q-w1-first-aid`.
   - Orders 1–34 for the firsts; `f-sleepover` keeps its words.
   - Ages the tests reject: `q-w4-underwear-rule` is 36 in the set but its world starts at 42, so 42; the note on
     `b-w4-nightmares` suggesting 36 stays 42 unless the owner moves it.
4. `Tests/DataTests/Fixtures/ShippedContentIDs.json`: append the 80 new ids with skill and XP; never edit a line.
5. `BundledContentRepositoryTests`: counts 5 / 98 / 35 / 34 and the new fields.
6. The owner reads every medical card and guide (the content agent's rule). Flag `b-w4-big-goodbye`: it names death
   plainly, which the owner's "cards never scare" rule must allow for a grief guide, or the wording changes.
7. `ui-check`: World 0 on home for a child not born yet; the map for a child not born yet and for a born one; the
   "When life changes" row; a film of World 0; a quest sheet with a long tip at the largest text size; Greek and English.
8. `reviewer` before the PR.

## Tests
Swift Testing, Given/When/Then, through the code the screen calls.

**Domain**
- Age: a child not born yet is before birth on any day; a born child is before birth on a day before the birth day and
  0 months on it; the Gregorian months as before.
- Worlds: not born → World 0 current and the only one reached, its quests and bosses only; born today → World 1 current,
  World 0 visited and replayable, World 0's quests not in World 1; nothing past content for a child not born.
- Audiences: partner cards gone with no partner and back with one; the second-born sees `meet-the-crew`, the first-born
  doesn't, twins neither; a sibling on the way gives a three-year-old "The New Roommate", an only child doesn't get it.
- Retired: never in any world's quests, the weekly pick or the firsts offered, at any age and family; still counted by
  `Timeline` and `DadProgress` with its XP; counted on the map when done.
- Evergreen bosses: in later worlds, counted on the map in their own world only.
- Firsts: before birth only the two; after it, every first but the retired one.
- Film: World 0's period ends on the birth day; years start at the birth; a whole-saga film puts entries before the
  birth in World 0's chapter; the birth day offers World 0's film when it has an entry, and nothing is offered before the
  birth; a film of a child not born yet is told as before birth.
- Profile: a child not born yet is valid; a born child dated tomorrow is not.

**Application**
- Home for a child not born yet: World 0, its cards, no situational row; with no partner, none of the six cards; the
  situational bosses apart from the others.
- The weekly quest: World 0's for a child not born yet; never a partner card for a dad without one, over a year of weeks.
- "My family": saving the partner answer; unticking and saving a day keeps the child's id and every entry.
- No world fits: "coming soon" for a child not born when the catalog has no world before birth.

**Data**
- Mapping: a world before birth without ages; a world with neither (`invalidWorldAges`); audience words, an unknown one
  (`unknownAudience`); situational, evergreen, retired and before-birth flags.
- Validation: two worlds before birth, or one not first (`misplacedBeforeBirthWorld`); a World 0 card above 0 months
  (`agedBeforeBirth`).
- Shipped ids: the four existing tests, and every retired card is one that shipped.
- Store: `StoreV5` opens read-write at version 6 with both children born on their days (the empty one from its
  `birthDate`), the look, entries, photos and wardrobe, and the partner answer yes; read-only at version 6 it throws and
  leaves the files byte for byte; once migrated, the widget reads it; `StoreV1`, `StoreV3` and `StoreV4` still open; a
  child not born yet saves and reads back without a day, then born on a day.

**Presentation**
- Onboarding: the switch hides the date and look rows and saves a child without a day; the partner switch starts on
  and saves off.
- "My family": unticking shows the picker at today and saving makes the child born; either switch is an unsaved change.
- Home: "<name> · on the way", the mark, the arrival line, World 0's cards, the closed "When life changes" row and its
  cards; the map's texts for a child not born yet and for a born one.
- Moments: the two firsts before birth for a child not born yet, dated before any birth day; a retired first never
  offered but shown if captured; "complete" counts what can be offered.
- Links: a link to a retired card or one for someone else opens no sheet.
- Film: the opening of a film of a child not born yet has the mark; World 0's chapter title.
- Strings in el and en.

## Risks
- **Swift 6 strict concurrency.** The new types are value types and `Sendable`. The migration closures are
  `@Sendable (ModelContext) throws -> Void` in the current SDK: the stage calls a static function with
  `.autoupdatingCurrent` and captures nothing. No new tasks or actors; the view models stay `@MainActor`.
- **SwiftData.** Apple doesn't document what `willMigrate` sees or that dropping a property is lightweight. The plan
  follows what this store already does (V2 → V3 dropped `photoID` after a `willMigrate` copy, ADR-0042 §2) and proves it
  with the `StoreV5` fixture, read-write and read-only. V6 must differ from V5 in shape, or SwiftData rejects the plan
  ("duplicate version checksums"). A throw leaves the store at V5 and the calm screen (ADR-0026). An older build can't
  open V6: anyone going back to an older `develop` build sees "couldn't open".
- **iOS 26.** Nothing new beyond `Toggle` and `DisclosureGroup` (iOS 14). The mark's SF Symbol is checked in the SF
  Symbols app before use.
- **ADR-0006.** No due date, countdown or "overdue"; the birth is the dad's word and World 1 opens by age. The partner
  question is neutral, never asks why, and keeps everything a "no" hides. Situational bosses wait behind a closed row,
  with no count. Retired cards keep their XP and their place. A first before birth carries no weeks and no expectation.
- **Content.** Six cards change who sees them, and `b-w3-new-sibling` narrows; past entries all stay. Death is named in
  `b-w4-big-goodbye` (PR 2, step 6). The set's health wording follows G1 as the owner answered it.
