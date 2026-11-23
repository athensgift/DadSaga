# ADR-0066: Home in one column whenever the display lies flat

**Status:** Accepted (2026-11-23), at the owner's request: on the iPhone Duo fully open (not half-open) and on a tablet,
the avatar and the cards scroll up together, so the cards no longer fill only half the screen. Supersedes ADR-0064 and
ADR-0061 §1 where they split home on a flat display, and ADR-0045 again; ADR-0056 §2 (the flat fold as a line) goes
again. Changes ADR-0011 and ADR-0043 for home: it splits only while the Duo is half-open.

## Context
- ADR-0064 made the Duo open flat and upright the hero's pane above the hinge's line and the adventure below it, each
  scrolling on its own; ADR-0061 §1 made every window 600 pt and wider two columns (the Duo open flat on its side, iPads,
  large iPhones in landscape). Either way the cards had half the screen, beside or below a hero who never scrolls away.
- ADR-0064 rejected one scrolling column because folding would rebuild home and lose where it was scrolled. The owner
  prefers the column and accepts that.

## Decision
- **Home splits into panes only around a fold the dad can feel**, while the iPhone Duo is half-open:
  - held upright like a laptop, the hero above the fold and the adventure below it (ADR-0043, unchanged);
  - on its side like a book, two columns beside the fold, from 600 pt wide (as before).
- **Everywhere else home is one column**, the hero first and the adventure under him, scrolling together, with the
  navigation bar and its large title: the Duo open flat (upright or on its side), iPads, every iPhone (landscape too),
  the Duo's cover display. The column is no wider than `readableWidth`, centred.
- Home reads the active folds only: across it (`onHorizontalFoldChange`) and down it (`onVerticalFoldChange`,
  `VerticalFold.runsDown`). `whileFlat` and `HorizontalFold.divisions(active:all:whileFlat:)` go; nothing reads a flat
  fold any more.
- Folding or opening the Duo swaps the column for the panes and back; the column starts again from its top.

## Rejected
- **Keeping two columns on a large iPhone in landscape**: telling it from the Duo open flat on its side would take the
  device's kind or a height threshold; one rule (panes only at a fold) is simpler, and the owner wants the column on
  wide flat displays.

## Verification status
`HomeArrangementTests` (one column open flat, on an iPad and on a phone; two columns half-open on its side from 600 pt;
rows half-open upright, one column again once flat) and `FoldLayoutTests` (a fold down the view). Drawn in the
simulator: the iPhone Duo open flat and half-open, an iPad. Not checked: a real iPhone Duo.
