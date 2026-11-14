# ADR-0012: Families of up to four children, with shared XP

**Status:** Accepted

## Context
The first version had exactly one child. Many dads have more than one, and the coming legendary moments (first steps,
first word) belong to a specific child, so the model had to change before them.

## Decision
- **1 to 4 children** per profile (`PlayerProfile.maxChildren`). Each `Child` has a stable `id`, name, birth date,
  gender (boy or girl) and skin tone. The dad has a skin tone too. Five tones, the same scale emoji use.
- **XP and level are the dad's**, from all children together. Per-child progress would invite comparisons between
  siblings, which goes against ADR-0006.
- **What happened with a child stays with that child.** Every `ProgressEvent` carries a `childID`. Quest completions,
  defeated bosses and captured firsts are counted per child: each child has their own first fever. XP for a boss or a
  first is earned once per child.
- **Home shows one child at a time.** A segmented picker chooses whose world and quests are shown. A child older than
  every world sees "coming soon" instead of quests meant for babies.
- **"My family"** (from home) adds, edits or removes children after onboarding. Removing a child never removes XP.
- **Migration.** Stores from before families are converted on first read (`LegacyProfileMigration`): the old child
  becomes a `ChildRecord` and every event without a child is linked to them. The legacy columns stay, so an older build
  can still open the store.

## Consequences
- Legendary moments, the timeline and the child avatars can all be per child from the start.
- More state on home (the selected child), and progress queries need a child.
- Gender has only two options, as decided by the product owner. Revisit if the audience asks for more.
