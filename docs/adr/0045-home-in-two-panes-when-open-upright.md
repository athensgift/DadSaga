# ADR-0045: Home in the same two panes when iPhone Duo is open and upright

**Status:** Accepted (2026-11-20). The owner tried ADR-0043 on the inner display and asked for home, open and upright,
to show "the avatar above, the rest below" instead of two columns. Changes ADR-0043 §3 (home open flat in portrait)
and its Consequences (folding home no longer swaps columns for rows). Numbered 0045 because 0044 is taken by a branch
in progress.

## Context
- ADR-0043 gave home two panes above and below the fold while the Duo is half-open like a laptop, and kept ADR-0011's
  two columns whenever the inner display lies flat, upright too. So folding an upright Duo swapped columns for rows,
  which the HIG advises against ("avoid extreme layout changes as people fold the device"), and upright the columns
  are narrow: 334 pt each.
- `GeometryProxy.reservedRegions(kind: .division, options: .includeInactive)` reports the fold while the device lies
  flat as well, as a region with no thickness. In the iPhone Duo simulator (iOS 27.2) it does so for the inner display
  open at 180°.

## Decision
- **Open and upright, home is split where it folds**: the hero's pane above, today's adventure below, each scrolling
  on its own. They are the same two panes as half-open (ADR-0043 §3), so folding only opens the fold's gap between
  them, and nothing is rebuilt.
- **On its side, home keeps two columns** (ADR-0011): there the fold runs down between them, flat or half-open like
  a book.
- The reader takes `whileFlat: true` to include a fold with no thickness; `HomeArrangement.make` takes that fold as
  `flatFold`. It splits home only where there would otherwise be two columns (600 pt and wider), so a narrow window
  over the fold stays one column. A fold that is active wins over its flat place.
- Only home asks for the flat fold. The sheets, the film and the timeline split only while half-open, as in ADR-0043:
  flat, each is one page to read.

## Rejected
- **One scrolling column open and upright**, as on the cover display: folding would then rebuild home into two panes
  and lose where it was scrolled to. The owner chose the two panes.
- **Splitting at half the height** instead of asking where the fold is: it would be a few points off the fold, so
  home would jump when the device folds.

## Verification status
Drawn in the iPhone Duo simulator (iOS 27.2): open and upright (two panes), folded to 90° from there (the same panes,
nothing moves), and open on its side (two columns). Not checked: a real iPhone Duo, Split View, the accessibility text
sizes, VoiceOver.

## Consequences
- Folding an upright Duo no longer changes home's layout.
- Turning an open Duo still swaps panes for columns, as turning any device does.
- No stored data, content or text changes.
