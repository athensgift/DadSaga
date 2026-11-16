# ADR-0020: Card tips, evergreen cards and a sibling-only boss

**Status:** Proposed. The content is written (branch `feature/content-review-0-6`); the code below is not. Points marked
**(owner)** still need the owner's yes.

## Context
The content review for ages 0–6 (`docs/content-review-0-6.md`) rewrote the card set against one test: "would an experienced
dad tell this to a friend who just became one?" Three things came out of it that the current schema cannot express:

- **Tips.** A card title says what to do; the useful part is how. 40 of the 55 quests now carry a short tip in the JSON
  (`tip`), 12 of them about health or safety. The app does not read the field, so none of it is visible.
- **Needs that do not belong to one age.** "Time for you", "date night" or "the apology" matter at every age, but a quest
  belongs to exactly one world and home shows one world. The old content worked around this by writing the same card twice
  ("Time for you" and "Your own hobby"). 14 quests are now marked `evergreen` in the JSON instead.
- **A boss that only some families meet.** "The New Roommate" (a new sibling) means nothing to a one-child family, and a boss
  that can never be beaten sits on the world map as something missing, which ADR-0006 rule 4 forbids.

The review also found that the "done / total" counters shown on the world map and on legendary moments break the same rule:
a child who never crawled leaves "13 / 14" forever.

The app is in development with no released version and no migrations: removed or renamed content ids are simply dropped, and
old events that reference them are ignored (ADR-0005).

## Decision

### 1. Quest tips
- JSON: optional `tip` on a quest: `{ "title": {el,en}, "steps": [{el,en}, …], "medical": true? }`. One to five steps.
- Domain: `QuestTip(title: LocalizedText, steps: [LocalizedText], isMedical: Bool)` and `Quest.tip: QuestTip?`.
- Data: `QuestTipDTO`, mapped in `ContentMappers`. `ContentValidator` rejects a tip with no steps.
- Presentation: the quest sheet (`QuestSheet` in `Home/HomeSheets.swift`) shows the tip under the description, with the same
  numbered-steps look as a boss guide, so there is one visual language for "how to". A card with a tip shows a small marker
  on `QuestCard` so the dad knows there is more inside.
- **Medical footer.** When `isMedical` is true the sheet ends with one fixed line, "General information. It does not replace
  your paediatrician." / «Γενικές πληροφορίες. Δεν αντικαθιστούν τον παιδίατρό σου.» The line lives in `HomeStrings`, not in
  the JSON, so it cannot be forgotten on a card or drift between cards. Boss guides get the same footer.
- Sources stay out of the app. They are listed in the review doc.

### 2. Evergreen quests **(owner: decision 2)**
- JSON: optional `evergreen: true`. Domain: `Quest.isEvergreen`.
- Rule (Domain, `UnlockRules`): the quests shown for a world are that world's own quests **plus** every evergreen quest from
  an earlier world, each still gated by its own `minAgeMonths`. Add
  `UnlockRules.quests(for world: World, in catalog:, ageInMonths:)` and use it from `HomeViewModel`, which today filters by
  `worldID` itself (`HomeViewModel.swift`, the `availableQuests.filter { $0.worldID == worldID }` line). The filter moves out
  of Presentation.
- An evergreen quest is listed after the world's own quests, so what is new for the child's age comes first.
- World-map counts include an evergreen quest only in its home world.
- XP, skills and completions are unchanged: it is the same quest id wherever it is shown.
- **No `maxAgeMonths` on quests.** The review proposed it (decision 3), but home already shows only the current world, so a
  card leaves the screen when the child leaves its world. With evergreen in place nothing needs a second age bound.

### 3. Sibling-only bosses **(owner: decision 4)**
- JSON: optional `requiresSibling: true` on a boss. Domain: `BossFight.requiresSibling`.
- Rule (Domain): `UnlockRules.availableBosses` takes the number of children in the profile and drops these bosses when it is
  one. `GetAdventureUseCase` passes `profile.children.count`.
- The condition reads the family, never the child's development, so ADR-0006 rule 3 holds.
- The boss is excluded from world-map counts when it is hidden.

### 4. Counters without denominators **(owner: decision 6)**
- World map: "7 quests · 1 boss" instead of "7 / 10 quests · 1 / 2 bosses" (`HomeStrings`, `WorldMapSheet`).
- Legendary moments: the number captured, without the total.
- A past world shows what was kept there, not what was left undone.

## Implementation order
One PR, in this order, each step green before the next:

1. Domain: `QuestTip`, `Quest.tip`, `Quest.isEvergreen`, `BossFight.requiresSibling`; the two `UnlockRules` changes. Tests:
   evergreen quest appears in a later world and respects its minimum age; a sibling-only boss is hidden with one child and
   shown with two.
2. Data: DTO fields, mappers, validator. Tests: a tip maps with its steps and medical flag; a tip with no steps is rejected.
   Extend `noEmptyText` in `BundledContentRepositoryTests` to cover tip titles and steps.
3. Application: `GetAdventureUseCase` passes the child count.
4. Presentation: quest sheet tip section, medical footer, card marker, world-map and moments counters. `HomeViewModel` uses the
   new rule.
5. Verify in the simulator: a card with a medical tip, a card without a tip, an evergreen card seen from world 4, the world
   map, and a one-child profile against a two-child one. iPhone Duo too, since the sheet layout changes.

## Consequences
- The research becomes visible in the app, and the health wording has one owner (the footer string).
- Evergreen cards remove duplicated content and keep the dad's own wellbeing on screen at every age.
- Three optional fields are added to the content schema. A future Android client must read them too.
- Old timeline entries for the five deleted quests disappear, and three ids changed (`q-w1-floor-scout`, `q-w3-bike-pilot`,
  `b-w1-teething`). Acceptable before the first release; not after it.
- Not in this ADR: "card of the day", "new card for this age" notifications and "on this day". They are product ideas from
  the review and belong to Phase 3.
