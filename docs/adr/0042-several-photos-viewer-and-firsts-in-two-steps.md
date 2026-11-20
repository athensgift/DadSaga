# ADR-0042: Up to ten photos on every entry, a full-screen viewer, and firsts in two steps

**Status:** Proposed (2026-11-20). The owner approved the three changes and asked for the design; drafted by the
architect. Changes ADR-0016 and ADR-0022 (an entry keeps up to ten photos), ADR-0021 §3 (a first's undo shows in its
sheet), ADR-0026 §4 (the first new schema versions are for photos; the non-optional `childID` waits for sync),
ADR-0036 §1–§2 and ADR-0037 §2 (an entry's further photos in the film), ADR-0033 and ADR-0034 (the audit and the
snapshots cover the viewer and both steps of a first).

## Context
- An entry keeps one photo: `ProgressEvent.photoID: String?`, one column in `SchemaV1`, edited as keep, remove or
  replace (`PhotoChange`). A day worth keeping rarely fits in one picture.
- Photos show only as 56–64 pt squares (home's moment cards, the timeline, "last time" in a card's sheet) and whole in
  a sheet's photo field (`WholePhoto`). Nothing shows one large.
- The moment sheet puts the grid of firsts, a photo, the date and a note on one screen. The owner, using it, did not
  notice that a first can carry a photo or a note.
- Every sheet now opens at full height, so home's celebration and its "Saved · Undo" bar are hidden while one is open.
- `MigrationStage.custom`'s two closures are `@Sendable`; `willMigrate` sees the old schema and `didMigrate` the new
  one. A value read in the first can reach the second only through shared mutable state, and nothing documents that a
  failure between them leaves the store as it was. Core Data infers an optional attribute becoming non-optional only
  when it has a default value.
- SwiftUI has no pinch-to-zoom for a scroll view; `UIScrollView` has. The zoom transition (iOS 18) works with
  `fullScreenCover` and can be dragged, but developers report regressions with it on iOS 26 (the source view vanishing,
  flicker), and SwiftUI has nothing like UIKit's `interactiveDismissShouldBegin` to keep a zoomed-in photo from closing.
- ADR-0006: a photo or a note is never asked for, and nothing may nag about one that is missing.

## Decision

### 1. Up to ten photos on every entry, in the dad's order
- `ProgressEvent.photoIDs: [String]` replaces `photoID`; `ProgressEvent.photoLimit` is 10. `TimelineEntry`,
  `CapturedMoment` and `JournalEntry` follow. Ten is enough for a day and keeps the files modest (at most 2048 px,
  about 1 MB each, ADR-0016).
- **The first photo is the cover:** the one on every square thumbnail, on the widget, and behind a first's or a boss's
  card in the film.
- Recording takes `JournalInput(note:photos:)`. Editing takes the whole list as it should end up, `[EntryPhoto]`, each
  `.kept(id)` or `.added(Data)`; it replaces `PhotoChange`. One shape covers adding several, removing one and choosing
  the cover. More than ten, a kept id the entry doesn't have, or the same id kept twice, throws before anything is
  written.
- **Files** (ADR-0016, ADR-0021): new photos are written first, then the event. If a photo or the event can't be
  written, every photo written for it is deleted. Removed photos are deleted only once the event no longer points to
  them. Saving an entry deleted meanwhile throws, so its new photos are deleted too. Deleting an entry deletes all its
  photos. Starting over still empties the whole folder.
- `FilePhotoStore.thumbnail` returns the stored file itself when it is not larger than asked, so the viewer and the
  film never get a JPEG of a JPEG.

### 2. The stored shape changes in two versions, with nothing carried between closures
- `SchemaV1` never changes. `SchemaV2` (2.0.0) is version 1 plus `photoIDs: [String] = []` on `ProgressEventRecord`,
  and keeps `photoID`. `SchemaV3` (3.0.0) drops `photoID` and is `CurrentSchema`.
