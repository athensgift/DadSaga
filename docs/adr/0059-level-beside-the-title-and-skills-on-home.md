# ADR-0059: A level beside the dad's title on home, and his four skills as marks that grow with every card

**Status:** Accepted (2026-11-22): the owner's decisions are final, and he confirmed the choices listed under "Choices
made for the owner to confirm" the same day. Numbered 0059 because another branch takes 0057. It changes:
- **ADR-0055** (itself still Proposed):
  - §2: a title's order is also its level, and orders run without gaps.
  - §6: home's title line has the level, the four skills sit under it, and the title card has a level line.
  - §7: the catalog may hold the level word, still no XP.
  - §10: «Επίπεδο %lld» comes back, now meaning the title's level.
  - §11: shipped titles keep their order, and a skill's curve is a shipped value.
- **ADR-0005:** a new kind of content, `skills.json`.
- **ADR-0012:** the dad's title has a level.
- **ADR-0043 §3:** the hero's pane holds the level and the four skills.
- **ADR-0056 §3:** above the fold the hero yields width to the skills; side by side he yields height, so his pane
  fits.
- **ADR-0048 §5:** a shipped title keeps its order, and a skill's half-grown XP never rises.

## Context
- **Today** (ADR-0055):
  - Home shows the title's name under the hero (`TitleLine`), with no number, and XP is never on screen.
  - The four skills (`Skill`: care, play, patience, resilience) are on every quest and boss and in
    `DadProgress.skillXP`. On screen they are only a card's skill line and the celebration's "Your patience grew".
  - The catalog holds no "XP", "Level" or «Επίπεδο» (`CatalogTests.noXPOrLevels`).
- **What follows the entries** (ADR-0021 §2, ADR-0055 §3):
  - The title and its gear are kept on the profile row, so a deletion never lowers them.
  - Everything else follows the entries, the boss medals on the hero included.
  - Skill XP isn't kept: an undo or a deletion takes back what that card gave. A shipped card never loses XP or moves
    skill (`ShippedContentIDsTests`). A first has XP but no skill.
- **The owner's decisions (2026-11-22, final):**
  - **A level beside the title, on home only.**
    - It counts from 0: the level is the title's order. «Μπαμπάς σε αναμονή» is Level 0, «Σίγουρα χέρια» Level 4 and
      «Μπαμπάς-θρύλος» Level 9, e.g. «Επίπεδο 4 · Σίγουρα χέρια» / "Level 4 · Steady hands".
    - It is also a line on the title card.
    - It is not in the film's credits, the widget, "Your hero" or the notification.
    - There is no total, no bar and no "X to go".
    - It comes from the title held, and nothing new is stored.
  - **The four skills on home, under the title:** small symbols that grow a little with every card, each with its
    skill's name under it. There is no maximum, no number, no XP and no next step: progress that looks back.
  - **The skills follow the entries:** they come from `DadProgress.skillXP` alone. An undo or a deletion can shrink a
    mark visibly, as it takes a boss medal. The title still stays (ADR-0055).
  - **A first grows no skill.**
  - **One curve for all four skills for now,** in the content.
  - **The catalog test** allows the level word, but still no XP.
- **Title orders aren't checked for gaps:** the validator checks only that each title needs more than the one before
  it. A gap would skip a level, and reordering shipped titles would lower one.
- **iPhone Duo** (ADR-0043 §3, ADR-0045, ADR-0056 §3, ADR-0058):
  - Half-open, or open and upright, the hero's pane is above the fold. The hero stands beside his lines and title,
    except at the accessibility text sizes, where they stack and the pane scrolls.
  - The hero's height is what the pane's title leaves, between 120 and 260 pt.
- **What Apple documents (checked 2026-11-22):**
  - `symbolEffect(_:options:value:)` (iOS 17): "the animation is triggered each time the value changes".
  - `@ScaledMetric(wrappedValue:relativeTo:)` is iOS 14+; `ViewThatFits(in:)` is iOS 16+ and picks the first child
    that fits.
  - `accessibilityElement(children:)` (iOS 13) and `accessibilityValue(_:)` (iOS 16).
  - `Image(systemName:variableValue:)` (iOS 16) changes only symbols that support a variable value; others ignore it.
    `symbolVariableValueMode(_:)` (iOS 26) has `.color` and `.draw`; draw "changes the drawn length of each variable
    layer".
  - Nothing here needs an API newer than iOS 17.
