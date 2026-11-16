# ADR-0022: A note and a photo on every card

**Status:** Accepted (2026-11-16)

## Context
The owner wants the app to also work as a diary of his own moments. Until now only legendary moments (firsts) could
carry a note and a photo (ADR-0016). Quests and bosses were a tap and nothing else.

## Decision
1. **Every entry can carry a note and a photo.** `ProgressEvent` already had both fields; quests and bosses now fill
   them. Both stay optional and are never asked for: the quest and boss sheets show a folded "Note or photo
   (optional)" button that opens the fields only when tapped.
2. **Recording takes a `JournalInput`.** `CompleteQuestUseCase` and `DefeatBossUseCase` take it and store the photo
   through `PhotoStore` before the event; if the event can't be stored the photo is removed again (`EventRecorder`).
3. **"Last time you wrote…".** `DadProgress.lastJournal(for:childID:)` keeps the newest note or photo per card and
   child. The sheet shows it right under the card's description, so the dad sees it without scrolling.
4. **Editable later.** Tapping a timeline row opens its note and photo; `UpdateJournalUseCase` changes them for any
   kind of entry without touching its date or XP. A moment's date is still edited from home (ADR-0016).
5. Boss entries in the timeline keep their size; their note follows the badge in the subtitle.

## Consequences
- The shared photo picker (`JournalPhotoField`, with the camera) now serves moments and cards alike.
- Photos stay on the device, as before (ADR-0004).
