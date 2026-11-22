# ADR-0057: A copy of the saga: one file the dad saves anywhere, and a restore that replaces the whole saga

**Status:** Accepted (2026-11-22). The owner chose, on 2026-11-22: Apple Archive, no password, what travels as in §2,
restore on onboarding's first step, "Open with DadSaga" in v1.x, its own Settings section, the file name with no names
in it, no free-space check, the copy's size shown when it is ready, and plain names for the feature: "Export data" and
"Import data" (§8). Drafted by the architect from the owner's direction in an earlier review (one file,
saved or shared through the share sheet; a file picker to restore; the whole saga replaced, never merged; a clear
confirmation; nothing nags; never behind a paywall; photos as stored). The owner decided on 2026-11-22 that it ships in
v1 whatever the iCloud Backup restore test shows: it is a v1 requirement and gates the first App Store release. The
plan is [`docs/plans/saga-export.md`](../plans/saga-export.md). Changes ADR-0004 (the export it asked for: a copy the
dad makes is how his data leaves the device), ADR-0016 (photos leave the device only in that copy), ADR-0026 (export
and backup decided; a restore replaces every row in one save; `SagaEraser` becomes part of `WholeSagaRepository`),
ADR-0030 (§1 a "Your data" section; §7 the About statement; §8 start over through `WholeSagaRepository`), ADR-0037 §5
(a restore brings the copy's answers to the film offers) and ADR-0055 §3 (restoring an older copy brings back that
copy's title: the dad's own choice, like start over).

## Context
- **Everything is on one iPhone** (ADR-0004). The store (`DadSaga.store`, schema V7) and the photos (`MomentPhotos/<UUID>.jpg`)
  live in the App Group container (`SharedContainer`, `FilePhotoStore`), which the widget reads. Photos taken with the
  app's camera exist nowhere else. ADR-0004: "Losing the phone without a backup means losing data, so an export feature
  is needed." ADR-0026 and ADR-0048 deferred it.
- **Whether iCloud Backup brings App Group data back** is being tested on a device. It no longer decides when this
  ships (owner, 2026-11-22); it decides what the support and privacy pages say about backups.
- **What the saga is today.** In the store: the profile row (hero, skin tone, look, partner answer, and since V7 the
  title held, the title last seen and the gear kept, ADR-0055 §3), the children, the events (kind, content id, child,
  date, note, photo ids) and the wardrobe rows. In the app's defaults: the film-offer answers (keys per occasion, whose
  ids name the child), the weekly reminder, the preferences and what the film sheet remembers. Start over erases the
  store, the photos, the reminder and the offer answers, and keeps the preferences and the film choices (ADR-0030 §3,
  §8).
- **The store is open for the process's life.** `StoreConnection` opens one `ModelContainer` and never closes it; each
  repository is a `@ModelActor` with its own context; the widget may have the same SQLite file open read-only. Replacing
  the store's files under them is not safe.
- **`FilePhotoStore.save`** always downscales and re-encodes (JPEG 0.82). The orphan sweep (ADR-0048 §6) deletes a
  `<UUID>.jpg` no entry points to once it is 24 hours old, never when the saga can't be read or has no profile.
- **The old level path is gone** and nothing on screen counts (ADR-0055). ADR-0006: XP for the dad's actions, nothing
  lost, no streaks, no deadlines; nothing pops up unasked (ADR-0030 §6).
