# ADR-0018: Wardrobe: choose what the hero wears per slot

**Status:** Accepted. Extends ADR-0014.

## Context
Gear was automatic: the best earned item per skill. The product owner asked for a wardrobe once that worked.

## Decision
- **One choice per slot (skill):** automatic (the default; the best earned, and it upgrades by itself), nothing, or a
  specific earned item. Stored as `Outfit` with only non-automatic slots saved (`OutfitRecord`, one row per slot).
- **`GearRules.equipped(_:skillXP:outfit:)`** applies the choices; a chosen item that is no longer earned (content
  changed) falls back to automatic, so the hero is never left wearing something he does not have.
- **Celebrations follow earning, not wearing:** "New: <item>" shows when an item is earned, even if the dad has chosen
  to wear something else in that slot (`GearRules.newlyEarned`).
- **Wardrobe screen** (sheet from home): live hero preview on top, then per skill its XP and the options. Locked items
  are shown with the XP they need, so the wardrobe also shows what is coming. Choices save immediately.
- Boss medals are not a wardrobe choice; they are always shown.

## Consequences
- The dad can tidy the hero, or keep a favourite item.
- Developer reset clears the outfit too.
