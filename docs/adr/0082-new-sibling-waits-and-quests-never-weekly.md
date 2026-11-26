# ADR-0082: The new sibling waits in "When life changes", and quests that are never the weekly quest

**Status:** Accepted (2026-11-26, by the owner). From the review of 2026-11-25, decided item by item on 2026-11-26.
Changes ADR-0053 §5 and ADR-0080 §2 (the situational bosses) and ADR-0072 §1 (which cards the weekly quest is picked from).

## Context
- `b-w3-new-sibling` ("The New Roommate", `onlyFor: ["youngerSibling"]`) lives in World 3, 24–41 months. A brother or
  sister who arrives when the child is four or five never met it: World 4 didn't offer it. Its intro said "A baby has
  arrived", though ADR-0053 §4 offers it while the sibling is still on the way.
- `FamilyFacts.hasYoungerSibling` holds for a younger sibling of any age. A boss for a new sibling, open on home, stood
  in front of a child whose sibling is long settled. Made evergreen, it would have stood there to age six.
- The weekly quest (ADR-0072) is the one card the widget and the notification put in front of every dad. Some quests
  fit only some homes or some days, with no family fact to tell: introducing a pet (`q-w1-pet-intro`), bottle feeding
  (`q-w1-bottle-engineer`), welcoming the visitors (`q-w0-welcome-crew`), mending something broken (`q-w3-repair`).
  Suggested to a dad with no pet or no bottle, they say the app doesn't know his home. On the map and on home, where he
  picks, they are right.
- ADR-0006: the suggestion never chases; nothing is stored about what he did or skipped.

## Decision
1. **`b-w3-new-sibling` is `"situational": true`** (the owner, 2026-11-26), not evergreen: it waits in World 3's closed
   row "When life changes", for the dad to open when a sibling is on the way or has arrived, and once recorded reads
   "You were there" (ADR-0079). It keeps `onlyFor: ["youngerSibling"]`: situational bosses are offered by age and
   audience like any boss (ADR-0053 §5). Its intro, in both languages, holds both before and after the birth. The
   situational bosses are five: `b-w1-early-start`, `b-w3-new-sibling`, `b-w4-two-homes`, `b-w4-big-goodbye`,
   `b-w4-big-move`.
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
- A sibling who arrives after World 3 (the child 42 months or older) still meets no new-sibling boss: World 4 has
  none. The owner chose a closed row over showing it to every older brother or sister to age six.
- A dad who has a pet still finds `q-w1-pet-intro` on home; it is just never the week's one suggestion.

## Rejected
- **A family fact per card** (has a pet, bottle feeds): more questions in onboarding for one card each, and facts
  about the home the app has no other use for.
- **`b-w3-new-sibling` evergreen:** first decided, then dropped the same day. It would stand open on home to age six
  for any child with a younger sibling, however long ago the sibling came.
- **Moving `b-w3-new-sibling` to World 4 or duplicating it:** two cards for one moment, or none for a two-year-old.
