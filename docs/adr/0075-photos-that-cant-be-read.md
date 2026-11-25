# ADR-0075: A photo that can't be read stays out of the film's wordless scenes and out of a copy

**Status:** Proposed (2026-11-25). From the 2026-11-25 audit (its part C); drafted by the architect. Changes ADR-0037
§2 (a photo alone that can't be read is left out, not shown as black), ADR-0047 §1, §2, §4 and §8 (a film may lose a
scene; an unreadable photo is the last choice; the film's photos are checked as it is made), ADR-0047 §3 (faces in
the background are not classified) and ADR-0057 §2 and §6 (a copy carries only photos its import takes).

## Context
- A stored photo can be missing (a crash between steps, a photo sync hasn't fetched yet) or damaged (a file that isn't
  the JPEG the store wrote). Both are rare, and nothing the dad did.
- The copy lists photos by file name (`storedPhotos()`), so a damaged file goes into the copy, and the import then
  refuses the whole copy as damaged (ADR-0057 §3: a photo must be a JPEG whose header gives its size).
- In a film, a photo the loader can't read comes back black (ADR-0037 §2). Over a first's or a boss's card the words
  still show; a photo alone (a quest's, or a further photo) has no words, so its scene is 2.5 seconds of black. And
  `choosingPhotos(by:)` takes an unrated candidate as "Vision couldn't", so the entry keeps its photos by position and
  the unreadable one keeps its place.
- A film's scenes, their frames and the music are fixed before any photo loads; photos load one clip ahead. A scene
  can't be dropped once the film is being written.
- `PhotoSubject.framing` leaves out faces under a third of the tallest face's height, but every face is classified
  child or adult first, so background faces cost a classification each and change nothing.

## Decision
1. **What "can be read" means, once.** A photo can be read when its file is a JPEG whose header gives a size the store
   takes (at most 8192 px a side): the check `adopt` already makes. `PhotoStore.readablePhotos(among:)` answers it for
   many ids at once, reading each file's header only, never decoding it. A missing file can't be read.
2. **A copy carries only photos that can be read.** An entry whose photo can't be read goes in without that id, as one
   whose file is missing already does (ADR-0057 §2). The copy needs no other change; its format is the same.
3. **In a film, as it is made, before the script** (inside `ChooseSagaFilmPhotosUseCase`, which already runs then):
   - Only photos whose reading can change the film are checked: every photo shown alone (a quest's cover, each further
     photo) and every candidate of an entry with more further photos than places. A first's or a boss's cover is not:
     its words stay on the dark either way, as ADR-0037 §2 says.
   - A further photo that can't be read is never a candidate. Its place goes to the entry's next readable further
     photo in the dad's order, or, by rating, to the best of them (ADR-0047 §2). "No rating" still means Vision
     couldn't, and keeps the dad's order; it no longer stands for a file that can't be read.
   - With no readable photo left for it, the place is left out of the film. A quest whose cover can't be read loses
     its own scene; its further photos stay. A chapter card left with nothing after it goes, and the chapters are
     counted again (one world left: none).
   - Every scene kept keeps its length. The film is shorter by the scenes left out, so still within 90 seconds, and
     nothing thinned earlier comes back: the film no longer holds the entries its cut left out, and none of their
     photos was checked.
   - When the store can't answer, the film is made as before. No word on the sheet or in the film says a photo was
     left out (ADR-0047 §7).
   - The loader's black stays as the last resort: a first's or a boss's cover, and a file whose header was whole but
     whose pixels still don't decode.
4. **Only the faces that can be the subject are classified.** The rule for the background is one Domain function,
   used by the subject rule and by the analyzer; a face in the background comes back with no age group. A photo with
   one face still has it classified (ADR-0047 §3).

## Consequences
- A copy with a damaged photo opens, without that photo, instead of being refused whole.
- A film never shows seconds of black for a photo alone whose file is missing or damaged, and an entry's damaged
  photo never takes the place of a good one.
- Every film reads a few dozen file headers before it starts (estimated: milliseconds each, not measured). A film where
  every further photo fits now reads headers, but still rates no photo.
- A film can have fewer scenes than the sheet's storyboard: ADR-0047 §1's "how many scenes" holds for Vision only.
- Fewer faces are told child or adult: less is guessed about people in the background (ADR-0047 §7).
- No stored schema, copy format, content, privacy manifest or UI text changes.
