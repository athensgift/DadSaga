# ADR-0056: Home's map and Settings by the tab bar in the two-pane layouts, and a flat fold read as a line

**Status:** Accepted (2026-11-22). The owner tried home on the iPhone Duo after ADR-0053 and asked for the map and
Settings to sit open where they sit closed, by the tab bar, and for the empty block under the hero to go. Changes
ADR-0030 §1 (Settings is not in the wide layout's header), ADR-0043 §3 (the stage no longer holds the buttons),
ADR-0044 §8 (in the wide layouts the map and Settings are not in the pane's header) and ADR-0045 (its Context: the
system reports a flat fold with the hinge's thickness).

## Context
- Closed, the Duo's cover display is 678 × 466 pt, short and wide. There iOS 27 draws the tab bar as a bar at the side
  and puts the navigation bar's buttons, the map and Settings, in a pill of their own just above it.
- Open (669 × 951 pt upright, or on its side) home has two panes (ADR-0043, ADR-0045) and no navigation bar, so the map
  and Settings were glass buttons at the top of the hero's pane, far from the tab bar and the dad's thumbs.
- iOS 27 has no way to ask for the side bar on a display of regular height: the tab bar stays at the bottom there.
- Open flat, `reservedRegions(kind: .division, options: .includeInactive)` reports the fold as a band 40 pt high in
  the iPhone Duo simulator (iOS 27.2), not as a line. ADR-0045 assumed a line, so home kept that band empty between its
  panes while flat as well.
- Above the fold the hero was sized for a header 180 pt tall, a guess. The header and the padding take less, so the
  rest of the upper pane stayed empty. With the band, that made a block of 130–190 pt between the hero and the
  adventure. It was there before ADR-0053; a child on the way only made it easy to see.

## Decision
1. **In the two-pane layouts the map and Settings are one glass capsule at the trailing edge, just above the tab bar,**
   over the adventure's pane, which keeps room under its last card for them. The hero's pane is headed by the title
   alone. One column keeps them in the navigation bar, where the cover display's side bar shows them.
2. **A flat fold is the line down its middle.** The reader takes the active folds while the device is half-open; while
   it lies flat, and only where a screen asks (`whileFlat`), it takes each fold as the line down the middle of the band
   the system reports. Half-open, the band stays empty, as in ADR-0043. Folding narrows each pane by half the band.
3. **The hero fills what the title leaves above the fold:** his height is the pane's height less the title as drawn
   (measured), the padding and the space above the stage, between 120 and 260 pt as before. At the accessibility text
   sizes, where he stands above his level, he is no taller than in one column (210 pt) and the pane scrolls.
4. **The map and Settings are one capsule, map first,** read first by VoiceOver, as when they stood by the title. The
   adventure's bottom margin is their measured height.

## Rejected
- **A side bar drawn by the app when open:** a second tab bar beside the system's, which iOS would still draw at the
  bottom.
- **The navigation bar back on the two-pane layouts:** it collapses with whichever pane scrolls and moves the fold's
  place (ADR-0043 §3), and it would put the buttons at the top again.
- **Centring the hero's pane on the fold:** it would hide the empty space without filling it.

## Consequences
- On the open Duo the map and Settings are in reach where the dad's thumbs are, open and closed alike. They float over
  the adventure's lower right corner; its last card scrolls clear of them.
- Open flat, home's panes meet at the hinge's middle; the hero is larger and reaches the fold.
- No stored data, content or text changes. Domain, Application, Data and the composition root are untouched.
- `FoldLayoutTests` covers the flat fold; `HomeArrangementTests` the hero's size.

## Verification status
Drawn in the iPhone Duo simulator (iOS 27.2): home closed, half-open and open upright. Not checked: a real iPhone Duo,
Split View, the accessibility text sizes, VoiceOver.
