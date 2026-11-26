# ADR-0082: The new sibling at every age from two, and quests that are never the weekly quest

**Status:** Accepted (2026-11-26, by the owner). From the review of 2026-11-25, decided item by item on 2026-11-26.
Changes ADR-0053 §5 (the evergreen bosses) and ADR-0072 §1 (which cards the weekly quest is picked from).

## Context
- `b-w3-new-sibling` ("The New Roommate", `onlyFor: ["youngerSibling"]`) lives in World 3, 24–41 months. A brother or
  sister who arrives when the child is four or five never met it: World 4 didn't offer it. Its intro said "A baby has
  arrived", though ADR-0053 §4 offers it while the sibling is still on the way.
- The weekly quest (ADR-0072) is the one card the widget and the notification put in front of every dad. Some quests
  fit only some homes or some days, with no family fact to tell: introducing a pet (`q-w1-pet-intro`), bottle feeding
  (`q-w1-bottle-engineer`), welcoming the visitors (`q-w0-welcome-crew`), mending something broken (`q-w3-repair`).
  Suggested to a dad with no pet or no bottle, they say the app doesn't know his home. On the map and on home, where he
  picks, they are right.
- ADR-0006: the suggestion never chases; nothing is stored about what he did or skipped.

## Decision
1. **`b-w3-new-sibling` is `"evergreen": true`,** from 24 months (its `minAgeMonths`), still only for a child with a
   younger sibling, born or on the way. It is offered in World 3 and in every later world and counted on the map in
   World 3 only (ADR-0053 §5). Its intro, in both languages, holds both before and after the birth. Its id stays: the
   content rules don't ask an evergreen card's id to name every world it shows in.
2. **A quest may be left out of the weekly pick:** `"weekly": false` in `quests.json`, `Quest.isWeekly` in Domain
   (`true` when the field is absent). Such a quest is offered everywhere else as before: home, the map, links. The
   weekly quest's pool (ADR-0072 §1) is the quests on offer that week that are weekly; the walk of §2 uses the same
   pool, so the app, the widget and the notification still agree. The four quests above are the first.
3. **The validator:** a world with quests of its own, none of them weekly and not retired, fails the load
   (`ContentDataError.noWeeklyQuest`). The flag is for a few cards. The check doesn't weigh `onlyFor` or ages; the
   bundled-content tests walk every week to six with the shipped cards.

## Consequences
- Every child's weekly order changes once; nothing has shipped (ADR-0060).
- Nothing is stored: no schema, privacy page, manifest or Info.plist key changes.
- `hasYoungerSibling` holds for a sibling of any age, so a five-year-old whose sibling is four is offered the boss
  too, as a three-year-old with a one-year-old already was in World 3. Making it situational as well is the owner's
  call, not taken here.
- A dad who has a pet still finds `q-w1-pet-intro` on home; it is just never the week's one suggestion.

## Rejected
- **A family fact per card** (has a pet, bottle feeds): more questions in onboarding for one card each, and facts
  about the home the app has no other use for.
- **Moving `b-w3-new-sibling` to World 4 or duplicating it:** two cards for one moment, or none for a two-year-old.