- V1 → V2 is `.lightweight`. V2 → V3 is `.custom`: its `willMigrate`, on version 2 where both columns exist, copies
  `photoID` into an empty `photoIDs` and saves; the schema change then drops `photoID`. The copy captures nothing and
  can run twice.
- Whatever fails, the store stays at version 1 or 2 with every photo id in it, and the next launch carries on
  (ADR-0026 §1). One V1 → V2 stage would have had to hand the ids from `willMigrate` to `didMigrate` through a shared
  static, and a failure between the two would lose them.
- **Not in these versions:** the non-optional `childID` (it would need a default value to be inferred), `#Unique` and
  indexes. They go with the sync ADR's version. This changes ADR-0026 §4, which put `childID` in "the first V2 that is
  needed anyway".
- **Tests:** a new fixture, `Tests/DataTests/Fixtures/StoreV1`, written by the version 1 build before the schema
  changes and never regenerated, holds entries with and without a photo. The app opens a copy read-write and finds each
  photo as a one-item list. The widget opens a copy read-only at version 3, throws, and leaves the database and its
  write-ahead log byte for byte as they were; once the app has migrated, the widget reads it. The `StoreBeforeV1`
  fixture migrates too. `SchemaV2Draft` is deleted and the widget tests use the real plan (ADR-0034 §6);
  `StoreVersions`, which let tests open the store at a version not yet shipped, goes with it.
- An older build cannot open a version 3 store; it shows the calm "couldn't open" screen (ADR-0026). Installing an
  older build over a newer one is not supported.

### 3. Picking and editing photos
- `JournalPhotosField` replaces `JournalPhotoField`. With no photo: "Add photos" and the camera. With photos: the
  cover whole (`WholePhoto`), under it a row of square thumbnails, the cover first and marked, then a "+" while there
  is room.
- **Library:** `photosPicker(isPresented:selection:maxSelectionCount:selectionBehavior:matching:)`, with the room
  left as `maxSelectionCount` and `.ordered`, so photos keep the order the dad tapped them in. **Camera:** one at a
  time.
- **Each thumbnail:** a tap opens it full screen; its menu, and the same accessibility actions, offer "Make cover"
  (moves it first) and "Remove". There is no drag to reorder: the only order the app uses is the cover, and the picker
  already numbers the rest.
- At ten the add buttons go, and one plain line says ten is the most an entry keeps.
- Picked photos stay as they came until Save. Previews decode them only as large as they are shown, off the main
  actor.

### 4. A photo, full screen
- Tapping a photo anywhere (home's moment cards, a timeline row, "last time" in a card's sheet, the field's cover and
  thumbnails) opens that entry's photos full screen on black, at the one tapped. Tapping the rest of a card or a row
  does what it does today. A thumbnail with more than one photo shows how many.
- Swipe sideways between the entry's photos, with "2 / 5" at the top. Pinch or double-tap to zoom (a `UIScrollView`
  in a representable, up to 4×). Swipe down to close, only when not zoomed in. A Close button always shows.
- Presented with `fullScreenCover`, without the zoom transition (see Context). Photos load through `GetPhotoUseCase`
  at up to 2048 px, the size the store keeps; only the shown page and its neighbours are decoded.
- **VoiceOver:** each photo is an image, "Photo 2 of 5, «entry»"; a three-finger swipe turns the page; the zoom
  action zooms; the escape gesture and Close close it. Cards and rows stay one element each, say how many photos they
  have, and gain a "Show photos" action.
- It has no view model: it shows what it is given and keeps only its page and zoom. A link from outside the app closes
  it, like the sheets (ADR-0023).

### 5. Firsts in two steps
- **Step 1:** the grid of firsts and "When did it happen?" (today by default), with one line: "Next, if you like:
  photos or a few words." ✓ records the first at once: XP, the celebration and "Saved · Undo".
- **The date stays in step 1.** It decides where the moment lands: its month in the timeline, its world and year in
  the film. Asked only in step 2, a first caught up from months ago and closed with "Not now" would be dated today,
  with nothing to say so.
