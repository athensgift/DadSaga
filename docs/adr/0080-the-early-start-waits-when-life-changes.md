# ADR-0080: "The Early Start" waits in "When life changes"

**Status:** Accepted (2026-11-25, by the owner). From the review of 2026-11-25. Changes the list of situational bosses
in ADR-0053 §5.

## Context
- ADR-0053 §5 made three World 4 bosses situational: the two homes, a death in the family and a move.
- `b-w1-early-start` is about a baby in the neonatal unit. It was an open boss, so it stood on home for every dad of a
  newborn. Most of them will never meet it and could never beat it (ADR-0006 rule 4), and its first lines are a hard
  scene for a dad who doesn't need them.

## Decision
1. **`b-w1-early-start` is `"situational": true`.** It waits in the closed row "When life changes" at the end of World
   1's cards, and once recorded it reads "You were there" (ADR-0079).
2. **The situational bosses are four:** `b-w1-early-start`, `b-w4-two-homes`, `b-w4-big-goodbye`, `b-w4-big-move`.
3. **`b-w0-caesarean` stays as it is,** an open boss.

## Consequences
- World 1 gets the row "When life changes", with one boss in it. No code changes: the flag does it.
- The test that pins the list has four ids.
