# ADR-0008: Hero classes, a code-drawn avatar, and the profile in SwiftData

**Status:** Accepted

## Context
The dad is the hero of the game, so he needs a visible, animated character on the home screen. Onboarding has to
capture who the child is and which hero the dad plays, and that has to survive app restarts.

## Decision
- **Hero classes are content.** `heroes.json` (el/en) is loaded into `ContentCatalog.heroClasses` like all other content
  ([ADR-0005](0005-content-as-data.md)). The first three are Knight, Mage and Ranger.
- **A class is identity only.** It has a name, a tagline and a look. It gives no stats, bonuses or exclusive content, so
  no choice is "wrong" ([ADR-0006](0006-no-pressure-game-design.md)).
- **The avatar is drawn in SwiftUI** (`HeroAvatar` in `DesignSystem`), not shipped as image assets. It idles from a
  time-driven pose (bob, breathing, blinking, swaying gear), cheers when tapped, and stands still under Reduce Motion.
  `DesignSystem` knows only a visual `Style`; `Presentation` maps a class id to it (`HeroLook`), and unknown ids fall
  back to the knight.
- **The profile is persisted with SwiftData** behind `ProfileRepository`. The `@Model` type (`ProfileRecord`) stays in
  `Data`; Domain's `PlayerProfile` is a plain value. `ProfileRules` validates a profile before it is stored.
- If the on-disk store cannot be opened, the app falls back to a session-only repository instead of crashing.

## Consequences
- No art pipeline, and the avatar scales to any size and adapts to light/dark through tokens.
- The look is deliberately simple. Richer art (Rive, sprite sheets) would replace `HeroAvatar` without touching other layers.
- Adding a class needs a JSON entry plus a `Style` case and drawing code; without the drawing it shows as the knight.
- The session-only fallback means a profile could be lost after a store failure. This is silent today and needs a
  user-facing message before release.
