# ADR-0017: A timeline tab built from progress events

**Status:** Accepted

## Context
The family's history (quests, bosses, legendary moments for every child) had nowhere to be seen together, and home
was getting long.

## Decision
- **The timeline is derived, not stored.** `Timeline.entries(from:catalog:)` (Domain) turns progress events into
  entries, newest first, with the same rules as `DadProgress`: unknown content is skipped and a boss or first appears
  only once per child. No new storage, so it can never disagree with XP.
- **Grouped by month** ("Νοέμβριος 2026", the stand-alone month form), with a filter: everyone or one child. Child names
  are shown only when there are several children and the filter is "everyone".
- **Two tabs:** Adventure (home) and Timeline, with the system Liquid Glass tab bar that shrinks while scrolling. The
  timeline reloads each time its tab appears, so it shows what was just done on home.
- Moment photos appear in the timeline through the same `PhotoStore`.

## Consequences
- Home is unchanged for now; moving legendary moments or the family into their own tabs is possible later.
- The timeline is read-only. Moments are still edited from home.
