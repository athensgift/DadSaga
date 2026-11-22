# ADR-0058: Side by side, home's map and Settings go where the system puts a bar's buttons

**Status:** Accepted (2026-11-22). The owner saw home on the iPhone Duo open on its side: the map and Settings floated
over the adventure's last cards, beside the system's side bar instead of in it. Changes ADR-0056 §1 (the capsule is
now only for the layout above and below a fold), ADR-0011 and ADR-0043 §3 (side by side, home has a navigation bar
again), ADR-0043 §1 (home reads the fold around its navigation stack) and ADR-0030 §1 and ADR-0044 §8 (side by side,
the map and Settings are in home's navigation bar).

## Context
- Open on its side (951 × 669 pt), the Duo draws the tab bar as a bar at the trailing side, as on the closed cover
  display. ADR-0056 assumed the tab bar stays at the bottom on a display of regular height; it does only upright.
- Home's own capsule sits at the bottom trailing corner of the adventure's pane, inside the safe area: beside the side
  bar and over the cards, not in the side bar's column.
- With a navigation bar, the system puts the bar's buttons in a pill of their own at the top of the side bar's column,
  in the same glass and width as the tabs. On other iPhones on their side, where the tab bar stays at the bottom, it
  puts them at the top trailing corner, as every app has them.
- `tabBarPlacement` reports `bottomBar` in both cases, and no API says the tab bar is at the side. The trailing safe
  area (84 pt by the Duo's side bar, 62 pt by the Dynamic Island) can't tell them apart either.
- Side by side the panes meet with no fold between them, so a bar can't move a fold's place (ADR-0043 §3). Inline and
  with no title, it doesn't collapse as a pane scrolls.
- UIKit sets scrolling content against a navigation bar when its screen appears or the bar is shown, not when a
  visible bar changes. Measured in the simulators (iOS 27.2):
  - an inline bar that turns large on a screen that stays keeps its title collapsed: back in portrait the column sat
    at the inline bar's top (116 pt, not 168 pt) until it was pulled down;
  - turned on its side, the Duo first gives home its new size with the old safe area (82 pt at the top). The pane from
    below the fold, reused at the top, ended 58 pt past its top (82 pt with `develop`'s hidden bar);
  - with no title mode named, the large title collapses as soon as the loaded home replaces the spinner. `develop`
    starts that way.
- Before ADR-0045 folding swapped columns for rows, so both used the same two scroll views. Since then only turning the
  device goes from one to the other.

## Decision
1. **Side by side, home keeps the navigation bar, inline and with no title,** and the system places the map and
   Settings: in the side bar's column on the Duo, at the top on other iPhones. The hero's pane keeps the title.
2. **Above and below a fold, nothing changes** (ADR-0056): no bar, and the capsule floats just above the tab bar, which
   is at the bottom there. The adventure keeps room for it only then.
3. **In one column, nothing changes:** the navigation bar with its large title.
4. `HomeArrangement.buttons` says which of the three, so the rule is tested without drawing.
5. **Each of the three is a navigation stack of its own,** so a bar is never changed under a screen that stays: turning
   the device builds home anew, with every pane at its top, as it is when the app starts. Folding and unfolding stay
   above and below a fold, so they keep the stack, where each pane was scrolled to and a celebration in flight
   (ADR-0043 §2).
6. **Home reads its width and the fold around the stack, not inside it** (changes ADR-0043 §1 for home): a stack built
   for what was read must not start the reading again. Home fills the stack while it has no bar, which is whenever a
   fold splits it, so the fold is still in the panes' coordinates.
7. The bar's title mode is always named: large in one column, inline side by side.

## Rejected
- **Moving home's capsule into the side bar's column:** it would guess the column's width and the tab pill's height,
  which the system may change, and it can't tell the side bar from the Dynamic Island.
- **The capsule above the tab bar on iPhones on their side:** it needs a signal of where the tab bar is, which iOS 27
  doesn't give; the top trailing corner is where iOS puts these buttons there.
- **One stack, and scrolling each pane back to its top after a change:** tried, and the title stayed collapsed. It
  would also leave the cause: a bar changed under a screen that stays.
- **A large title mode throughout, with an empty title side by side:** it keeps the title on other iPhones, whose bar
  is short on its side. In a tall window side by side (the Duo upright before iOS 27.1) it leaves an empty band 52 pt
  high that collapses as a pane scrolls.
- **A new identity for the panes inside one stack:** tried; the bar is still the same bar, and the title stayed
  collapsed.

## Consequences
- On the Duo on its side the map and Settings are in the side bar's column, above the tabs, as on the cover display;
  they no longer cover the cards.
- On other iPhones on their side they move from above the tab bar to the top trailing corner; the panes start a bar
  lower.
- Turning the device puts every pane at its top; it did already between one column and two panes. A sheet open over
  home stays open. The undo bar's time starts again.
- Turned upright from its side, the Duo passes through one column for a frame (669 pt less the side bar's 84 pt is
  under 600 pt), as before: now a stack is built for that frame too.
- After the Duo is turned on its side the adventure can rest a point or two past its top (0.3 to 2 pt measured): UIKit
  rounds each step as the safe area animates, and only a pane too short to scroll is set back exactly.
- Home opens with its large title; on `develop` it opened collapsed.
- No stored data, content or text changes. Domain, Application, Data and the composition root are untouched.
- `HomeArrangementTests` covers where the buttons go, that folding keeps the place and that turning changes it.

## Verification status
Drawn in the simulators (iOS 27.2): the iPhone Duo open on its side, before and after scrolling the adventure, and the
iPhone 17 on its side. Turned without touching, with the scroll views' offsets read in the debugger: the iPhone 17
upright, on its side and upright again (large title back, also with a boss sheet open across the turn); the Duo upright,
on its side (map and Settings in the side bar's column, the adventure at its top) and upright again; the Duo folded to
100° and opened flat with the adventure scrolled (same scroll views, same place). Not checked: a real iPhone Duo, the
Duo half-open like a book, VoiceOver, a celebration in flight while folding.
