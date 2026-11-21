# ADR-0051: The v1 card set: a world before birth, who a card is for, and retiring cards that shipped

**Status:** Proposed (2026-11-21). From the owner's review of the card set (2026-11-21, two rounds): every card he kept
ships in v1, World 0 included, and a tick "Not born yet" where the child's name is entered is how the app knows a
child is in World 0. Drafted by the architect; four points wait for the owner (see the plan,
`docs/plans/v1-card-set.md`). Changes ADR-0005 (new content fields), ADR-0012 (a child may not be born yet),
ADR-0013 (a mark for a child on the way), ADR-0019 (a world before birth; what a locked world says before the birth),
ADR-0020 §2–§3 (evergreen bosses; `onlyFor` replaces `requiresSibling`; the map counts every boss beaten), ADR-0026
(schema version 6), ADR-0028 (`Adventure` takes the family's facts, not a child count), ADR-0030 ("My family" asks
about a partner and whether a child is born), ADR-0036 §1 and §7 (the world before birth in the film, and its offer at
the birth) and ADR-0048 §2, §3 and §5 (an age before birth; `birthDate` dropped; retiring a card).

## Context
- **The set.** 190 cards were reviewed. The owner dropped 20 in the first round and 7 in the second
  (`b-w2-tiny-brawler` and six firsts); all the rest ship in v1, including the ones marked "later". The result: 5
  worlds, 95 quests, 35 bosses and 33 firsts that can be offered.
- **World 0**, "Το Λιμάνι της Αναμονής / The Harbour of Waiting" (`w0-harbour`): 15 quests, 2 bosses
  (`b-w0-birth-day`, `b-w0-caesarean`) and 2 firsts before birth (`f-found-out`, `f-first-picture`). An earlier design
  named it `w0-base-camp` with ages 0/0 (expert notes A1/A2); neither id has been in `develop`.
- **A child is a birth day** (ADR-0048 §2): `Child.birthDay: CalendarDay`, every age counted from it by one Gregorian
  rule, and `birthDay <= today`. Before a birth there is nothing to count from.
