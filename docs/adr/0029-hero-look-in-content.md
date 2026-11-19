# ADR-0029: A hero class names its look in the content

**Status:** Accepted (2026-11-19). Changes how ADR-0008 and ADR-0010 map a class to its drawing.

## Context
`Presentation` turned a hero class id into a look with a hard-coded switch (`"h-cool"` → `.cool`, …). Game content is
data ([ADR-0005](0005-content-as-data.md)), but this part of it lived in Swift: renaming an id or adding a class meant
editing code, and nothing in the content said how a class is drawn. Gear already worked the other way: `gear.json`
names a `look` and `Presentation` maps the name to a drawing.

## Decision
- `heroes.json` gives every class a `look` (`hero`, `cool`, `strong`, `smart`, `chef`, `fixer`), carried as
  `HeroClass.look: String` in the Domain, like `GearItem.look`.
- `Presentation` builds `HeroLook` from that name. An unknown name, or a stored class id the content no longer has,
  draws Super Dad, as before.
- `HeroLook` (the display model) and `HeroAvatar.Style` (the drawing) stay two types, mapped in `HeroLook+Avatar.swift`.
  This is the same split as skin tone, gender and gear: ViewModels never see `HeroArt`, and `HeroArt` never sees the
  Domain.
- The hero colour tokens are named by colour (`heroPurple`, `heroGreen`, `heroNavyShade`, …), not by the fantasy classes
  of ADR-0008.

## Consequences
- Class ids can change in the content without touching Swift. A new look still needs a `HeroLook` case, a
  `HeroAvatar.Style` case and its drawing.
- A test checks that each bundled hero has its own look, so a typo in `heroes.json` fails the package tests instead of
  quietly drawing Super Dad.
