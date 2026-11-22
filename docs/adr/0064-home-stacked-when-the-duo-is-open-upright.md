# ADR-0064: Home above and below the hinge again when the iPhone Duo is open flat and upright

**Status:** Accepted (2026-11-22). The owner opened the Duo flat and upright after ADR-0061 and found home in two
columns again; ADR-0045 had settled, at the owner's request, that open and upright it shows "the avatar above, the rest
below". Supersedes ADR-0061 §1 where it makes the Duo open flat and upright two columns. Restores ADR-0045 and
ADR-0056 §2 for home.

## Context
- ADR-0061 §1 took out the flat fold (`whileFlat`, `.includeInactive`) so that home would not split "at a hinge the dad
  can't feel", and made the Duo open flat and upright two columns of 334 pt each, the owner choosing the columns. Having
  tried them, the owner reverses that choice and wants ADR-0045's rows back.
- Open flat, `reservedRegions(kind: .division, options: .includeInactive)` reports the fold as a band 40 pt high in the
  iPhone Duo simulator (iOS 27.2); ADR-0056 §2 reads it as the line down the band's middle.

## Decision
- **Open flat and upright, home is the hero's pane above the hinge's line and the adventure below it**, each scrolling
  on its own: the same two panes as half-open, so folding only opens the hinge's gap between them.
- `HorizontalFold.divisions(active:all:whileFlat:)` and the reader's `whileFlat` come back as in ADR-0056 §2. Home reads
  the fold twice: the active one and, `whileFlat`, the line. `HomeArrangement.make(width:fold:flatFold:)`: an active
  fold wins; the line splits home only where it would otherwise be two columns (600 pt and wider).
- On its side the Duo keeps two columns (the fold runs down between them), and a large iPhone in landscape too.
- Only home reads the flat fold. The map, Settings, "Your hero", "My family", the sheets, the film and the timeline split
  only while half-open (ADR-0043, ADR-0061 §4).
- Folding moves the upper pane's end from the line to the gap's top (about 20 pt), so the hero, who fills that pane
  (ADR-0056 §3), shrinks a little as it folds; the panes themselves stay.
- Everything else in ADR-0061 stays: the four tabs, no navigation bar on two panes, the open worlds.

## Rejected
- **One scrolling column open and upright**: folding would rebuild home into two panes and lose where it was scrolled.
- **Splitting at half the height** instead of at the reported fold: a few points off, so home would jump when it folds.

## Verification status
`FoldLayoutTests` (the flat fold as a line, the active fold's gap, the fold down the view on its side) and
`HomeArrangementTests` (stacked open flat upright, folding keeps the rows, a narrow window stays one column). Drawn in
the iPhone Duo simulator (iOS 27.2): open flat upright, half-open, on its side. Not checked: a real iPhone Duo.
