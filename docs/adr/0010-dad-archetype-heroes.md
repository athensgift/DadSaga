# ADR-0010: Heroes are dad archetypes, not fantasy classes

**Status:** Accepted. Supersedes the class list in [ADR-0008](0008-hero-classes-and-code-drawn-avatar.md).

## Context
The first hero classes were Knight, Mage and Ranger. They looked like any fantasy game and said nothing about fatherhood,
which is the whole point of the app.

## Decision
- The hero classes are **kinds of dad**: Super Dad, Cool Dad, Strong Dad, Smart Dad, Chef Dad and Fix-it Dad.
- Everything else in ADR-0008 stands: classes are content (`heroes.json`), identity only, and drawn in SwiftUI.
- Super Dad's chest crest is an **original design** (a gold shield with "Μ" for «Μπαμπάς»), with its own colours. It must
  not imitate any existing superhero's logo, costume or colour scheme.
- Class ids changed (`h-super`, `h-cool`, `h-strong`, `h-smart`, `h-chef`, `h-fixer`). A stored profile with an old id
  still loads and is drawn as Super Dad, because unknown ids fall back to the default look.

## Consequences
- The avatar now reflects the product's theme, and each dad has a small signature animation (hovering, lifting a
  dumbbell, a glowing idea).
- Six drawn avatars are more code to maintain than three.
- No migration was written for old class ids. That is acceptable before the first release; after it, renaming an id
  needs a migration or an alias.
