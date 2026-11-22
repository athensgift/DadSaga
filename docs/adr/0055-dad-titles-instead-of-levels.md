# ADR-0055: Dad titles instead of levels: earned by cards done and XP, never lowered, bringing the hero's gear

**Status:** Accepted (2026-11-22): the owner's decisions of 2026-11-22 are final. Of the choices made while he was
away, he confirmed 2 to 11 and reversed 1: an Undo goes back to before the card, title included (§3); choice 5 is moot,
since nothing is released yet. Numbered
0055 because another branch takes 0054. Changes ADR-0005 (a new kind of content, `titles.json`), ADR-0012 (the dad has
XP and a title, no level), ADR-0014 (gear comes with titles; a skill names a slot and unlocks nothing), ADR-0018 (the
wardrobe shows only what the hero has, without XP), ADR-0021 §2 (deleting an entry no longer lowers the title or takes
gear), ADR-0023 (the widget's quest shows its skill, no XP), ADR-0024 (the reminder card also waits while a title card
shows), ADR-0026 (schema version 7), ADR-0037 (the title in the credits; the film card waits while a title card shows),
ADR-0043 (the hero's pane shows the title where the level card was) and ADR-0048 §5 (titles join the shipped ids; gear
is guarded by its title).

## Context
- **Today:** `LevelCurve` turns total XP into a numbered level (100, 300, 600 … XP). Home shows "Level 3" with an XP bar
  and "40 / 200 XP" (`LevelPanel`, `XPBar`). Every card, sheet, timeline row, moment and the widget show "+20 XP". The
  celebration shows "+20 XP", "Level 3!" and "New: <item>". Each of the eight gear items is earned by one skill's XP: 50
  for the first item and 200 for the second (`GearRules.earned(_:skillXP:)`, ADR-0014). The wardrobe shows each skill's
  XP and every locked item with "120 / 200 XP" (ADR-0018).
- **Everything follows from the events** (ADR-0021 §2): deleting an entry, by undo or from the timeline, takes back its
  XP, so a level can drop and gear can lock again. Nothing else is stored.
- **The owner's decisions (2026-11-22, final):**
  - XP stays inside the app and is never shown.
  - A title needs both a number of cards done and total XP. Cards done means every counted timeline entry: a quest
    every time, a boss or a first once per child. With both, one early 100-XP boss can't skip titles.
  - Ten titles, each bringing one gear item, except the first and the last (§2).
  - Titles, their thresholds and what they bring are content, not Swift.
  - A title never goes down.
  - Gear comes with the title, not with a skill. Each item keeps its slot on the hero. Gear a dad already has stays.
  - Shipped ids stay.
  - The four skills stay as flavour only ("your patience grew") and unlock nothing.
  - A calm card on home when the title changes ("Έγινες … Πήρες …"), closed with one tap: no confetti, no sound.
  - The title is in the saga film's credits, in the film's language.
  - Nothing anywhere hints at the next title: no bar, no "X to go".
  - The old level path goes.
- **Only a deletion lowers what the events give.** Removing a child keeps its entries (ADR-0012). A shipped card never
  loses XP or goes (ADR-0048 §5), and a retired one still counts (ADR-0053 §6). Editing an entry changes its note,
  photos or a first's date, never what it counts. Starting over erases everything, on purpose (ADR-0030).
- **No release is installed yet.** Stores from before titles exist on the owner's phone and on devices running
  `develop`, which is where content ships (ADR-0048 §5).
- **The other branch** changes `quests.json`, `bosses.json`, `firsts.json` and `worlds.json`. This decision changes none
  of them.
- **What Apple documents (checked 2026-11-22):**
  - `MigrationStage.lightweight(fromVersion:toVersion:)` has only its declaration. No page says what a lightweight stage
    can change. This store added four optional `String` columns that way (V3 → V4, ADR-0044 §6) and an array column
    with a default (V1 → V2, ADR-0042), with fixture tests. It has never stored an optional array.
  - `AccessibilityNotification.Announcement(_:)` and its `post()` are iOS 17+.
  - `ListFormatStyle` (`formatted(.list(type: .and))`) is iOS 15+ and follows its locale.
  - Nothing here needs an API newer than iOS 26.
- ADR-0006: XP for the dad's actions, nothing ever lost, worlds by age only, no deadlines.

## Decision

### 1. A title, from cards done and XP
- **`DadTitle`** (Domain, content): `id`, `formerIDs`, `order`, `minCards`, `minXP`, `gearIDs` and `name`
  (`LocalizedText`).
