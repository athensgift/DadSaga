# ADR-0078: A birthday comes before a world's end on the same day; the world ages; three rules from the Domain review

**Status:** Accepted (2026-11-25). From the review of the Domain and Application layers (2026-11-25); the owner chose
the birthday. Changes ADR-0036 §7 and ADR-0037 §5 (which occasion wins a child's day; deleting a child for good
forgets the answers about them), ADR-0065 §4 (what deleting for good takes) and ADR-0053 §3 (where a first's dates are
checked). Records the world ages the owner set on 2026-11-25, which ADR-0019 still gives as before.

## Context
- ADR-0036 §7 and ADR-0037 §5: on one child's day a world's end comes before a birthday, and once the dad answers the
  offer no older occasion takes its place. `SagaOccasions.latest(for:)` picks one occasion per child, so a same-day
  occasion of the same child never comes after it either.
- On 2026-11-25 the owner set World 2 to 9–23 months and the Land of No to 24–41 (commit `ac68dbf`, PR #115). No ADR
  has these ages; ADR-0019 says 25–41. World 2 now ends on the second birthday, as the Kingdom of Why ends on the
  sixth. Every entry of the second year is also in World 2, so the second birthday was never offered a film, nor the
  sixth. Run with the bundled ages, an entry every month and each offer answered as it came: years 1, 3, 4, 5 and 7
  were offered; at two, World 2; at six, World 4. The film sheet's default period fell the same way.
- The README says a film is "gently offered on each birthday". The second is the one a family of 1.0 is likeliest to
  meet.
- The answers to the offers are kept by occasion id: `<childID>/birthday/2`, `<childID>/world/<worldID>`. Deleting a
  child for good (ADR-0065 §4) left them in the app's defaults, and every later copy of the saga carried them: a
  random id and no name, but it says that a child existed and which birthdays came.
- ADR-0053 §3 dates a first before birth any day up to today, and every other first from the birth day. The rule lived
  in Presentation (`MomentsFormatter`), held by a date picker's range. `CaptureMomentUseCase` checked only that the day
  isn't in the future, and took a retired first or one not offered before the birth. ADR-0007 puts business rules in
  Domain: an App Intent, a widget action or sync could store "First steps" before the birth, and the film would put it
  in World 0's chapter.
- The weekly quest's number (ADR-0072) was the weeks between two instants. Where a zone's rules changed after 2001 it
  was one short: in `America/Ojinaga` and two `America/North_Dakota` zones, with Sunday weeks, the week that starts on
  the day the clocks go back, every year; in `Pacific/Apia` and `Pacific/Fakaofo`, which skipped a day in 2011, every
  week. The same quest came two weeks running, and the walk from the birth week stopped a step short. Very few people.

## Decision

### 1. A birthday wins the day
- On one child's day, **a birthday comes before a world's end.** It is the day the dad expects, and the year is the
  film he is offered.
- Once he answers it, nothing else is offered that day for that child, as before: the world that ended that day doesn't
  come after it. Children with a birthday on the same day (twins) are still offered one after the other (ADR-0037 §5).
- The film sheet opened with no period takes the same occasion: the year.
- With today's ages, home offers every birthday, and the films of World 0 (on the birth day), World 1 (at 9 months) and
  the Land of No (at 42 months). The films of World 2 and the Kingdom of Why, which end on a birthday, are made from the
  film sheet or the timeline, and never offered.
- `SagaOccasions.latest` loses its `windowDays` parameter, which only tests passed: with the real ages no two occasions
  of one child are less than 30 days apart unless they fall on the same day.

### 2. The world ages
As `worlds.json` has them since commit `ac68dbf`:

| World | Ages | Ends, and its film is offered, on |
|---|---|---|
| 0 `w0-harbour`, the Harbour of Waiting | before birth | the birth day |
| 1 `w1-swamp`, the Swamp of No Sleep | 0–8 months | 9 months |
| 2 `w2-plains`, the Plains of First Steps | 9–23 months | 24 months: the second birthday wins (§1) |
| 3 `w3-no-land`, the Land of No | 24–41 months | 42 months |
| 4 `w4-why-kingdom`, the Kingdom of Why | 42–71 months | 72 months: the sixth birthday wins (§1) |

The Domain tests' fixture (`SagaFixtures`) has these five worlds, so the tests pin what the content does. A change of
ages that moves a world's end onto or off a birthday changes which films home offers, and says so in its PR.

### 3. Deleting a child for good forgets the answers about them
- `SagaOfferRepository.forget(childID:)` removes every answer whose occasion id begins with that child's id.
  `DefaultDeleteChildForGoodUseCase` calls it right after the store has deleted the child, before the reminders are
  scheduled again and the photo files go. It can't fail, so a deletion that happened is never reported as failed.
- A copy made afterwards holds none of them. Copies made before keep them, as they keep the child.
- With iCloud on (the co-op version, ADR-0067), the child's `offer-` records also go from the parent's `Personal`
  zone, and an iPhone that fetches the child's `gone` marker forgets the answers too. Until then
  `SyncedSagaOfferRepository` only passes the call on.
- Nothing new is kept, so the manifests and the privacy pages don't change (ADR-0051 §1): "Delete for good … deletes
  that child, with every entry and photo recorded with them" now holds for the answers about the child too.

### 4. A first's earliest day is a Domain rule
- `UnlockRules.earliestDay(for:child:today:)`: none for a first before birth, which may be dated any day up to today;
  the birth day for every other first, or today while the child isn't born or their birth day is still ahead. The
  capture and edit sheets' date pickers take their range from it.
- **Capturing** a first checks, before anything is written: the child is in the family; the first is offered at the
  child's age today (`UnlockRules.firsts`: never a retired one, and before the birth only firsts before birth); its day
  is neither before its earliest day nor after today.
- **Editing** a first's date keeps the same rule, except that a moment already dated earlier (its child's birth day was
  moved later after it was captured) may keep its day or move later, never earlier, as the editor's picker allows.