- ADR-0006: XP for the dad's actions, nothing ever lost, no streaks, no deadlines.

## Decision

### 1. The level is the held title's order
- **The level is `DadTitle.order`,** read from `DadStanding.title`, the title held, so it never goes down. There is no
  new property and nothing is stored. `order`'s comment says it is also the level.
- **Orders run 0, 1, 2 … with no gap and no repeat** (`ContentValidator`, `ContentDataError.invalidTitleOrder`). This
  replaces the check that two titles don't share an order.
- **A shipped title keeps its order for good,** so a new title can only come after the highest:
  - `ShippedContentIDs.json`'s title lines gain `order`, as it shipped. This adds a field to each line and removes
    nothing.
  - A test checks that each shipped title's order is unchanged.
  - So "Level 4" always means the same title, and adding a title never changes a dad's level.
- **On home,** the title line reads «Επίπεδο 4 · Σίγουρα χέρια» / "Level 4 · Steady hands": the catalog's
  «Επίπεδο %lld» / "Level %lld", then the name.
  - VoiceOver reads a comma in place of the dot.
  - A new dad reads «Επίπεδο 0 · Μπαμπάς σε αναμονή».
  - There is no total, no bar and no next title.
- **On the title card,** a line under its heading says «Επίπεδο 4» / "Level 4" (the detail line of `OfferCard`).
  VoiceOver hears it with the card, once.
- **Nowhere else:**
  - The film's credits keep the name alone. `SagaFilmViewModelTests` still forbids "Level" and «Επίπεδο» in a film.
  - The widget, "Your hero", the notification, the celebration and the timeline don't show it.

### 2. The four skills: marks that grow with every card and never fill
- **Below the title line, four marks,** always in the same order (care, play, patience, resilience, as
  `Skill.allCases`), never sorted by size.
  - Each is the skill's symbol from the cards (`Skill.symbol`), with the skill's name under it: «Φροντίδα»,
    «Παιχνίδι», «Υπομονή», «Αντοχή» / "Care", "Play", "Patience", "Resilience".
  - There is no number, no XP and no word for how far a skill has grown.
- **How much a skill has grown** (`SkillGrowth`, Domain) is `xp / (xp + halfGrownXP)`, from `DadProgress.skillXP`:
  - It is 0 before any card of that skill.
  - Every card of the skill raises it, and it never reaches 1.
  - It is half grown at `halfGrownXP` and three quarters grown at three times that.
  - There are no stages, no maximum to reach and no number.
  - Home's query returns it (`HomeOverview.skills`).
- **How a mark is drawn** (`SkillMarkLook`, Presentation):
  - The symbol is in the accent tint. It is 60% of its circle with no growth, and nears 100% as the growth nears 1.
  - A soft glow and a wash of the tint behind it grow with it.
  - The look follows the square root of the growth, so the first card shows clearly (one quest of 20 XP: the symbol
    from 60% to about 74%, a glow at about a third, the wash from 35% to about 57% of its ceiling) and later cards
    still show, ever less, with no end.
  - The wash never goes above the tint's wash opacity, so the symbol keeps its contrast (ADR-0032). With no growth it
    is 35% of that, so a new mark is never empty.
  - The circle never changes size, so a mark growing or shrinking moves nothing on screen.
  - The name is secondary text in the caption style (ADR-0033).