- **What Apple documents (checked 2026-11-22):**
  - Apple Archive (iOS 14, macOS 11): `ArchiveByteStream.fileStream(path:mode:options:permissions:)`,
    `compressionStream(using:writingTo:)` and `decompressionStream(readingFrom:)`; `ArchiveStream.encodeStream(writingTo:)`
    and `decodeStream(readingFrom:)`; `ArchiveStreamProtocol`'s `writeHeader(_:)`, `writeBlob(key:from:)`,
    `readHeader() -> ArchiveHeader?`, `readBlob(key:into:)`, `close()`, `cancel()`. A header is built from `PAT` (path),
    `TYP` (entry type) and `DAT` (a blob with its size) fields, as in Apple's "Compressing and saving a string to the
    file system". `ArchiveCompression` has `.none`, `.lz4`, `.zlib`, `.lzma`, `.lzfse` ("recommended for use on Apple
    platforms"), `.lzbitmap`, `.lzraven`. Sizes are `UInt64`. The classes are not marked `Sendable`.
  - `fileImporter(isPresented:allowedContentTypes:onCompletion:)` (iOS 14) "provides security-scoped URLs"; access with
    `startAccessingSecurityScopedResource`. Whether the file is copied is not said.
  - `NSFileCoordinator.coordinate(readingItemAt:…)`: "If the device has not yet downloaded the file at the given URL,
    this method blocks (potentially for a long time) while the file is downloaded." `coordinate(with:queue:byAccessor:)`
    (iOS 8) does it asynchronously and calls its `@Sendable` accessor on the given queue; files must not be touched
    after the accessor returns.
  - `UTType(exportedAs:conformingTo:)` (iOS 14). Apple's "Defining file and data types for your app": a type must
    conform to `public.data` (or `com.apple.package`) for Files to represent it, and to `public.content` "to share your
    type over AirDrop"; the extension goes in `UTTypeTagSpecification`.
  - `ShareLink` with a `Transferable` `FileRepresentation` (iOS 16, already used by the film); `SentTransferredFile`'s
    `allowAccessingOriginalFile: false` gives the receiver "only … a copy of the file".
  - `UIApplication.beginBackgroundTask(withName:expirationHandler:)`: a finite time; the handler is `@MainActor
    @Sendable`, "called shortly before the app's remaining background time reaches 0"; unended tasks get the app killed.
  - `FileProtectionType.completeUnlessOpen`: a file "opened when unlocked, you may continue to access … normally, even if
    the user locks the device".
  - `BGContinuedProcessingTask` (iOS 26): work started in the foreground that continues in the background, with a Live
    Activity the person can cancel.
  - CryptoKit `SHA256` (iOS 13): incremental `update`, `finalize()`.
  - Required-reason APIs: file timestamps `C617.1` covers "timestamps, size, or other metadata of files inside the app
    container, app group container…"; files the user picked need `3B52.1`. Disk space (`volumeAvailableCapacity…`,
    `statfs`…) needs `E174.1` to check room before writing.
  - SwiftData `Schema.Entity.storedPropertiesByName` (iOS 17) lists an entity's stored properties.
  - An app suspended while holding a SQLite or file lock in a shared container is terminated (`0xdead10cc`). No current
    Apple page documents it; TN2408 and Apple's forums describe it.

## Decision

### 1. One file, made and restored only when the dad asks
- **A copy of the saga** is one file, `DadSaga <yyyy-MM-dd>.dadsaga`, made on the iPhone and handed to the share sheet:
  Save to Files, AirDrop, Mail or any app. A **restore** reads a copy the dad picks and replaces the whole saga with it.
  No merging, ever.
- **Never asked for.** No reminder, card, badge, onboarding nudge, "last copy" date or count, anywhere. The app does
  not record that a copy was ever made. Making one earns nothing (ADR-0006).
- **Never behind a paywall**, whatever the pricing ADR decides: it is how a dad keeps his own photos.
- **Ships in v1** (owner, 2026-11-22), so format 1 (§3) is read by every later version.

### 2. What a copy holds: the saga, not the phone
| In the copy | Stays with the iPhone |
|---|---|
| The dad's hero class, skin tone and look; the partner answer | Appearance and haptics (ADR-0030 §3) |
| Every child, in family order, with its id, name, birth day or "not born yet", gender and skin tone | The weekly reminder and its iOS permission (ADR-0024) |
| Every entry the store maps (`fetchEvents`), with its id, kind, content id, child, date, note and photo ids | The film sheet's dates switch and music (ADR-0041, ADR-0046) |
| The photos those entries point to, byte for byte | Photo files no entry points to (orphans) |
| The wardrobe choices | Any film: never stored (ADR-0036) |
| The kept standing: title held, title last seen, gear kept, with "not frozen yet" kept as such (ADR-0055 §3) | |
| The film offers answered (ADR-0037 §5) | |

- **The rule:** what describes the family and what the dad did travels; what belongs to this iPhone stays. The
  reminder stays because its permission is per iPhone: a restored "on" without permission would show on and never
  arrive. On a new iPhone the reminder card is offered once, as for any new saga.
- An entry whose photo file is missing when the copy is made goes in without that id: it points to nothing here either.