- **`TitleRules.reached(cardsDone:xp:in:)`**: the highest title, by order, whose `minCards` and `minXP` are both
  reached.
- **`DadProgress.cardsDone`** counts the entries `Timeline` counts. So the timeline, XP and the title never disagree.
  `DadProgress.level` goes.
- The skills stay in the content and in `DadProgress.skillXP`. They unlock nothing. They give the celebration its line
  and the old gear rule its input (§4).

### 2. The titles are content: `titles.json`
| order | id | el / en | min cards | min XP | brings |
|---|---|---|---|---|---|
| 0 | `t-dad-in-waiting` | Μπαμπάς σε αναμονή / Dad in waiting | 0 | 0 | |
| 1 | `t-new-to-the-journey` | Νέος στο ταξίδι / New to the journey | 1 | 20 | `g-mug` |
| 2 | `t-apprentice-dad` | Μαθητευόμενος μπαμπάς / Apprentice dad | 2 | 60 | `g-burp-cloth` |
| 3 | `t-dad-with-tricks` | Μπαμπάς με κόλπα / Dad with a few tricks | 4 | 140 | `g-duck` |
| 4 | `t-steady-hands` | Σίγουρα χέρια / Steady hands | 7 | 260 | `g-diaper-bag` |
| 5 | `t-family-rock` | Βράχος της οικογένειας / Family rock | 11 | 420 | `g-blocks` |
| 6 | `t-dad-of-all-trades` | Μπαμπάς για όλα / Dad of all trades | 16 | 620 | `g-thermos` |
| 7 | `t-keeper-of-the-house` | Φύλακας του σπιτιού / Keeper of the house | 22 | 860 | `g-mega-bag` |
| 8 | `t-super-dad` | Σούπερ μπαμπάς / Super dad | 29 | 1140 | `g-burp-cloth-gold` |
| 9 | `t-legendary-dad` | Μπαμπάς-θρύλος / Legendary dad | 37 | 1460 | |

```json
{ "id": "t-steady-hands", "order": 4, "minCards": 7, "minXP": 260, "gear": ["g-diaper-bag"],
  "name": { "el": "Σίγουρα χέρια", "en": "Steady hands" } }
```
- **Checked at load** (`ContentValidator`):
  - The first title needs 0 cards and 0 XP.
  - Each later title needs more cards and more XP than the one before (`ContentDataError.invalidTitleThresholds`).
  - Every id a title lists is a gear item (`.unknownGear`).
  - Every gear item is brought by exactly one title (`.gearWithoutTitle`, `.gearInTwoTitles`).
  - Ids and former ids stay unique (ADR-0048 §5), and names are not empty.
- **Each slot keeps its order.** The first item in a slot comes with an earlier title than the second: mug (1) before
  thermos (6), burp cloth (2) before the gold one (8), duck (3) before blocks (5), changing bag (4) before the bag for
  every emergency (7). "The best" item in a slot is the one the highest title brings.

### 3. A title never goes down: what the store keeps
- **Only a deletion lowers what the events give** (Context). So before any change to the dad's entries (recording one
  or deleting one), the app writes what he holds. The title he has is then never lowered by a deletion.
- **`KeptStanding`** (Domain), stored on the profile row:
  - `titleID`: the highest title he held when his entries last changed;
  - `gearIDs`: the gear the old rule had earned him, frozen (§4);
  - `seenTitleID`: the title whose card he closed last (§6).
- **His title** is the higher of the title his entries reach and the kept one (`DadStanding`). A kept id the content
  doesn't know, even as a former id, is ignored.
- **One writer, before the change** (`StandingKeeper` in Application, used by `ProgressRecorder` and
  `DeleteEventUseCase`; an Undo is the one exception, below):
  - It reads the entries and the kept record.
  - It writes only when the title is higher than the kept one, or the old gear isn't frozen yet. That is at most once
    per title, plus once ever.
  - Then the change happens. If the write fails, nothing is recorded or deleted, and the screen says it couldn't save,
    as it does now. If the change fails after the write, the kept record holds only what he already had.