- **Step 2, in the same sheet:** the moment's page: its title and reward, "Saved! Want to keep something more?",
  photos, a note, the date (still editable), Save and Not now. The celebration and the undo bar show in the sheet,
  since home is behind it; Undo deletes the moment and closes the sheet.
- **Closing never loses the moment.** While photos or words have been added and not saved, the sheet can't be swiped
  away, "Not now" is hidden, and Close asks before discarding them.
- Editing a first opens straight at step 2, with Save and Delete (ADR-0016) and no celebration.
- Recording a first takes only the first, the child and the date (`CaptureMomentRequest`); step 2 saves through
  `UpdateMomentUseCase`.
- Nothing asks later: no reminder, badge or count for a first without a photo or a note.

  | | el | en |
  |---|---|---|
  | Step 1 line | Μετά, αν θες, φωτογραφίες ή δυο λόγια. | Next, if you like: photos or a few words. |
  | Step 2 title | Αποθηκεύτηκε! Θες να κρατήσεις κάτι ακόμα; | Saved! Want to keep something more? |
  | Step 2 line | Φωτογραφίες ή δυο λόγια, τώρα ή όποτε θέλεις. | Photos or a few words, now or whenever you like. |
  | Buttons | Αποθήκευση · Όχι τώρα | Save · Not now |
  | Discard | Να φύγουν οι φωτογραφίες και οι σημειώσεις που πρόσθεσες; · Να φύγουν · Συνέχισε | Discard the photos and words you just added? · Discard · Keep editing |
  | At ten | Ως 10 φωτογραφίες σε κάθε καταχώριση. | Up to 10 photos on each entry. |
  | Viewer | Φωτογραφία 2 από 5 · Κλείσιμο · Δες τις φωτογραφίες | Photo 2 of 5 · Close · Show photos |
  | Thumbnail | Κάν' την εξώφυλλο · Αφαίρεση | Make cover · Remove |

### 6. The film
- A first's or a boss's card is drawn over its cover; a quest's cover is a photo alone, as before.
- **An entry's further photos follow its scene,** each alone and without words, in the dad's order: at most three per
  entry (`SagaPacing.morePhotosPerEntry`), each as long as a quest's photo (`SagaPacing.photo`, 2.5 s, renamed from
  `questPhoto`).
- **They are thinned first** (ADR-0036 §2): further photos, then quests, then bosses without a photo, then bosses with
  one, each evenly with the first and the last kept. Firsts' cards are still never dropped.
- `SagaScene.Kind` gains `.photo(TimelineEntry, id:)`; `SagaFilmCard.questPhoto` becomes `.photo`, for every photo
  shown alone (ADR-0037 §2).

### 7. Snapshots and the audit
They are paused while this is built and run once at the end:
- New images, in the three looks: step 1 and step 2 of a first (with three photos), the viewer, and the timeline with
  photos, from a fixture saga with generated photos. The existing images should not change; any that do are recorded
  again.
- The audit covers step 2 and the viewer. The system photo picker can't be driven reliably from a UI test, so a debug
  launch argument starts the app on a saga that already has photos (`DeviceData`, ADR-0033).

## Consequences
- Every entry can hold a real album, while every list, the widget and the film keep one picture per entry, the cover.
- Three schema versions exist, two of them only on the way to the third. The `StoreV1` fixture is three more small
  binary files.
- A film with many photos shows more of them without growing past 90 seconds; a dad who adds photos to one entry sees
  at most four of them in a film.
- Ten photos are written one after another when saved (a second or two on a phone); the button waits meanwhile.
- A first is recorded before its photos and note, so the timeline, the widget and the film may hold a first without
  them, as they could before.
- The viewer is the app's first `UIScrollView` and its second `UIViewRepresentable` (after the camera); both stay in
  Presentation's views.
- A crash between writing photos and writing their entry leaves files no entry points to, as one photo could before.
  Sweeping them is left for the export and backup work (ADR-0004).