### 5. The weekly quest's number
`WeeklyQuest.weekNumber` counts the days between the first days of two weeks on the calendar (`CalendarDay`) and divides
by seven; no instant is compared, so no clock change or skipped day moves it. ADR-0072 says nothing of how the number is
counted, and its guarantees ("in every process", "a new time zone changes nothing while the first day of the week
stays") now hold as written in those zones too, for weeks that start on Sunday, Monday or Saturday. ADR-0072 isn't
changed.

## Rejected
- **A world's end still first:** the second birthday, the one most families of 1.0 meet, would never be offered.
- **After the newest is answered, offering an unanswered occasion of the same day and child,** as twins get: two film
  cards on one birthday, and a dad who said "Not now" asked again the same day.
- **Moving a world's end off a birthday, or World 2 back to 24 months:** the ages are set for the cards, not the offer.
- **Forgetting the answers before the store deletes the child:** a deletion refused in the store's own turn
  (ADR-0068 §3) or one that fails would have taken a removed child's answers, and bringing them back would offer their
  films again.
- **Keeping the answers and leaving them out of a copy:** the defaults would still keep the id.
- **Checking a first's date in the picker only:** any other caller could store it (Context).
- **A strict edit:** a moment whose child's birth day moved later could no longer be saved, not even its note.

## Consequences
- Every child with an entry in the year is offered a film on each birthday, one to seven. World 2's and World 4's films
  are made on demand only.
- Tests that relied on a world first, or on a month between World 2's end and the second birthday, change. A new one
  walks seven years with an entry every month and answers each offer as it comes.
- A first can't be captured for a child who isn't in the family. Recording a quest or a boss for one is still taken
  (the same review's finding 5).
- A kill between the store's deletion and the forgetting leaves the answers, as before.
- In the zones of §5 the weekly quests' order changes once; nothing has shipped (ADR-0060).
- No schema, content id, stored field or Info.plist key changes.
