# ADR-0072: The weekly quest is the card on offer that came up longest ago

**Status:** Proposed (2026-11-25). Changes ADR-0023 §1: the order of the weekly quest, and the age the birth week is
taken at. Designed by the architect.

## Context
- ADR-0023 §1: "Week *n* shows card *n* mod count, so every card comes up once before any repeats." That holds only
  while the pool stays the same. When it changes (a card's `minAgeMonths` is reached, the world changes), the count and
  the shuffle change together and the index jumps: a card shown a week or two ago can come back while others on offer
  have never come up.
- The app, the read-only widget and the scheduler must agree without talking to each other, so nothing can be stored.
  The scheduler asks for four weeks ahead, so a week's answer can't depend on the week it is asked from.
- A born child's pool changes only with age. The content ends at 71 months, so a child has at most about 313 weeks.
- Nothing may look at what the dad did or left undone (ADR-0006).

## Decision

### 1. The rule
The quest of a week is **the card on offer that week that came up longest ago; a card that never came up goes first**.
Between cards that never came up, the child's shuffle decides (the same FNV-1a rank, then the id), so siblings differ.
With a pool that doesn't change this is the fixed cycle of ADR-0023.

### 2. When a card came up is worked out, not stored
- **Before the birth week, and for a child not born yet,** the pool is World 0's and doesn't change with age. The week
  shows card *n* mod count of the shuffle, as today. No walk, however far the week is.
- **From the birth week on,** the weeks are walked from the birth week to the asked one, applying §1 in each. The walk
  starts knowing nothing of the weeks before the birth.
- A child past the content has no quest and no walk. The pool is worked out once per age, not once per week.
- **One rule for a week's age,** used for the asked week and for every week walked: the age on the week's first day, and
  in the birth week the age on the birth day, so a baby born mid-week gets a card for after the birth that week.

### 3. One note a week, about this family
- The reminder keeps when its notes are due, in the app's own defaults. A week whose note's time has passed gets no
  other, whatever the dad changes (ADR-0024 §1). A note is due by the clock on the wall, as iOS delivers it, so one
  that arrived just before the dad crossed a border to the west can come again within that hour.
- Besides ADR-0024 §2, the notes are scheduled again when the dad comes back with notifications allowed, and when a
  child is removed or deleted for good. Removing or deleting a child also takes away the notes already shown, as
  starting over and importing do.
- When the saga can't be read, the notes already waiting stay.

### 4. Where the code goes
| Layer | Changes |
|---|---|
| Domain | `WeeklyQuest.pick(for:family:in:week:calendar:)` takes the child, the family's facts and the catalog, and works out each week's age and pool itself through `UnlockRules`. `pick(from:childID:week:calendar:)` goes: a caller can't give the pool of a week it doesn't know. |
| Application | `GetWeeklyHighlightsUseCase` hands the facts over; no age or pool of its own. |

The quest stores nothing: no schema, content id or Info.plist key changes. The note times of §3 are on the privacy
pages (ADR-0051).

## What is guaranteed
From the birth week on, and apart before it, with the same catalog, family facts, birth day and first day of the week:
- **A card comes back only after every other card on offer that week has come up since.** This holds through a growing
  pool, a shrinking one and a change of world.
- A card that stays on offer comes up within as many weeks as there are different cards on offer in that time.
- The same answer all week, in every process, from whichever week it is asked, whatever the dad did.

## What is not
- **A card that leaves before its turn** (its world ends) may never come up.
- **A catalog update, a changed partner answer, an added or removed sibling, an edited birth day, a different first day
  of the week:** the past is worked out as if it had always been so. This week's card may change at once, one already
  seen may come back early, and a card the dad never saw may count as having come up. The guarantee starts again from
  the change. Unticking "Not born yet" changes no week before the birth week; a new time zone changes nothing while the
  first day of the week stays.
- **Across the birth:** first aid (`q-w0-first-aid`, World 0's one evergreen card) may come up shortly before the birth
  and again soon after it.
- **What the dad really saw:** the walk knows no install day. Cards of the weeks before he installed the app count as
  having come up.

## Rejected
- **Storing the last card shown:** the widget can't write, and two processes could disagree.
- **Rounds** (a set of cards shown, emptied when full): a card that joins late can end one round and start the next,
  two weeks in a row.
- **One fixed list of every card of the world, skipping those not reached:** skipping shows the same card again.
- **New cards at the end of the list, *n* mod count from the world's start:** the index still jumps when the count
  grows after the first cycle.
- **Starting the walk from what came up before the birth:** it would put first aid behind every card of World 1, about
  seven months, for every dad who starts after the birth, to spare one repeat to a dad who started before it.
- **The walk from the world's start:** evergreen cards could come back right after a change of world.

## Consequences
- Every child's order changes once; nothing has shipped (ADR-0060).
- A card newly reached comes up soon after its age, ahead of every repeat.
- About 313 steps at most for one answer, on pools of some 40 cards.
