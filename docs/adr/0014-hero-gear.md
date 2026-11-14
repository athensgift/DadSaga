# ADR-0014: The hero earns gear from skills and bosses

**Status:** Accepted

## Context
The product owner wanted the dad's avatar to change with what he does. ADR-0006 rules out anything that can be lost.

## Decision
- **Gear is content** (`gear.json`): each item has a skill, an XP threshold and a `look` the avatar knows how to draw.
  Two tiers per skill: 50 and 200 skill XP.
- **Automatic for now.** For each skill the best earned item is shown (`GearRules.equipped`). A wardrobe where the dad
  picks what to wear comes later; the rules already return every earned item's best tier.
- **One slot per skill**, chosen so it never clashes with an archetype's own gear: care on the left shoulder (burp
  cloth), patience in the left hand (coffee mug, thermos), play on the ground (rubber duck, blocks), resilience on the
  back (changing bag).
- **Boss medals:** one medal on the chest per boss defeated with any child, up to four drawn.
- **Celebration:** when a quest or boss crosses a threshold, the celebration adds "New: <item>".
- XP never decreases, so gear is never taken away.

## Consequences
- The hero visibly reflects what kind of dad the player is.
- Each new look needs drawing code in `HeroItems.swift`; an unknown `look` in content is ignored rather than crashing.
- Temporary daily states (tired after a night shift) were left out on purpose, to keep this change small.
