# ADR-0021: Undo and delete the dad's own entries

**Status:** Accepted (2026-11-16)

## Context
A wrong tap on "I did it" recorded a quest or a boss for good. Only legendary moments could be deleted (ADR-0016). The
owner asked for an undo right after completing, and for deleting any entry from the timeline. ADR-0006 says "nothing
is ever lost", which was written against the game taking things away (decay, penalties, streaks), not against the dad
correcting his own log.

## Decision
1. **One use case for every kind of entry.** `DeleteEventUseCase` removes a quest, boss or moment event, and its photo
   if it has one. It replaces `DeleteMomentUseCase`.
2. **Everything follows from the events.** XP, level, gear and boss badges are computed from the log, so deleting an
   event takes back exactly what it gave: a level can drop and gear can lock again. Nothing extra is stored or reverted.
3. **Undo after recording.** Completing a quest, defeating a boss or capturing a moment shows "Saved · Undo" for 6
   seconds (15 with VoiceOver). `ProgressChange` carries the recorded `eventID` for this; it is `nil` when nothing was
   recorded (a boss already defeated).
4. **Delete from the timeline** through the row's context menu (and an accessibility action), always behind a
   confirmation. A moment with a photo or a note says plainly that they are deleted too, for good.
5. ADR-0006 rule 2 now reads as: the **game** never takes anything away; the dad may remove his own entries.

## Consequences
- Deleting is permanent; there is no trash. The confirmation is the safety net.
- The undo offer lives only in memory; leaving the screen or a newer completion replaces it.