- **Conditions in the set:** `onlyFor: ["partner"]` on four quests; `onlyFor: ["twoHomes"]` on two cards, both dropped;
  `requiresBirthPartner` on `b-w1-fourth-trimester`; `requiresSibling` on a quest (`q-w1-meet-the-crew`, "only if there
  is an older child"); `situational: true` on `b-w4-two-homes`, `b-w4-big-goodbye` and `b-w4-big-move`; `evergreen` on
  two bosses (`b-w1-double-shift`, `b-w2-long-grind`). Expert notes: no `requiresPregnancy`, the texts say "if she
  wants you there" (A14); `q-w0-the-talk` needs a partner (A15); firsts before birth get `beforeBirth: true`, not a
  negative `order` (A8).
- **Today one family fact decides a card:** `requiresSibling` on `b-w3-new-sibling`, true when the family has more than
  one child (ADR-0020 §3), passed around as `childCount`.
- **Shipped content** (ADR-0048 §5): an id that has been in `develop` stays, as an id or a former id; a shipped quest,
  boss or first keeps its skill and earns no less XP; "retiring a card without a successor of the same kind needs its
  own decision when the first such card comes". The set retires five shipped cards that have no successor of the same
  kind: `q-w1-tummy-time`, `q-w2-rough-play`, `q-w3-ten-breaths` (its steps go into the new boss `b-w3-red-mist`),
  `f-sleepover`, and `q-w1-first-aid` (dropped as too frightening; the set keeps `q-w0-first-aid`, the same action with
  the same skill and XP). Six cards move or are renamed within their kind. Checked against the set's meta lines, none
  loses XP or changes skill (§6).
- **The film:** firsts are never dropped; they shorten to 3 seconds each when a film is over 90 (ADR-0036 §2). The five
  tracks last at least 95 seconds (ADR-0046 §1); a longer film loops its track (`FilmKit.MusicBed`). With 33 firsts, the
  retired `f-sleepover`, a chapter card per world, the opening and the credits, a whole-saga film can reach about 124
  seconds. The set notes "about 27 firsts" as the music's limit.
- **What Apple documents (checked 2026-11-21):** `MigrationStage.custom(fromVersion:toVersion:willMigrate:didMigrate:)`
  has only its declaration; its closures are `@Sendable (ModelContext) throws -> Void`. WWDC23 "Model your schema with
  SwiftData" fetches the old version's models in `willMigrate`, before the store changes. No page says that removing a
  property is a lightweight change; this store already removed `photoID` that way (V2 → V3, ADR-0042 §2), with
  fixture tests. `DisclosureGroup` is iOS 14+.
- ADR-0006: XP for the dad's actions, nothing lost, worlds by age only, no deadlines. The owner's rule for cards: calm
  wording, red flags as plain instructions.

## Decision

### 1. A child not born yet
- **Domain:** `Child.birthDay: CalendarDay?`, `nil` while the child is not born yet; `Child.isBorn`. No other date is
  kept: no due date.
- **Why no due date.** Nothing needs one: World 0's cards have no ages, and the birth, not a date, opens World 1. A due
  date is an estimate; it would bring a countdown or an "overdue" onto the screen (ADR-0006; the owner dropped
  `b-w0-long-wait`), and a baby who comes early or late would make it wrong either way. The dad says when the child is
  born.
- **One age rule, with a "before":** `Child.age(on: CalendarDay) -> ChildAge`, either `.beforeBirth` or `.months(n)`.
  It is `.beforeBirth` when there is no birth day or the day is before it; otherwise the completed Gregorian months of
  ADR-0048 §2. It replaces `ageInMonths(on:)`. `day(atMonths:)` is `nil` before the birth. An entry dated before the
  birth day is "before birth", so it belongs to World 0, not to World 1 at age 0.
- **Entering (the owner's design):** the child editor, in onboarding and in "My family", has a switch "Not born yet"
  under the name.
  - On: the name stays and is still required ("Name or nickname"); date of birth, gender and skin tone are hidden and
    not asked. Gender and skin tone keep their defaults until he sets them.
  - Off: those rows come back, the date picker at today and no later.
- **Unticking it and saving a day** makes the child born on that day. It is the same child, with the same id, so
  everything recorded before the birth stays theirs: XP, the timeline, the film. World 1 opens by age from that day and
  World 0 becomes a visited world on the map. An earlier day is fine: he may tell the app days after the birth.
- **Ticking it for a born child** is allowed, to undo a mistake; saving forgets the birth day; nothing recorded is lost.
  "My family" asks before leaving with either change unsaved, as it does for any change (ADR-0050).
- `ProfileRules` checks `birthDay <= today` only for a born child. A child not born yet counts towards one to four
  children.
- **Home in World 0** shows one quiet line under the world: "When they arrive, untick "Not born yet" in My family." No
  card, no count, no date.

### 2. World 0, the Harbour of Waiting
- **Id `w0-harbour`**, the reviewed set's; `w0-base-camp` never shipped. `order` 0.
- **`World.span: WorldSpan`**, `.beforeBirth` or `.months(min: Int, max: Int?)`, replaces `minAgeMonths` and
  `maxAgeMonths`. In the JSON: `"beforeBirth": true` and no ages.
- **Rules (`UnlockRules`):** a world before birth is reached at every age. It is the current world while the child is
  not born, and a visited world afterwards. A world of months is reached by a born child of its minimum age. The current
  world is the last reached, by order. So a child not born yet has World 0 only; a born child has World 0 behind them
  and the months worlds as today.
- **Its cards** have `minAgeMonths` 0 (checked at load). They are reached before birth, and after it at age 0, so a dad
  can open World 0 from the map like any earlier world (ADR-0019).
- **When no world fits** a child, older than every world or not born in content without a world before birth, home and
  the weekly quest say "Adventures for your child's age are coming soon.", as they do today for a child over six.
- **World map:** World 0's age line reads "before birth". For a child not born yet every other world reads "Opens after
  the birth": there are no months to count.
- **Its two bosses stay in it.** On the birth day the arrival line sits above them; after the birth they are on the map
  like any earlier world's bosses.
- **Film:**
  - World 0 is a period: everything before the birth day, or everything so far while the child is not born.
  - A film spanning worlds gives entries before the birth World 0's chapter card.
  - The world ends on the birth day: home offers World 0's film from that day for 30 days, when the dad has an entry in
    it, as for any world (ADR-0036 §7).
  - No year starts before birth: year 1 starts on the birth day, as now.
  - A film of a child not born yet opens with the hero and the child's mark.
- **The child on screen:** `CompanionStage.onTheWay`, drawn as a small mark beside the hero, on home, in the child
  editor and on the film's opening card, read by VoiceOver as "<name>, on the way". The mark is an SF Symbol, chosen and
  checked in the SF Symbols app (iOS 26 is the package's minimum). The code-drawn children (`HeroArt`) don't change, so
  the launch image and the website's images stay.
- The age line on home and the map: "<name> · on the way".

### 3. Firsts before birth
- `"beforeBirth": true` on `f-found-out` and `f-first-picture` (`FirstMoment.isBeforeBirth`), instead of a negative
  `order` (A8). The orders are renumbered 1 to 34; `order` sorts the list and is never stored.
- **Offered** (`UnlockRules.firsts(in:age:)`): before the birth, only firsts before birth; after it, every first; never
  a retired one.
- **Dates:** a first before birth can be dated any day up to today; every other first from the birth day, as now.
- Nothing about a first before birth is expected or compared (ADR-0006 rule 4): no weeks of pregnancy anywhere.

### 4. Who a card is for
- **One field, `onlyFor`,** on quests and bosses: a list of `partner`, `olderSibling`, `youngerSibling`
  (`Audience` in Domain). Every one listed must hold. An unknown word fails the load (`ContentDataError.unknownAudience`).
  It replaces `requiresSibling`.
- **The facts** are about the family, never the child's development (ADR-0006 rule 3), in one value,
  `FamilyFacts(profile:child:)`:
  - `hasPartner`: what the dad answered;
  - `hasOlderSibling`: another child born before this one; for a child not born yet, any born child; twins have none;
  - `hasYoungerSibling`: another child born after this one, or one not born yet while this one is.
- **The cards:**
  - `partner`: `q-w1-invisible-jobs`, `q-w1-check-in`, `q-w1-close-again`, `q-w1-date-night`, `q-w0-the-talk` (A15)
    and `b-w1-fourth-trimester`. The set's `requiresBirthPartner` becomes `partner`: v1 asks no one who gave birth.
  - `olderSibling`: `q-w1-meet-the-crew`.
  - `youngerSibling`: `b-w3-new-sibling` ("The New Roommate"), which was "more than one child". A child with only an
    older sibling no longer meets it; one whose sibling is on the way meets it before the birth.
  - Not added: `twoHomes` (both its cards were dropped) and `requiresPregnancy` (A14).
- **The partner answer:** `PlayerProfile.hasPartner: Bool`. Onboarding asks once, with the children: a switch "I'm
  raising them with a partner", on, with one line under it, "Shows the cards for the two of you." "My family" has the
  same row. Nothing asks why, and no other word is used for the answer. A profile without an answer, which is every
  profile today, reads yes: no one loses a card he sees now.
- **A card for someone else is never offered:** not on home, not as the weekly quest, not on the widget or in the
  notification, and a link to it opens no sheet. What the dad did with it still counts: `Timeline` doesn't read
  audiences.
- **`childCount` goes** from `Adventure`, `UnlockRules` and `DadProgress.progress(in:)`. The map counts every boss
  beaten in a world, whoever it is for now: ADR-0020 §4 already took the totals away, so a hidden boss changes nothing
  but what was kept.

### 5. Bosses for when life changes, and bosses at every age
- **`"situational": true`** (`b-w4-two-homes`, `b-w4-big-goodbye`, `b-w4-big-move`): offered by age and audience like
  any boss, but home lists them in one closed row at the end of the world's cards, "When life changes", that opens to
  show them. It is closed each time home loads and shows no count. They are there for the dad who needs them, and not
  on every dad's screen.
- **`"evergreen": true` on a boss** (`b-w1-double-shift`, `b-w2-long-grind`): shown in every later world, like an
  evergreen quest (ADR-0020 §2), and counted on the map only in its own world. Once beaten it shows "Defeated" wherever
  it appears.

### 6. Retiring a card that shipped
- **`"retired": true`** on a quest or a first. A retired card stays in the content with its id, world, title,
  description, skill and XP; its tip may go. `Timeline`, XP, gear, the timeline, the journal and the film find it, so
  what the dad did keeps its words and its XP. It is never offered: not on home in any world, not as the weekly quest,
  not in the moments picker, and a link to it opens no sheet. The map counts a retired quest the dad did.
- **Only a shipped card can be retired** (a test): an unshipped card is simply deleted.
- **A move or a rename within a kind** uses `formerIDs` (ADR-0048 §5), and the new id names its new world. A card
  folded into another kind is retired: a quest counts each time, a boss once.
- **Bosses** get `retired` when the first one is retired; none is now.

| Shipped | Now | Kind | Skill · XP, before → now | How |
|---|---|---|---|---|
| `q-w2-car-seat` | `q-w1-car-seat` | quest | care 25 → care 25 | `formerIDs` |
| `q-w2-toothbrush` | `q-w1-toothbrush` | quest | care 20 → care 20 | `formerIDs` |
| `q-w2-date-night` | `q-w1-date-night` | quest | resilience 35 → resilience 35 | `formerIDs`; `partner` |
| `q-w4-swim` | `q-w2-swim` | quest | play 30 → play 30 | `formerIDs` |
| `q-w4-check-in` | `q-w1-check-in` | quest | resilience 30 → resilience 30 | `formerIDs`; `partner` |
| `f-christmas` | `f-celebration` | first | 30 → 30 | `formerIDs`; "First big celebration" |
| `q-w1-first-aid` | `q-w0-first-aid` (owner to confirm) | quest | care 35 → care 35 | `formerIDs` |
| `q-w3-ten-breaths` | retired; its steps in `b-w3-red-mist` | quest | patience 30, kept | `retired` |
| `q-w1-tummy-time` | retired | quest | play 20, kept | `retired` |
| `q-w2-rough-play` | retired | quest | play 25, kept | `retired` |
| `f-sleepover` | retired | first | 30, kept | `retired` |

Every other shipped quest, boss and first keeps its id, skill and XP in the set.

### 7. The content's shape
```json
{ "id": "w0-harbour", "order": 0, "beforeBirth": true, "title": { "el": "…", "en": "…" }, "tagline": { "el": "…", "en": "…" } }
{ "id": "q-w1-date-night", "formerIDs": ["q-w2-date-night"], "worldID": "w1-swamp", "skill": "resilience", "xp": 35,
  "minAgeMonths": 4, "evergreen": true, "onlyFor": ["partner"], "title": …, "description": …, "tip": … }
{ "id": "q-w1-tummy-time", "worldID": "w1-swamp", "skill": "play", "xp": 20, "minAgeMonths": 0, "retired": true,
  "title": …, "description": … }
{ "id": "b-w4-two-homes", "worldID": "w4-why-kingdom", …, "situational": true }
{ "id": "b-w3-new-sibling", …, "onlyFor": ["youngerSibling"] }
{ "id": "f-found-out", "order": 1, "beforeBirth": true, … }
{ "id": "f-sleepover", "order": 34, "retired": true, … }
```
- **Checked at load:** a world is either before birth with no ages or has `minAgeMonths`
  (`ContentDataError.invalidWorldAges`); at most one world is before birth and it has the lowest order; every card in it
  has `minAgeMonths` 0; every `onlyFor` word is known. Ids and former ids stay unique (ADR-0048 §5).
- **`ShippedContentIDs.json`** gains the new world and every new card in the PR that adds them (1 world, 49 quests, 19
  bosses, 11 firsts), and a test that every retired card is one that shipped.

### 8. Stored: schema version 6
- **`SchemaV6`** (6.0.0) is version 5 with two changes. `ChildRecord` loses `birthDate`, as ADR-0048 §3 said the next
  version that changes the child would; `birthYear`, `birthMonth` and `birthDay` stay optional, and all three empty mean
  "not born yet". `ProfileRecord` gains `hasPartner: Bool?`; empty reads yes. Optional, as in ADR-0044 §6.
- **V5 → V6** is `.custom` with a `willMigrate` only. On version 5, each child without a day gets the day its
  `birthDate` falls on in the device's time zone (`fillBirthDays`, the V4 → V5 function, which can run twice); then the
  stage drops the column. The same shape as V2 → V3. A throw fails the migration: the store stays at version 5 with its
  `birthDate`, and the next launch tries again (ADR-0026). So a born child can't come out as not born.
- **No stored "not born" flag:** the empty day says it, and two fields could disagree.
- **Tests:** a new fixture, `Tests/DataTests/Fixtures/StoreV5`, written by the version 5 build before the schema changes
  and never regenerated: a dad with a look, one child with a day and one whose day columns are empty (written through
  `SchemaV5` directly), entries with photos and a note, and a wardrobe choice. The app opens a copy read-write and finds
  everything, both children born on their days and the partner answer yes; the widget opens a copy read-only at
  version 6, throws, and leaves the files byte for byte as they were; the earlier fixtures still open. A child not born
  yet is saved and read back without a day, and born again on a day.
- An older build can't open a version 6 store: the calm "couldn't open" screen (ADR-0026).

### 9. More firsts than the music: the owner decides
- At the 3-second floor, 33 firsts and the retired one, five chapter cards, the opening and the credits make about 124
  seconds; the shortest track is 95 and loops. Only a whole-saga film of a dad who captured more than about 25 firsts
  reaches the loop.
- **Recommended:** every track at least as long as the longest film the content allows (130 seconds or more), and a test
  that works that length out from the catalog and `SagaPacing` and fails when the content outgrows the music. Firsts are
  still never dropped. That changes ADR-0046 §1's 95 seconds; the index notes it once the owner chooses.
- Otherwise: keep the loop as it is, or cap the firsts in a film, which ADR-0036 §2 rules out.

### 10. Where the code goes

| Layer | Adds | Changes or removes |
|---|---|---|
| Domain | `ChildAge`, `WorldSpan`, `Audience`, `FamilyFacts`; `UnlockRules.bosses(for:…)`, `firsts(in:age:)`, `isOffered(_:age:family:)` | `Child.birthDay` optional, `age(on:)` replaces `ageInMonths(on:)`, `day(atMonths:)` optional; `World.span` replaces the two ages; `Quest` and `BossFight` gain `onlyFor`, `Quest` and `FirstMoment` `isRetired`, `BossFight` `isSituational` and `isEvergreen`, `FirstMoment` `isBeforeBirth`; `requiresSibling`, `isPossible` and every `childCount` go; `PlayerProfile.hasPartner`; `ProfileRules`, `SagaPeriod`, `SagaOccasions`, `SagaStoryboard` (`childAge` replaces `childAgeInMonths`), `DadProgress.progress(in:)` |
| Application | `HomeOverview.situationalBosses`, `HomeOverview.family` | `Adventure` takes `FamilyFacts` and has `age`; `availableBosses` goes (home asks `UnlockRules.bosses(for:)`); the weekly quest reads the family; `UpdateFamilyUseCase.execute(children:hasPartner:on:)` |
| Data | `SchemaV6` and its stage; the `StoreV5` fixture; `ContentDataError.unknownAudience`, `.invalidWorldAges`, `.misplacedBeforeBirthWorld`, `.agedBeforeBirth` | DTOs and mappers for the new fields, `requiresSibling` gone; `ContentValidator`; `ChildRecord` and `ProfileRecord` mappings; `CurrentSchema`; the content JSON; `ShippedContentIDs.json` |
| Presentation | `CompanionStage.onTheWay` and its mark; the "Not born yet" switch and the partner row; home's arrival line and "When life changes" row | `ChildDraft`, `FamilyDraft`, `ChildEditorCard`, onboarding, "My family", home, the map, moments, links, the film's opening card; strings in el and en |
| App | | nothing new to wire: the use cases keep their dependencies |

## Rejected
- **A due date**, shown or only stored: a countdown or an "overdue" waiting to happen, wrong for every early or late
  baby, and nothing reads it (§1).
- **Ages before birth as negative months** (World 0 as −9 to −1, firsts with a negative `order`): every age rule would
  have to know that a negative month is a guess.
- **Opening World 1 on a date:** only the dad knows the baby is here.
- **`availableBeforeBirth` on World 1 cards** (A5, A6): the owner kept the separate World 0 cards (car seat, sleep
  space, first aid).
- **World 0's bosses as tips** (A4): the owner kept them as bosses.
- **Asking who gave birth** for `b-w1-fourth-trimester`: a second personal question for one card.
- **A "hide this card" control:** a dad would first have to see the card that hurts.
- **Deleting dropped cards that shipped:** their events would lose their XP and their place in the timeline and the
  film (ADR-0048 §5).
- **Folding `q-w1-tummy-time` or `q-w2-rough-play` into a similar quest:** the dad's entries would show another card's
  title.
- **Situational bosses as ordinary bosses:** "Two Homes" and "The Big Goodbye" on every dad's screen. **Behind a
  setting:** a dad who needs one wouldn't find it.

## Deferred
- A per-child "who gave birth" fact; corrected age for children born early and a path for a stay in neonatal care (A5;
  ADR-0048 deferred corrected age).
- Retiring bosses, heroes, gear or worlds: when the first one is retired.
- The film's music length (§9), until the owner chooses.

## Consequences
- A dad can start before the birth: World 0, its two firsts, and a film of the waiting, offered on the birth day. The
  birth is the one thing he tells the app; nothing counts down to it.
- Every age still comes from one function, now with a "before"; World 1 opens on the birth day he enters, as every
  later world opens by age.
- One more personal answer (a partner), kept on the device (ADR-0004) and erased by "start over" (ADR-0030 §8). A dad
  who answers no stops seeing six cards; everything he did with them stays.
- `b-w3-new-sibling` now needs a younger sibling, born or on the way: a youngest child stops seeing it.
- Five shipped cards are retired and six renamed; their ids stay for good, and the content carries the retired cards'
  words so past entries keep them. Past entries of `f-christmas` now read "First big celebration".
- One stored version more, and a fixture of three small binary files.
- World 0's bosses are a tap further away once the child is born: the map, then World 0.
- Until the owner decides §9, a long whole-saga film loops its music.