- **A mark that hasn't grown looks new, not missing:** full colour, never grey, dashed, empty or locked.
- **Nothing fills up:** no ring, no bar and no variable symbol. Each would show how much is left.
- **Each card shows on its mark:**
  - When a quest or boss is celebrated, its skill's mark bounces once.
  - It bounces as the celebration's badge goes (`HomeViewModel.celebrationFinished`), so the badge never hides it.
  - A celebration replaced by a newer one (a second card within seconds, or a moment's as its sheet closes) has gone
    too, so its mark bounces as it is replaced. One taken back by an undo bounces nothing.
  - The view model keeps which skill each celebration grew; the screen's models carry only a mark's id, no Domain
    type (ADR-0007).
  - With Reduce Motion it doesn't bounce (`symbolEffectsRemoved`), not even when the setting changes, and the
    celebration still says "Your patience grew".
- **An undo or a deletion** takes back what that card gave, and the mark is drawn smaller at once, with no
  animation, which would only draw his eye to it. The title and its gear stay (ADR-0055 §3).
- **A first grows no skill,** since it has none. It counts toward cards done and the title, as now.
- **The curve is content, in `skills.json`,** with one entry per skill and 150 for all four for now:
  ```json
  { "skill": "care", "halfGrownXP": 150 }
  ```
  - Quests give 20 to 35 XP: one quest grows its skill by about 12% to 19%, about six quests bring it to half grown,
    and about eighteen to three quarters. It never reaches the whole.
  - Checked at load:
    - each of the four skills appears exactly once, and nothing else does (`.unknownSkill`, `.missingSkillCurve`,
      `.duplicateID`);
    - `halfGrownXP` is above 0 (`.invalidSkillCurve`).
  - A shipped value never rises, since an update raising it would shrink every dad's marks without him doing
    anything. `ShippedContentIDs.json` gains a `skills` section, and a test checks it.
  - The file has no text: skill names stay UI strings in the catalog (ADR-0027).
- **VoiceOver:** the row is one element, with no number.
  - Its label is «Οι δεξιότητές σου» / "Your skills", and its value is the four names as a list (`ListFormatStyle`).
  - The celebration's line says what grew.
- **Dynamic Type:**
  - The circle grows with the headline style (`@ScaledMetric`, 36 pt at the default size).
  - The names grow with every text size, with no limit (ADR-0033).
  - All four sit side by side when they fit. If not, they go two by two, and at the largest sizes in one column, each
    symbol beside its name (`ViewThatFits`).

### 3. Home, and the iPhone Duo
- **The title line and the marks make one panel** under the hero's lines, where the title line is now: `TitleLine`
  with the level, then `SkillMarks`. In one column it scrolls with the hero.
- **Above the fold** it stays in the hero's pane, beside the hero and under his lines.
  - His column takes half the pane, or more when the four skills need it to stand side by side: the hero yields the
    width, never less than 160 pt of stage. So at xxxLarge the marks stay in one row and the panel stays above the
    fold, where two by two would push it and the hero's feet under it. The panel learns the row's width from a hidden
    copy of it.
  - The hero's height rule doesn't change (ADR-0056 §3).
  - At the accessibility text sizes the panel follows the hero and the pane scrolls, as now.
- **Side by side** (on its side, or two columns), the hero yields height instead: he is what his pane, inside the
  safe area, leaves after its title and what stands under him, between 120 and 260 pt. So at xxxLarge the skills sit
  above the home indicator without scrolling; at the accessibility sizes he stops at 120 pt and the pane scrolls.
- **The bounce** is in the hero's pane, away from the fold.

### 4. The catalog test
- No key or text says "XP", as now.
- "Level" and «Επίπεδο», in any case or ending, appear only in the one key «Επίπεδο %lld» / "Level %lld". So
  "levels", "next level" or "Level 4/9" can't come back through the catalog.

### 5. Where the code goes
| Layer | Adds | Changes or removes |
|---|---|---|
| Domain | `SkillCurve`, `SkillGrowth` | `ContentCatalog.skillCurves` and `curve(for:)`; `DadTitle.order`'s comment |
| Application | | `HomeOverview.skills` |
| Data | `skills.json`; `SkillCurveDTO` | `ContentValidator` and `ContentDataError` (title order, skill curves); `BundledContentRepository`; mappers; `ShippedContentIDs.json` (title `order`, `skills`) |
| Presentation | `SkillMarks`, `SkillMarkLook`, `SkillMarksModel`, `TitleLineModel`, `HomeViewModel+Standing`, `HomeView+HeroPanel` | `HomeContent.dadTitle` (a model, not a string) and `skills`; `TitleCard.level`; the skill that grew, kept in the view model after the celebration; `TitleLine`; `OfferCard`; the card's announcement; `HomeArrangement.maxHeroSize` (side by side); strings in el and en |
| App | | none: no new use case or repository |

No stored data changes: no schema version and no change to the privacy pages or manifests (ADR-0051).

## Choices made for the owner to confirm
1. **VoiceOver hears the row as one element:** "Your skills", then the four names.
2. **One look for all four:** the accent tint, and the name in secondary text under the symbol.
3. **The bounce comes as the celebration's badge goes,** not with it.
4. **A mark that shrinks after an undo or a deletion** is redrawn smaller at once, without animation.
5. **Wording,** written by `content` before the PR: «Επίπεδο %lld» / "Level %lld" and «Οι δεξιότητές σου» / "Your
   skills".

## Rejected
- **A level from XP** (`LevelCurve`): it went in ADR-0055, and it would drop with a deletion.
- **A level of the order + 1,** so that the first title is Level 1: the owner counts from 0.
- **"Level 4 of 9", a bar, or the next title's level:** each hints at the next level.
- **Keeping each skill's highest XP so a mark never shrinks** (a new schema version on the profile row, written before
  a deletion): a new stored version, a fixture and a privacy-page line, for little gain. The owner chose that the marks
  follow the entries, as the boss medals do.