- **Undo goes back to before the card** (the owner's decision). Undo, right after recording, is the dad taking back a
  tap, not deleting his log: the title, and so its level, its card and the gear it brought go with the card.
  - Recording returns what the store kept just before the entry (`ProgressChange.keptBefore`): the record
    `StandingKeeper` wrote, or found, before storing it.
  - `UndoRecordUseCase` puts that record's title and gear back (`StandingRepository.restore`), then deletes the entry.
    It never keeps the card it takes back. If the delete fails, the record is put back as it was before the Undo.
  - **The closed card** (`seenTitleID`) stays as it is now, unless it is above the title he holds once the entry is
    gone. Only then it goes back, to the higher of that title and the card closed before the entry
    (`KeptStanding.undone(to:after:catalog:)`). So a card closed for a title he still holds (brought by an earlier
    card) stays closed, and the card of a title the Undo takes back comes again when a later card reaches it. Home
    forgets the cards closed in the session by the same rule, and closing a card takes its turn with the saves, so its
    write can't land in the middle of an Undo.
  - Two quick cards, then Undo: only the last goes, and the record before it already holds what the first brought.
  - The old gear frozen at the first change (§4) stays frozen: it is what the entries before the card gave.
  - Undo is offered for the last entry on home, for a few seconds, and for a new moment in its sheet. Both can be live
    at once and either can go first: the record each puts back is absolute, so when one is undone, an entry recorded
    after it is given the record from before the undone one. An offer that leaves the screen (its time is up, a newer
    one replaces it, its sheet closes) can't be used later.
- **A deletion from the timeline keeps the title** and its gear, as above: that is the rule that a title never goes
  down.
- **Two screens never write at once:** home's recording waits for its last save (`isCompleting`), and the timeline is
  another tab. A stale write could only lower the kept title, never the one shown, which is the higher of the two.
  A timeline deletion during an Undo's few seconds keeps the card about to be undone; the Undo then puts back the
  record from before that card, which still holds everything the deleted entry had given.
- **Why stored, and why in the store:**
  - Derived alone, any delete lowers the title.
  - In the app's defaults, a start over cut short between the store and the defaults would give a new saga an old
    title.
  - On the profile row, start over erases it in the same write (ADR-0030), and export takes it with the saga.
  - Each field only ever grows, except when an Undo puts back the record from before its card: the title by order, the
    gear as a union, and the seen title by order. Sync merges them with the sync ADR, which must carry an Undo too.

### 4. Gear comes with titles; gear the old rule earned stays
- **An item is earned when the dad holds the title that brings it, or a later one.** `GearItem.minXP` goes, and
  `GearItem.skill` stays: it names the item's slot on the hero (ADR-0014) and the wardrobe's section, and is flavour.
  `Outfit` stays per skill, and so do the stored wardrobe rows.
- **The old rule, only for gear already earned:**
  - Each of the eight shipped items keeps the skill XP that earned it before titles as `skillXPBeforeTitles` (50 or
    200, as it shipped).
  - `GearRules.earnedBeforeTitles(_:skillXP:)` applies the old rule to the dad's entries. It is kept in content, not
    in Swift.
  - An item added after titles has no such field.
- **Frozen once, at the first change** (§3):
  - A profile row from version 6 has `keptGearIDs` empty (nil) after the migration.
  - Until the dad records or deletes something, his entries are exactly the ones from before titles, so the old rule
    reads them as they are.
  - The keeper's first write freezes what the rule gives and stores it. From then on, those ids are his whatever
    happens to his entries, and skill XP earns nothing more.
  - A profile created by version 7 starts with an empty list: nothing to keep, so a new dad gets gear by title only.
- **The hero's gear** is what his title brings and what he kept, `DadStanding.gear`. `GearRules.equipped(_:outfit:)`
  applies the wardrobe. A chosen item that isn't earned falls back to automatic, as before (ADR-0018).
- **Not frozen inside the migration:** the old rule needs the content and `Timeline`'s counting. A migration closure
  would have to load and validate the content, and what a throw in a closure leaves behind is not documented
  (ADR-0048).

### 5. Stored: schema version 7
- **`SchemaV7`** (7.0.0) is version 6 with three optional columns on `ProfileRecord`: `heldTitleID: String?`,
  `seenTitleID: String?` and `keptGearIDs: [String]?`.
  - Optional, as in ADR-0044 §6.
  - Rows from version 6 read nil.
  - A row created since then gets `keptGearIDs = []` (`ProfileRecord(profile:)`).
  - `update(from:)` never touches the three columns, so editing the family or the hero can't lower them.
- **V6 → V7 is `.lightweight`.** No closure runs, so nothing is computed while migrating.
- **`SwiftDataStandingRepository`** (`@ModelActor`, through `ConnectedStandingRepository`'s `@concurrent` methods,
  ADR-0034) reads and writes them through `saveAllOrNothing` (ADR-0048 §1).
  - Without a profile, it reads an empty record with nothing to keep, and writes nothing.
  - The eraser already deletes the profile row, so start over needs no change.
- **Tests:**
  - **The fixture.** `Tests/DataTests/Fixtures/StoreV6` is written by the version 6 build before the schema changes,
    and never regenerated. It holds:
    - a dad with a look and a partner answer;
    - a child who is born and one not born yet;
    - one boss worth 100 care XP, with photos and a note: title 1 by cards, while the old rule had earned the burp
      cloth;
    - the wardrobe wearing `g-burp-cloth`.
  - **The app** opens a copy read-write and finds everything:
    - the hero still wears the burp cloth, although the title is lower than the one that brings it;
    - the title card shows once;
    - after one more quest, the burp cloth is in `keptGearIDs` for good.
  - **The widget** opens a copy read-only at version 7, throws, and leaves the files byte for byte as they were
    (ADR-0053 §8).
  - The earlier fixtures still open.
  - An optional array is new to this store; the fixture test is what shows it works.
- An older build can't open a version 7 store: the calm "couldn't open" screen (ADR-0026).
- **Privacy:** the privacy pages, `web/privacy` and `web/el/privacy`, say the app keeps the title reached, so it stays
  when an entry is deleted (ADR-0051). The manifests don't change: nothing leaves the device and no new API is used.

### 6. Home: the title under the hero, a calm card when it changes
- **The hero's panel** shows the title's name where `LevelPanel` was, in the dad's language. There is no bar, no number
  and no next title. Above the fold it stays in the hero's pane (ADR-0043).
- **The title card:**
  - `DadStanding.news` is set when his title is above the last one he closed. For a store without one, that last
    title counts as the first title.
  - Home's query returns it. The card says:
    - «Έγινες «Σίγουρα χέρια».» / "You became “Steady hands”.";
    - «Πήρες: Τσάντα αλλαξιέρα.» / "You got: Changing bag." This lists what the titles since the last card brought
      and the hero didn't already have, as a locale list (`ListFormatStyle`). There is no line when there's nothing
      new.
  - One button, «Ωραία» / "Nice", closes it. That writes `seenTitleID` (`MarkTitleSeenUseCase`), and the card goes at
    once and stays gone through a reload (as the film offer does).
  - No confetti, no sound and no haptic. VoiceOver hears it once when it first appears.
  - It stays until he closes it, across launches.
  - A jump of two titles at once makes one card, for the higher title, listing both items.
- **One card at a time:** the title card first, then a film offer, then the reminder offer. They sit in the same place
  at the top of the cards (`offerCard`). A first quest that brings title 1 no longer shows the reminder offer beside
  it.
- **The celebration stays, smaller.** It no longer says XP, levels or "New: <item>" (`LevelPanel`'s glow, the 16
  sparkles and `.levelUp`/`.unlock` go). A quest says which skill grew ("Your patience grew"). A boss says that and
  its badge, and a first says its name. The bursts and haptics stay as they are for bosses and firsts. A title is never
  celebrated with it: the card is the title's only voice.

### 7. No XP on screen, anywhere
XP is not shown on the home cards (a quest's badge goes; its skill line stays), on the quest and boss sheets (the skill,
or the boss's badge), on the moments (picker, page, gold cards), in the timeline (no badge), in the celebration, on the
widget (the skill only, ADR-0023), in the wardrobe, or in any delete prompt. The prompts say what goes, and end with
"Your title and what you got stay." The catalog keeps no string with "XP", "Level" or «Επίπεδο»: a test checks it.

### 8. The wardrobe: only what the hero has
- Per slot, under its skill's name: automatic, nothing, then the items he has.
- There are no locked items, no XP and no condition. A locked item would show what the next title brings.
- A slot with nothing yet is not shown. With nothing at all, one line says "What your hero earns will be here."
- The footnote reads "Your titles bring these. What you have stays yours."
- `SetOutfitChoiceUseCase` checks the item against `DadStanding.gear`.

### 9. The saga film
- **A credits line** after "The hero": «Τίτλος» / "Title", with the title's name in the film's language
  (`SagaFilmTexts`' locale).
- **The hero as he was then** (ADR-0036): the title and gear the entries before the film's end bring. Kept gear counts
  only if the old rule had earned it by then.
- **A film that runs to today** uses his title and gear now, as home does. So a film never shows a lower title than
  home.

### 10. The old level path goes
- **Domain:** `LevelCurve.swift`, `LevelProgress` and `DadProgress.level`. `GearRules.newlyEarned` and the
  skill-XP `earned`. `GearItem.minXP`.
- **Application:** `ProgressChange.newGear`, `gainedXP` and `leveledUp`.
- **Presentation:**
  - Home: `HomeContent.level`, `levelTitle`, `levelFraction` and `xpLine`; `LevelPanel`; `Celebration.xpText`,
    `levelUpText`, `unlockText`, `.levelUp` and `.unlock`. The quest badge, the sheets' rewards and the moments'
    reward.
  - Timeline: the badge.
  - Wardrobe: `xpText`, `isLocked`, `progress` and the locked detail.
- **Shared code:** `XPBar` and its preview (DesignSystem); `Strings.reward(xp:skill:)`; the widget's `reward`.
- **Strings:**
  - deleted: "Level %lld", "New: %@", "Its %lld XP will be removed." and "You earn items with each skill's XP. What
    you earn stays yours.";
  - replaced: "The badge and its %lld XP will be removed." and "The moment, its photos and its XP will be removed.".
- **The website:** "levels" and "collect the XP" in `web/index.html`, `web/el/index.html` and both support pages.
- **Other code that names it:** the README's "level curve". The accessibility audit finds a quest by "XP" in its label
  (`UITests/AccessibilityAuditTests.swift`).

### 11. Shipped content
- **The fixture.** `ShippedContentIDs.json` gains a `titles` section with each title's id, `minCards`, `minXP` and
  `gear`. It is appended to; the gear lines stay as they are.
- **Tests, on top of ADR-0048 §5:**
  - every shipped title is still there, by an id or a former id;
  - a shipped title needs no more cards and no more XP;
  - each item a shipped title brought comes with that title or an earlier one;
  - a shipped gear item keeps its skill (its slot);
  - `skillXPBeforeTitles` is on exactly the items whose fixture line has `minXP`, and is no higher than it.
- **Titles can be renamed** through `formerIDs`, like any content. A kept or seen title id is never rewritten.

### 12. Where the code goes
| Layer | Adds | Changes or removes |
|---|---|---|
| Domain | `DadTitle`, `KeptStanding` (and `undone(to:after:catalog:)`), `DadStanding` and `TitleNews`, `TitleRules` | `DadProgress.cardsDone` (no `level`); `GearRules.earned(_:upTo:kept:)`, `earnedBeforeTitles`, `equipped(_:outfit:)`; `GearItem.skillXPBeforeTitles` (no `minXP`); `ContentCatalog.titles`, `title(id:)`, `title(bringing:)`; `LevelCurve` deleted |
| Application | `StandingRepository` (with `restore`); `StandingKeeper`; `MarkTitleSeenUseCase`; `UndoRecordUseCase`; `EntryRemover`, shared by deleting and undoing | `ProgressRecorder` and `DeleteEventUseCase` keep first; `HomeOverview.standing`; `Wardrobe`, `SetOutfitChoiceUseCase` and `SagaFilm` (`title`) read the standing; `ProgressChange` loses the level and gear, and gains `keptBefore` |
| Data | `titles.json`; `DadTitleDTO`; `SchemaV7` and its stage; `SwiftDataStandingRepository`; `ConnectedStandingRepository`; `LocalStore.standing`; the `StoreV6` fixture | `gear.json` (`skillXPBeforeTitles`); `GearItemDTO`; mappers; `ContentValidator`; `BundledContentRepository`; `ProfileRecord(profile:)`; `CurrentSchema`; `ShippedContentIDs.json` |
| Presentation | the title line; the title card and `HomeViewModel+TitleCard` | home, its sheets, the moments, the timeline, the wardrobe, the film credits, the celebration; the widget's quest tile; DesignSystem (`XPBar` goes, badges optional); strings in el and en |
| App | `store.standing`, `MarkTitleSeenUseCase` and `UndoRecordUseCase` wired | `AppContainer`, `SnapshotTests/SagaFixture.swift` |

## Choices made for the owner to confirm
1. **Undo goes back to before the card** (the owner reversed this choice on 2026-11-22): the title it brought, its level,
   its card and its gear go with it. A deletion from the timeline later keeps the title and gear (§3).
2. **No XP anywhere on screen**, not only on the cards (§7): sheets, timeline, moments, widget, wardrobe, celebration
   and delete prompts.
3. **Wording, written by `content` before the PR:**
   - the card: «Έγινες «…».» / "You became “…”.", «Πήρες: …» / "You got: …", and its button «Ωραία» / "Nice";
   - the celebration's four skill lines ("Your patience grew");
   - the credits role «Τίτλος» / "Title";
   - the wardrobe's footnote and its empty line;
   - the delete prompts' "Your title and what you got stay.".
4. **The cards wait in turn:** the title card first, then a film, then the reminder (§6).
5. **A dad from before titles** sees one card for the title he has, listing only what is new on his hero.
6. **The wardrobe hides locked items** and empty slots (§8). The alternative is to show them without a condition.
7. **In the film,** the title is its own credits line, and shows the title at the film's end (§9).
8. **The title shows** on home and in the film only: not on "Your hero", on the widget or in the notification.
9. **The title ids** in §2.
10. **Title 8, «Σούπερ μπαμπάς» / "Super dad",** kept as the owner wrote it. A dad whose hero class is «Σούπερ
    Μπαμπάς» / "Super Dad" (`h-super`) reads the same words twice, on home and in the credits.
11. **Title 0, «Μπαμπάς σε αναμονή» / "Dad in waiting",** kept, also for a dad whose child is born. Every quest is
    worth at least 20 XP today, so his first card makes him «Νέος στο ταξίδι».

## Rejected
- **Deriving the title from the entries alone:** a deletion would lower it.
- **Undo keeping the title it brought,** as first proposed: the owner wants an Undo to leave nothing of a mistaken tap.
- **Keeping deleted entries as hidden tombstones** that still count: the dad's delete must delete (ADR-0021 §4, the
  privacy pages).
- **"Title reached" as events in the progress log:** every reader of the log would have to skip them, and the card's
  seen state would need somewhere else.
- **The kept record in the app's defaults:** a cut-short start over could hand an old title to a new saga.
- **Keeping the old skill rule live:** skills would still unlock gear, for new dads too.
- **Freezing the old gear inside the migration:** the content and `Timeline` inside a migration closure (§4).
- **A fixed date before which entries count for the old rule:** deleting an old entry would still take gear, and a
  phone's clock decides.
- **Storing the title's order instead of its id:** an inserted title would change every stored number.
- **A separate `GearSlot` type:** the slot has always been named by its skill. It would rename the wardrobe and its
  stored rows for nothing the dad sees.
- **Locked gear shown with the title that brings it, a title ladder, or a count of cards:** each is a "next title"
  hint.
- **A hidden level kept for later:** `LevelCurve` has no reader left.

## Deferred
- Merging the kept record in sync (by order and by union), with the sync ADR (ADR-0026 §6).
- The title on "Your hero" or the widget; a "you became …" entry in the timeline.
- Renaming `DSColor.xp`, now the colour of "done", to a name without XP.

## Verification status
Not yet checked on a device. To check:
- **Installing over a version 6 build:**
  - every item the hero wore is still worn;
  - one title card, listing only what's new;
  - the widget shows "Open DadSaga" until the app has migrated, then the skill without XP.
- **Crossing a title, then Undo:** the title, the card and the gear are as before the card, after a relaunch too; the
  card closed before the Undo comes again with the next card that reaches the title.
- **Deleting an old entry** from the timeline: the title and gear stay.
- **The first quest after onboarding:** title 1, the mug, and the reminder offer after the card is closed.
- **On screen:**
  - no "XP" or level in el and en, on every screen and the widget;
  - VoiceOver reads the card;
  - on iPhone Duo half-open, the card sits below the fold and the title above.
- **A Greek film** on an English phone has «Τίτλος» and the title in Greek.

## Consequences
- The dad sees a name, not a number. The title rises with what he does and never falls back (but for an Undo of the card that brought it), and nothing tells him
  how far away the next one is.
- One early boss can't race through titles: the cards count as much as the XP.
- Deleting an entry from the timeline no longer takes the title or gear back. This reverses ADR-0021 §2 for these two;
  boss medals and moments still follow the entries. An Undo right after recording still takes everything back.
- The old skill rule stays in the content for good, for the eight shipped items, so a store from before titles always
  keeps its gear. Skills unlock nothing new.
- **One stored version more,** three columns on the profile row and a fixture of three small binary files.
- **Every title is a shipped id from now on.**
- **A shipped title can never need more,** and no item can move to a later title.
- **The screenshots and snapshots change** (home, the sheets, the timeline, the wardrobe, the widget, the film
  credits). They are re-recorded when snapshots resume.
