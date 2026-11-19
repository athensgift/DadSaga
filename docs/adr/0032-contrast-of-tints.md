# ADR-0032: Tints readable as text and as fills; the hero keeps its own colours

**Status:** Accepted (2026-11-19). The owner asked for the contrast fix after the Dynamic Type pass; the exact shades
are this ADR's proposal, checked in the simulator in light and dark. Narrows the tint values of ADR-0011.

## Context
- The four tints (`accent`, `xp`, `legendary`, `boss`) are used in three ways:
  - as small text (badges, hints, "+30 XP"), also on their own 15% wash (the reward pill);
  - as fills (icon tiles, step numbers, world-map markers, the timeline rail, prominent buttons, the toolbar ✓) with
    a white symbol or label on them;
  - inside `HeroArt`, to paint the hero (gold buttons, orange capes, blue shields).
- Measured against WCAG 2.2 AA (4.5:1 for small text):
  - light mode: `legendary` text was 2.2–2.5:1 and `xp` 3.0–3.4:1 on the background and surface;
  - dark mode: white on the tints was 1.7–2.9:1, including the "I did it!" button and the toolbar ✓.
- Darkening a tint to fix text would have repainted the hero, since `HeroArt` shared the same tokens, and with it the
  launch image (ADR-0025).

## Decision
1. **One rule for every tint:** in each mode it reaches 4.5:1 as text on the background and the surface, on its own
   15% wash over either, and under `onTint`. `DSTint` holds the values as numbers, and `DSTintContrastTests` checks
   the rule for every tint, so a new or changed tint that fails it fails the build.
2. **New values:** light `accent` `#3755CD`, `xp` `#046C4E`, `legendary` `#875700`, `boss` `#AD3709`; dark
   `accent` `#6F90F5`. The other dark-mode values already pass and stay.
3. **The accent is also the app's tint,** and iOS draws its own white symbols on it, e.g. the toolbar ✓, whatever
   foreground style is set. So the accent also gives white symbols 3:1 (WCAG's minimum for graphics) in both modes.
4. **`DSColor.onTint`** for symbols and text on a tint fill: white in light mode, ink (`#1D1B26`) in dark mode, where
   the tints are bright. Our own buttons on a tint (`PrimaryButton`, the reminder offer's accept button) use
   `onTintLabel()`: `onTint` while enabled, the system's dimmed label when disabled.
5. **The hero has its own palette:** `heroGold`, `heroOrange` and `heroBlue` keep the old tint values, and `HeroArt`
   uses them instead of the tints. The hero, the wardrobe and the launch image look exactly as before.

## Consequences
- Light mode's tints are a little deeper; gold reads as amber. Dark mode's tiles and prominent buttons have dark
  symbols and labels, like iOS's own yellow and orange badges.
- Interface colours and the hero's colours can change independently.
- The ratios are for flat colours; fills use the tint's `.gradient`, whose lighter top lowers white-on-tint slightly
  in light mode. The margins (above 6:1) cover it. Liquid Glass buttons draw the tint through a material that lightens
  it a little, so the toolbar ✓ in dark mode sits near its 3:1 floor rather than above it.
- Not covered yet:
  - the companion line on home and the hero picker's checkmark draw text in the hero's own colour
    (`HeroAvatar.Style.tint`), which fails in light mode for some heroes;
  - the website's CSS still uses the old tints.
