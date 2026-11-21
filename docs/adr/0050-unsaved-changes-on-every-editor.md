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
   "My family") asks. The question is an alert, so every answer is a button the dad can see: on an iPhone a
   confirmation dialog shows as a popover whose cancel button isn't drawn, and "keep editing" was only a tap outside.
2. **The question never records.** On a quest or boss it offers only Discard and Keep editing; the sheet's own button
   ("I did it!", "We made it through!") is the one way to record. Where saving only keeps an edit (a moment, a note,
   the family), the question still offers Save.
3. **"Keep editing" is «Συνέχισε την επεξεργασία»** in Greek, on every editor: the one string reads right whether the
   dad was writing, picking photos or changing a date or a name. It replaces ADR-0042's «Συνέχισε».
4. **A link waits.** While something saves, or any editor on either tab holds unsaved changes, the link stays pending;
   it opens once the dad saves, records or discards. So a save always finishes against the sheet it came from, and
   nothing is closed with unsaved changes in it.
   - One `UnsavedWork` for the app, owned by the root screen. Each `UnsavedChangesGuard` reports to it for as long as
     its editor exists, not until the editor's `onDisappear`: the camera and the photo viewer cover an editor full
     screen, and SwiftUI calls `onDisappear` on it then, although its words are still there.
   - Home's view model does the waiting (`HomeViewModel.receive`), so it is tested: it opens the link once, after its
     own load, and only if the screen still shows the link's child. A newer link cancels the older one's wait; only a
     link that opened is reported handled, and the root clears only that one.
   - Coming back to the app reloads home also while a link waits: the link checks the child after its own load.
5. **Undo speaks only through its bar.** A failed undo brings the bar back saying so; it never writes a sheet's error
   or closes a sheet.

## Consequences
- A tap on the widget while a note is half written opens nothing until the dad finishes or discards. That is the
  point: his words are worth more than the link.
- No counter of sheet changes is needed to tell which sheet a save belongs to: only one can be open while it saves.
- A waiting link is silent: nothing says the open editor is holding it, and it opens the moment the editor closes. The
  timeline tab's editor holds a link too, although the link switches to the Adventure tab: the dad sees home, and the
  link opens once he goes back and finishes or discards his note.