- **Keeping the XP of deleted entries as a running total per skill:** also stored, and a mistaken tap would count for
  good.
- **Named stages for a skill** («Αρχάριος», «Έμπειρος»): a ladder with a top, and a next step to read.
- **A ring, a bar or a variable symbol that fills up** (`variableValue`, the draw mode): a full state is a cap, and it
  shows what is left. A variable value also works only on symbols that support them.
- **A mark that grows without limit:** no screen has room for it. The curve grows without ever reaching a top instead.
- **Symbols without names:** the dad would have to learn them from the cards.
- **A limit on the marks' Dynamic Type:** the names are text, and text grows with every size (ADR-0033).
- **Skills per child:** the XP is the dad's, from every child together (ADR-0012).
- **Sorting the marks by growth, or pointing at the smallest:** a nudge toward what wasn't done (ADR-0006).

## Deferred
- Each skill its own `halfGrownXP`. Play has fewer cards and no bosses, care the most. The file already has one entry
  per skill.
- The level on "Your hero" or the widget.
- "Levels" on the website (ADR-0055 §10 removed it), until the owner wants it said.

## Verification status
Not yet checked on a device. To check:
- **A quest, then Undo:**
  - the mark goes back to where it was, with no animation;
  - the title and its card stay, after a relaunch too.
- **Deleting an old boss** from the timeline: its skill's mark is smaller, and the title and gear stay.
- **The first quest after onboarding:**
  - «Επίπεδο 0 · Μπαμπάς σε αναμονή» becomes «Επίπεδο 1 · Νέος στο ταξίδι»;
  - the title card says «Επίπεδο 1»;
  - the quest's mark bounces after the celebration.
- **On screen:**
  - el and en;
  - VoiceOver reads the title line with a comma, and "Your skills" with the four names;
  - with Reduce Motion there is no bounce;
  - the largest text sizes, with nothing clipped;
  - on the iPhone Duo half-open and open upright, the panel is above the fold at the default size and at xxxLarge;
  - on the cover display, one column.
- **No level** in a film, the widget, "Your hero" or the notification.

## Consequences
- The dad sees a level and a name, and four marks with their names that grow with every card of their skill. Nothing
  on home says how far away the next title is.
- A level is a number on screen again, but it comes from the title, so it rises only with a title and never falls.
- An undo or a deletion can shrink a mark, as it takes a boss medal. That is the dad correcting his own log
  (ADR-0021); his title and gear stay.
- **No stored change:** no schema version, no fixture, no privacy-page change.
- **New titles can only be added above the highest.**
- **A skill's `halfGrownXP` can only be lowered once it has shipped.**
- The screenshots and snapshots of home and the title card change. They are re-recorded when snapshots resume.
