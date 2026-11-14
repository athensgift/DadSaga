# ADR-0015: Legendary moments are progress events with a date and a note

**Status:** Accepted

## Context
Legendary moments (first smile, first steps…) were content since Phase 1 but could not be captured. They belong to a
child (ADR-0012), happen on a real date that may be before the dad installed the app, and are worth keeping in his own
words.

## Decision
- A captured moment is a `ProgressEvent` of kind `.first`, with the child, the date it happened and an optional note.
  One store and one write, so XP and the moment can never disagree.
- **Once per child**, 30 XP each (content). The date can be any day from the child's birth to today.
- `DadProgress.moments(for:)` lists them newest first. Home shows them as gold cards with "captured / total".
- **Companion traits:** some firsts change how the child is drawn — a smile or first tooth replaces the dummy, a baby
  who has walked stands, a party hat from the first birthday. Traits with no drawing (e.g. crawling) are ignored.
- **Photos are not in this change.** They come next and will be stored on the device (ADR-0004).

## Consequences
- Older siblings can catch up on firsts from before the app.
- Moments cannot be edited or deleted yet; that comes with photos and the timeline.