### 3. The file: Apple Archive, with a manifest first and checksums last
- **Container:** an Apple Archive stream (`ArchiveStream.encodeStream`) inside an LZFSE compression stream, as Apple's
  sample does. Apple frameworks only, no code of ours for a container format, streaming in both directions, 64-bit
  sizes (no 4 GB limit), readable on any Mac with `aa extract`. Apple Archive refuses a compressed stream cut short
  anywhere at its first read, so a copy that didn't finish saving is refused before any entry; a file that starts with
  the compressed stream's `pbz` signature is then "not whole", anything else "not a copy". Another compression needs a
  new format version: an older app only reads what its Apple Archive knows.
- **Type:** extension `.dadsaga`, exported type `app.dadsaga.saga-copy` conforming to `public.data` and
  `public.content` (Files, AirDrop), declared in `project.yml` (`UTExportedTypeDeclarations`).
- **Entries, in this order,** each a regular file with only `PAT`, `TYP` and `DAT`: no dates, owners or permissions.
  1. `manifest.json`: `{"app":"1.0 (12)","formatVersion":1,"kind":"app.dadsaga.saga-copy","madeAt":790300000.5,"photoCount":3}`
     (`app` is the version and build that wrote it, so a later version can read around a faulty build's files)
  2. `saga.json` (below)
  3. `photos/<photo id>.jpg`, one per photo, as stored; the id is a UUID
  4. `checksums.json`: `{"sha256":{"manifest.json":"<hex>","saga.json":"<hex>","photos/<id>.jpg":"<hex>",…}}`, the
     SHA-256 of every entry before it, by path
- **`saga.json`, format 1.** Keys are sorted; a key whose value is absent (`nil`) is left out, and the reader takes
  absent or `null` the same:
  ```json
  { "answeredOccasionIDs": ["6F1C…/birthday/1"],
    "children": [ { "birthDay": "2026-03-14", "gender": "girl", "id": "6F1C…", "name": "Λένα", "skinTone": "medium" },
                  { "gender": "boy", "id": "A2B4…", "name": "Μικρός", "skinTone": "mediumLight" } ],
    "entries": [ { "childID": "6F1C…", "contentID": "f-first-smile", "date": 781424000.5, "id": "…", "kind": "first",
                   "note": "…", "photos": ["3D2E…", "77AA…"] } ],
    "hero": { "beard": "full", "classID": "h-chef", "glasses": "none", "hair": "short", "hairColor": "brown",
              "hasPartner": true, "skinTone": "mediumLight" },
    "standing": { "gearIDs": ["g-mug"], "seenTitleID": "t-steady-hands", "titleID": "t-steady-hands" },
    "wardrobe": [ { "choice": "hidden", "skill": "play" }, { "choice": "item", "itemID": "g-duck", "skill": "care" } ] }
  ```
  - Dates (`madeAt`, an entry's `date`) are seconds since 1 January 2001 as a JSON number, the value `Date` holds, so
    they read back exactly. A birth day is `yyyy-MM-dd` on the Gregorian calendar (`CalendarDay`, ADR-0048 §2),
    absent while the child is not born yet. Children are in family order; entries by date; photos in the dad's order.
  - `standing.gearIDs` absent is a saga from before titles whose gear is not frozen yet; `[]` is one with nothing to
    keep. The difference is kept (ADR-0055 §4).
  - Every value is named by format 1 itself (`SagaCopyNamesV1`), never by a Swift case name; a value format 1 doesn't
    have makes the copy damaged.
- **Read in order and checked as it goes:** the manifest must come first and name the format; `saga.json` next, decoded
  and checked (§7) before any photo is written; every photo must be one `saga.json` names, once; anything else, an
  entry out of order or a blob over its limit (64 KB manifest, 16 MB `saga.json`, 64 MB a photo, 8192 pixels a side)
  is refused before it is read. The copy is whole only when `checksums.json` arrives, matches every entry before it,
  and nothing follows it.
- **What every later format must keep,** so an older app can say "update the app" (§4): `manifest.json` first, at most
  64 KB, with `kind` and a whole-number `formatVersion`, in an Apple Archive the oldest reader can open.

### 4. Versions: every older file is read; a newer one is refused before anything is touched
- `formatVersion` is one whole number. A file of a version this app knows is read, however old: format *n*'s DTOs
  (`SagaCopyV1DTO`, …) never change once released, and a newer version maps each older one up with the values a
  migration would give (as `ProfileRecord` reads nil columns).
- A **newer** version is refused after reading the manifest only: "This copy was made by a newer DadSaga. Update the
  app, then try again." An older app never restores less than the file holds, so there are no "minor" versions an
  older reader may skip.
- **What makes a new version:** any change to what a copy holds or how, including a new case of a stored enum (gender,
  skin tone, look parts, skill, entry kind, wardrobe choice). Two tests make it impossible to forget: every stored
  property of every entity in `CurrentSchema` (`Schema.Entity.storedPropertiesByName`) is covered by format 1 or listed
  as not in a copy, and every case of those enums is pinned for format 1.
- **Frozen when it can first be made:** format 1 is fixed by the first `develop` build that can make a copy (the UI
  PR). From then on `Tests/DataTests/Fixtures/SagaCopyV1/` holds a copy that build made and is never regenerated, like
  the store fixtures (ADR-0026).
- New content (cards, titles, gear, heroes) is not a format change: content ids are strings (§5).

### 5. Content ids go in and out as stored
- A copy carries every content id exactly as the store holds it, and a restore writes it back unchanged: a former id
  stays a former id, a retired card stays (ADR-0048 §5, ADR-0053 §6). Stored rows are never rewritten.
- The restore never reads the content. What the app can't name today is kept and named by the rules that already
  exist: a former id finds its item; a retired card counts; an id from newer content (a copy from a newer app of the
  same format) stays hidden, as a store's unknown id does (ADR-0005), and shows once the app is updated; an unknown hero
  is shown as the first hero (ADR-0048 §5); an unknown wardrobe item falls back to automatic; an unknown kept title is
  ignored until the content knows it (ADR-0055 §3).

### 6. Making a copy
- **One whole-saga read.** `WholeSagaRepository.readAll()` reads the profile, children, events, wardrobe and kept
  standing in one turn of one `@ModelActor`, so no write lands between them. The offer answers come from
  `SagaOfferRepository`. Photos are the entries' ids whose files exist (`PhotoStore.storedPhotos()`).
- **Streamed:** one photo in memory at a time, read as stored (`PhotoStore.storedData(id:)`, no decoding) and written as
  one entry, hashing as it goes. Progress is photos written over photos to write; Cancel stops between entries.
- **Written in the app's own temporary folder** (`tmp/SagaCopies/<uuid>/`), created with `.completeUnlessOpen`
  protection, so a lock mid-write doesn't stop it. Nothing of the copy goes in the App Group, which is backed up and
  read by the widget.
- **Shared with `ShareLink`** once made ("Save or send"), with the size written ("Your copy is ready · 412 MB"), read
  from the file's size once it is closed (the app's own file: `C617.1`, already declared). The receiver gets a copy of the file
  (`SentTransferredFile`, `allowAccessingOriginalFile: false`).
- **Deleted** when Settings closes (its `onDismiss`, never `onDisappear`, ADR-0037 §4), when another copy is made, and at
  the next launch (`discardLeftoverCopies()`, beside the films').
- **Leaving the app:** the work runs under `beginBackgroundTask`, so switching apps or locking the phone for a moment
  doesn't stop a copy that takes seconds. If that time runs out, it is cancelled, the partial file deleted, and on return
  the page says it stopped when DadSaga left the screen.
- **No free-space check:** a full disk fails the write (Apple Archive reports it only as an I/O error, so a small write
  through Foundation in the same folder tells a full disk from another failure), the partial file goes, and the page says to free up
  space. Checking first is a disk-space required-reason API (`E174.1`) for a rare case.

### 7. Restoring: check the whole copy first, then ask, then replace in one save
1. **Pick:** `fileImporter` with the `.dadsaga` type only. The picked file is copied into `tmp/SagaCopies/` inside one
   asynchronous coordinated read (`coordinate(with:queue:byAccessor:)` on a queue of its own), which downloads it from
   iCloud Drive first if needed; the security scope ends with it. The copy is read from there. The picked file's dates
   and size are never asked for (that would be `3B52.1`).
2. **Open and check, before asking anything** ("Opening the copy…", with progress and Cancel):
   - the manifest's version (§4); `saga.json` decoded and checked by `SagaCopyRules`: one to four children, unique child
     ids, non-empty names, unique entry ids, at most five photos per entry, no photo on two entries. Not checked: content
     ids (§5), the hero, a birth day after today (a copy made in Auckland is read in Los Angeles), entries whose child
     is no longer in the family (they stay, ADR-0012);
   - each photo written into `MomentPhotos` as it comes, **byte for byte under a new id** (`PhotoStore.adopt(_:)`:
     a JPEG with a size in its header, written with the protection `save` uses; no re-encode, ADR-0042 §1). New ids,
     so nothing the current saga has is touched before the commit. The copy's entries are given the new ids;
   - the checksums at the end.
   Any failure, Cancel or lost background time deletes every photo adopted so far: the current saga was never touched.
3. **Ask** (a confirmation dialog): when it was made and whose saga it is ("Made on 12 March 2027 · Λένα, Μικρός"), and,
   when there is a saga here, plainly what it replaces (§8). Cancel deletes the adopted photos.
4. **Replace, in this order:**
   1. read the photo ids the current entries point to;
   2. **the commit:** `WholeSagaRepository.replaceAll(with:)` deletes every profile, child, event and wardrobe row and
      inserts the copy's, the three kept-standing columns set as the copy has them (nil stays nil), in one
      `saveAllOrNothing` (ADR-0048 §1). If it throws, nothing changed: the adopted photos are deleted and the dad is
      told his saga hasn't changed;
   3. the old saga's photos deleted;
   4. the offer answers replaced by the copy's;
   5. the weekly notifications rescheduled through the app's one `ScheduleWeeklyRemindersUseCase`, and the delivered
      ones removed: they name the old children (as start over does, ADR-0030 §8).
   After the commit nothing can undo the restore; a step that fails after it leaves only files nothing points to, which
   the orphan sweep removes (ADR-0048 §6).
- **A kill at any point is safe.** Before the commit, the adopted photos are orphans written moments ago: the sweep
  deletes them after 24 hours (they are new files, with today's date, never the archive's). After it, the old photos are
  orphans and go at the next sweep. The commit is one SQLite transaction. The whole restore runs under
  `beginBackgroundTask`, so the app isn't suspended holding the store's lock (`0xdead10cc`); if it were killed there,
  SQLite rolls the transaction back.
- **The store's actors (ADR-0034):** the replace is one call on one `@ModelActor`; the others' contexts fetch from the
  store, and every row they could hold was deleted, so they read the new rows. A test writes through every repository
  after a replace. No lock is added: while a restore runs, Settings covers home (or onboarding has no saga), and the page
  holds `UnsavedWork`, so a link from the widget or a notification waits until it ends (ADR-0050 §4).
- **After the restore** the root rebuilds home and the timeline (`RootViewModel.sagaRestored()`), which closes Settings,
  as start over does; from onboarding it opens home. The widget reloads when the app leaves the screen, as after any
  write (ADR-0023 §4); a widget set to a child the copy doesn't have shows the first child (ADR-0023 §1).
- **The title:** the copy brings its own. Restoring an older copy can bring back a lower title than the one on screen:
  that is the dad's choice, said in the confirmation, as start over is (ADR-0030 §8). Nothing in the game lowers it.

### 8. Where it lives, and what it says
- **Settings:** a section "Your data" after "Hero & family", with one row, "Export data", pushing a page with two
  parts: exporting the saga to a file and importing one. The owner chose plain words over "a copy of your saga":
  «Εξαγωγή δεδομένων» / «Εισαγωγή δεδομένων». The file is still called a copy in the text around them. A Settings page is a form, so it is not split by a fold (ADR-0043 §8). While
  it works, the sheet can't be swiped away and Back is hidden; Cancel is the way out.
- **Onboarding:** "Import data" under Continue on the first step, the way back on a new iPhone without a
  backup. It opens the same restore flow in a small sheet; the confirmation there doesn't speak of replacing.
- **Copy** (drafted here; `content` writes the final words before the UI PR):

  | | en | el |
  |---|---|---|
  | Section · row and page | Your data · Export data | Τα δεδομένα σου · Εξαγωγή δεδομένων |
  | Export: text | One file with your saga: your family and hero, your title and wardrobe, every quest, boss and moment with their notes and photos. Keep it in Files or on a computer, or send it to another iPhone. | Ένα αρχείο με την ιστορία σου: την οικογένεια και τον ήρωά σου, τον τίτλο και την ντουλάπα σου, κάθε αποστολή, αφεντικό και στιγμή με τις σημειώσεις και τις φωτογραφίες τους. Κράτα το στα Αρχεία ή σε έναν υπολογιστή, ή στείλ' το σε άλλο iPhone. |
  | Export · making | Make a copy · Making your copy… | Φτιάξε αντίγραφο · Το αντίγραφό σου φτιάχνεται… |
  | Ready · share | Your copy is ready · %@ · Save or send | Το αντίγραφό σου είναι έτοιμο · %@ · Αποθήκευσε ή στείλε |
  | Export: footer | It has no password: it always opens, for you and for anyone who has the file. Keep it where you'd keep your photos. | Δεν έχει κωδικό: ανοίγει πάντα, για σένα και για όποιον έχει το αρχείο. Κράτα το εκεί που θα κρατούσες τις φωτογραφίες σου. |
  | Import: section, onboarding's button and sheet | Import data | Εισαγωγή δεδομένων |
  | Import: text in Settings | Puts the saga from a copy in place of the one on this iPhone. We'll ask before anything changes. | Βάζει την ιστορία ενός αντιγράφου στη θέση αυτής που έχεις σε αυτό το iPhone. Πριν αλλάξει οτιδήποτε, θα σε ρωτήσουμε. |
  | Import: text on onboarding | If you have a copy of your saga from Export data, choose it here and pick up where you left off. | Αν έχεις αντίγραφο της ιστορίας σου από την Εξαγωγή δεδομένων, διάλεξέ το εδώ και συνέχισε από εκεί που είχες μείνει. |
  | Import · opening | Choose a copy · Opening the copy… | Διάλεξε αντίγραφο · Το αντίγραφο ανοίγει… |
  | Confirm: title · made | Import this copy? · Made on %1$@ · %2$@ | Εισαγωγή αυτού του αντιγράφου; · Φτιάχτηκε στις %1$@ · %2$@ |
  | Confirm: replaces (Settings only) | Everything on this iPhone now will be replaced by what's in the copy: your family and hero, your title and wardrobe, every quest, boss and moment with their notes and photos. This can't be undone. | Ό,τι υπάρχει τώρα σε αυτό το iPhone θα αντικατασταθεί από όσα έχει το αντίγραφο: η οικογένεια και ο ήρωάς σου, ο τίτλος και η ντουλάπα σου, κάθε αποστολή, αφεντικό και στιγμή με τις σημειώσεις και τις φωτογραφίες τους. Δεν αναιρείται. |
  | Confirm: buttons · importing | Import (destructive in Settings) · Cancel · Importing your saga… | Εισαγωγή · Άκυρο · Γίνεται εισαγωγή της ιστορίας σου… |
  | After every failure in Settings | Your saga hasn't changed. | Η ιστορία σου δεν άλλαξε. |
  | Newer format | This copy was made by a newer version of DadSaga. Update the app, then try again. | Το αντίγραφο φτιάχτηκε από νεότερη έκδοση του DadSaga. Ενημέρωσε την εφαρμογή και δοκίμασε ξανά. |
  | Not whole, damaged or not a copy (one message) | This file isn't a complete DadSaga copy. It may not have finished saving or sending. | Αυτό το αρχείο δεν είναι ολόκληρο αντίγραφο του DadSaga. Ίσως δεν πρόλαβε να αποθηκευτεί ή να σταλεί ολόκληρο. |
  | Can't read the file | The file couldn't be opened. If it's in iCloud Drive or another cloud service, check your connection and try again. | Το αρχείο δεν άνοιξε. Αν είναι στο iCloud Drive ή σε άλλη υπηρεσία cloud, έλεγξε τη σύνδεσή σου και δοκίμασε ξανά. |
  | No space | There isn't enough free space on this iPhone. Free up some space and try again. | Δεν υπάρχει αρκετός ελεύθερος χώρος σε αυτό το iPhone. Ελευθέρωσε λίγο χώρο και δοκίμασε ξανά. |
  | Left the app | The export (import) stopped when you left DadSaga. Try again whenever you like, and keep DadSaga open until it's done. | Η εξαγωγή (εισαγωγή) σταμάτησε όταν βγήκες από το DadSaga. Δοκίμασε ξανά όποτε θέλεις και κράτα το DadSaga ανοιχτό μέχρι να τελειώσει. |
  | Other failure | Couldn't export your data. Please try again. · Couldn't import the data. Please try again. | Η εξαγωγή δεν έγινε. Δοκίμασε ξανά. · Η εισαγωγή δεν έγινε. Δοκίμασε ξανά. |
  | Nothing yet | There's nothing to export yet. | Δεν υπάρχει ακόμα κάτι για εξαγωγή. |

  On onboarding there is no saga yet, so a failure there doesn't say it hasn't changed. VoiceOver hears "Your copy is
  ready" and every failure as it appears.

  The confirmation's wording mirrors start over's (ADR-0030 §8): it says what goes, with no counts, titles or alarm.

### 9. Privacy
- **Nothing reaches us.** The dad makes the file and chooses where it goes; App Store's "Data Not Collected" stays true.
- **The privacy manifests don't change:** no new required-reason API. The app's own files' metadata is already
  `C617.1`; the picked file is only read, never asked for its dates or size; no disk-space API (§6); Apple Archive and
  CryptoKit are not on the list. Hashing is not encryption: `ITSAppUsesNonExemptEncryption` stays false (ADR-0051).
- **No password** on the file, and the pages say so: a forgotten password would lose the one thing a copy is for.
- **The privacy pages** (`web/privacy`, `web/el/privacy`) gain a section "Copies of your saga" (what a copy holds and
  doesn't, that the dad chooses where it goes, no password, the temporary file deleted, a restore reads only the file
  he picks and replaces the saga); the storage paragraph says "unless you save a copy"; "Deleting your data" says start
  over doesn't delete copies he saved. The exact text is in the plan.
- **The support pages** (`web/support`, `web/el/support`): "How do I move my saga to a new iPhone?" leads with a copy;
  its iCloud Backup and Quick Start sentence stays only if the device test shows App Group data comes back (and if it
  doesn't, the privacy page's backup sentence changes too). A new question, "How do I keep a copy of my saga?".
- **The About statement** (ADR-0030 §7) becomes: "… stay on this iPhone, in its backups if you make them, and in any
  copy of your saga you make." / «… μένουν σε αυτό το iPhone, στα αντίγραφα ασφαλείας του αν τα κρατάς, και σε όποιο
  αντίγραφο της ιστορίας σου φτιάξεις.»

### 10. Where the code goes
| Layer | Adds | Changes or removes |
|---|---|---|
| Domain | `StoredSaga` (profile, events, outfit, kept standing; its photo ids and `replacingPhotoIDs`); `SagaCopy` (a stored saga, the offers answered, when it was made); `SagaCopyRules` | |
| Application | `WholeSagaRepository` (`readAll`, `replaceAll(with:)`, `eraseAll`); `SagaCopyFiles` port with `MadeSagaCopy` and `SagaCopyError`; `MakeSagaCopyUseCase`, `RestoreSagaUseCase` (`open`, `restore`, `discard`) with `OpenedSagaCopy`; `PhotoStore.storedData(id:)`, `adopt(_:)` | `SagaEraser` goes into `WholeSagaRepository`; `StartOverUseCase` takes it |
| Data | `SwiftDataWholeSagaRepository`; `ConnectedWholeSagaRepository`; `AppleArchiveSagaCopyFiles`; `SagaCopyV1DTO` and its mappers; `FilePhotoStore.storedData`, `adopt`; the `SagaCopyV1` fixture | `SwiftDataSagaEraser` and `ConnectedSagaEraser` go; `LocalStore.wholeSaga` replaces `eraser`; `StoreConnection.Repositories` |
| Presentation | `SagaCopyViewModel`/`SagaCopyViewState`/`SagaCopyView`; `RestoreSagaViewModel`/`RestoreSagaViewState` with its section and onboarding sheet; `SagaCopyFile` (`Transferable`, `UTType.dadSagaCopy`); `BackgroundTime` | Settings (section, page, `onSagaRestored`); onboarding's restore button; `RootViewModel.sagaRestored()` and `RootView` rebuilding home and the timeline; the About statement; strings in el and en |
| App | `UIKitBackgroundTime`; wiring; `discardLeftoverCopies()` at launch; `UTExportedTypeDeclarations` in `project.yml` | `AppContainer` (start over through `wholeSaga`) |
| Web | | both privacy pages, both support pages |

## Rejected
- **Swapping the store's files** (copying a `DadSaga.store` in): the container stays open for the process's life, the
  widget may hold the file, and SQLite's log and index files would have to move with it. Rows in one save are atomic
  and need nothing new.
- **A document package** (a folder with a type): cloud providers and transports turn packages into folders or drop
  them.
- **ZIP:** no Apple API reads or writes one on iOS; it would be code of our own, with ZIP64 past 4 GB, or a third-party
  dependency. Its gain is opening the file on Windows. Kept as an open question for the owner.
- **The saga's JSON shaped like the SwiftData records:** the schema would become the file format; the file is described
  in the Domain's terms and versioned on its own.
- **Lenient reading of unknown values** (an unknown hair style read as the standard one): an older app would restore
  less than the file holds without saying so. It refuses and asks for an update.
- **Merging** a copy into the saga (the owner's direction): which family, which title, which wardrobe wins.
- **Checking the whole copy only after the dad confirms:** he would be asked to replace his saga with a file that turns
  out cut short.
- **Staging photos in a folder of their own, then moving them:** the existing rule (photos first, then the entry; the
  sweep removes what a kill leaves) already covers it.
- **Re-encoding imported photos through `save`:** a JPEG of a JPEG (ADR-0042 §1), and slower.
- **A password or encryption:** a forgotten password loses the copy; it would also be encryption of our own (ADR-0051).
- **Carrying the reminder and the phone's preferences:** a reminder "on" without this iPhone's permission; preferences
  belong to the phone (ADR-0030 §3).
- **A "last copy made" line, a reminder to make one, or a copy made by itself:** pressure, and a file the dad didn't
  choose to make (ADR-0006).
- **Building the file lazily inside the share sheet** (`FileRepresentation`'s async export): no progress, no Cancel,
  and a share target that may give up on a large file.
- **A free-space check before writing:** a required-reason API (`E174.1`) for a case that already fails safely.

## Deferred (v1.x)
- **Opening a `.dadsaga` file with DadSaga** (a tap in Files or AirDrop's "Open with": `CFBundleDocumentTypes` and
  `onOpenURL` for a file): a second way in, arriving while an editor holds changes, a film is being made or a restore
  runs. Every path is covered without it in v1.
- **`BGContinuedProcessingTask`** (iOS 26) with its Live Activity, if dads with very large sagas see copies stop when
  they leave the app.
- **Telling the dad that a copy holds entries this version can't show yet** (from a newer app of the same format).
- **A copy of the current saga made automatically before a restore**, to undo it.
- **A localised name for the file type** in Files, if `UTTypeDescription` can be localised through `InfoPlist.xcstrings`.
- Sync (ADR-0026 §6) is still its own decision; a copy is not sync.

## Verification status
The format and the restore engine are built and tested in the package (PR 1): a round trip through two real stores, the
format-1 fixture, files cut short, changed, hand-made and from a newer format. The screens (PR 2) are tested through
their presenters and drawn in the simulator. Format 1 is frozen from PR 2's merge. File
protection (`completeUnlessOpen`, iOS only: macOS refuses to open a file created with a protection class) and a full disk
are checked only on a device. To check on a device, with a saga of 500 photos or more:
- making a copy: time, memory (Instruments: flat, about one photo at a time), heat; saving it to iCloud Drive in Files;
  AirDrop to a second iPhone; locking the phone and switching apps mid-copy;
- restoring on a fresh install from onboarding, from a file in iCloud Drive not yet downloaded, and from AirDrop's
  Downloads; over an existing saga from Settings; switching apps mid-restore; Cancel at each step;
- after a restore: home, the timeline, the wardrobe, the title and a title card left open in the copy; the widget for
  the same and for another child; the weekly reminder on a phone where it is on;
- a copy cut short (a file truncated on the Mac) and one from a newer build refused, with the saga unchanged;
- both screens in Greek and English, with VoiceOver, at the accessibility text sizes and on iPhone Duo folded.

## Consequences
- A dad can keep his saga anywhere and bring it back on any iPhone, without an account or a server; the photos taken
  with the app's camera can leave it at last.
- Every later version reads format 1 for good: one more frozen fixture, and a test that fails when a stored field or an
  enum case is added without a new format version.
- A restore replaces the whole saga in one save; a failed or cut-short one changes nothing, and what a kill leaves is
  swept.
- The privacy and support pages, and the About statement, change; the manifests and the App Store label don't.
- `SagaEraser` goes into `WholeSagaRepository`: one port for the saga as a whole (erase, read, replace).
- The file can be read by anyone who has it. The pages say so; the app adds no password.
