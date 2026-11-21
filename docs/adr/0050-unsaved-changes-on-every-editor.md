# ADR-0050: Unsaved changes are kept on every editor, a link waits for them, and the question never records

**Status:** Proposed (2026-11-21). The owner chose the dialog's buttons and its Greek wording; the rest follows the
reviewer's findings on the UI pull request. Changes ADR-0042 §5 ("Closing never loses the moment": which screens ask,
which buttons the question offers, its Greek "Keep editing") and ADR-0023 (when a link from outside opens).

## Context
- ADR-0042 §5 kept a first's step 2 and the timeline's note sheet from losing what the dad changed. The quest and boss
  sheets, which take a note and photos too, and "My family" lost them to one swipe.
- The first fix offered Save in the question on a quest or boss. Saving a quest is recording it, with its XP: a dad who
  wrote a few words before doing it would be credited for something he hadn't done yet. ADR-0006 gives XP only for the
  dad's own action.
- A link from the widget or a notification closed whatever sheet was open, and could do so while it saved. The save
  then finished against a sheet the link had opened, closing it or showing it an error it never made, and unsaved
  words were dropped without a question.

## Decision
1. **Every editor asks before losing changes:** a first's step 2, the timeline's note sheet (ADR-0042 §5), and now the
   quest and boss sheets and "My family". While something would be lost, a swipe can't close it and Close (or Back, on
   "My family") asks.
2. **The question never records.** On a quest or boss it offers only Discard and Keep editing; the sheet's own button
   ("I did it!", "We made it through!") is the one way to record. Where saving only keeps an edit (a moment, a note,
   the family), the question still offers Save.
3. **"Keep editing" is «Συνέχισε την επεξεργασία»** in Greek, on every editor: the one string reads right whether the
   dad was writing, picking photos or changing a date or a name. It replaces ADR-0042's «Συνέχισε».
4. **A link waits.** While something saves, or any editor below home holds unsaved changes (`UnsavedWork`, which each
   `UnsavedChangesGuard` reports to), the link stays pending; it opens once the dad saves, records or discards. So a
   save always finishes against the sheet it came from, and nothing is closed with unsaved changes in it.
5. **Undo speaks only through its bar.** A failed undo brings the bar back saying so; it never writes a sheet's error
   or closes a sheet.

## Consequences
- A tap on the widget while a note is half written opens nothing until the dad finishes or discards. That is the
  point: his words are worth more than the link.
- No counter of sheet changes is needed to tell which sheet a save belongs to: only one can be open while it saves.
- The timeline tab's editor is not below home, so a link does not wait for it; it is left as it was.
