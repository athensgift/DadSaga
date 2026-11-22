# Plan: a copy of the saga (export and restore)

Implements [ADR-0057](../adr/0057-saga-copy-export-and-restore.md) (Proposed). ROADMAP Phase 4, "Export and restore of
the saga". **A v1 requirement** (owner, 2026-11-22): it gates the first App Store release whatever the iCloud Backup
test shows. Scope is kept lean; what doesn't touch the safety of the data or the file format waits for v1.x.

Read before starting: ADR-0004, 0006, 0007, 0026, 0030, 0034, 0042, 0043 §8, 0048 §1 and §5–§6, 0050 §4, 0051, 0053 §6,
0055 §3–§5, and `.claude/rules/`.

## Decisions taken (details in the ADR)
1. **One file**, `DadSaga <yyyy-MM-dd>.dadsaga`: an Apple Archive (LZFSE) with `manifest.json` first, `saga.json`,
   `photos/<id>.jpg` as stored, and `checksums.json` last. Type `app.dadsaga.saga-copy` (`public.data`,
   `public.content`). Shared with `ShareLink`; restored through `fileImporter`.
2. **The saga travels, the phone's settings stay.** In: hero and look, partner answer, children, every entry, the
   photos they point to, the wardrobe, the kept standing (nil gear kept as nil), the film offers answered. Out:
   appearance, haptics, the reminder (its permission is per iPhone), the film sheet's choices, orphan photos.
3. **Format 1 is read forever.** A newer format is refused after its manifest, with "update the app". Any change to
   what a copy holds, or a new case of a stored enum, is a new format version; two tests enforce it.
4. **Content ids verbatim**, both ways. The restore never reads the content.
5. **Restore = check everything, then ask, then one save.** Photos are adopted byte for byte under new ids before the
   question; the commit is `replaceAll(with:)` in one `saveAllOrNothing`; the old photos go after it. Any failure before
   the commit deletes the adopted photos and leaves the saga as it was.
6. **Where:** Settings › "Your saga" › "Copy of your saga" (one page, make and restore), and "Restore from a copy" on
   onboarding's first step.
7. **No nag, no paywall, no password, no free-space check, no new required-reason API.**
8. **Redesign, not bolt-on:** `SagaEraser` becomes part of `WholeSagaRepository` (erase, read all, replace all), the one
   port for the saga as a whole. Start over erases through it; a restore replaces through it.

## Step by step

Each step stays green: `swiftlint --strict`, the suite being changed (`swift test --build-system swiftbuild --filter …`),
then the whole package and the simulator build before the PR.

### 1. Domain (`Packages/DadSagaKit/Sources/Domain`)
- `Entities/StoredSaga.swift`: `public struct StoredSaga: Hashable, Sendable` with `profile: PlayerProfile`,
  `events: [ProgressEvent]`, `outfit: Outfit`, `kept: KeptStanding`. `photoIDs: [String]` (every entry's, in order);
  `replacingPhotoIDs(_ newIDs: [String: String]) -> StoredSaga` (an id without a new one is dropped from its entry).
- `Entities/SagaCopy.swift`: `public struct SagaCopy: Hashable, Sendable` with `saga: StoredSaga`,
  `answeredOccasionIDs: Set<String>`, `madeAt: Date`.
- `Rules/SagaCopyRules.swift`: `public enum SagaCopyRules { static func checked(_ saga: StoredSaga) throws }` and
  `SagaCopyRuleError` (`.childCount`, `.duplicateChild`, `.emptyChildName`, `.duplicateEntry`, `.tooManyPhotos`,
  `.sharedPhoto`). Deliberately not: content ids, the hero, `birthDay <= today`, an entry's child being in the family.
- Tests (`DomainTests/SagaCopyRulesTests.swift`, `StoredSagaTests.swift`): see the test list.

### 2. Application (`Packages/DadSagaKit/Sources/Application`)
- `Repositories/WholeSagaRepository.swift` replaces `Repositories/SagaEraser.swift` (deleted):
  ```swift
  public protocol WholeSagaRepository: Sendable {
      /// Profile, children, every entry the store maps, the wardrobe and the kept standing, in one read. Nil without a profile.
      func readAll() async throws -> StoredSaga?
      /// Every row replaced by `saga` in one save: all of it or none of it.
      func replaceAll(with saga: StoredSaga) async throws
      /// Starting over (ADR-0030 §8): every row deleted in one save.
      func eraseAll() async throws
  }
  ```
- `Repositories/SagaCopyFiles.swift` (the file format's port):
  ```swift
  public protocol SagaCopyFiles: Sendable {
      /// Writes `copy` and its photos to a new file in the app's temporary folder; one photo in memory at a time.
      func write(_ copy: SagaCopy, photo: @escaping @Sendable (String) async throws -> Data,
                 progress: @escaping @Sendable (Double) -> Void) async throws -> MadeSagaCopy
      /// Reads the copy the dad picked. Each photo goes to `adopt` as it comes, which returns its new id; the copy comes
      /// back with those ids. Throws `SagaCopyError` before any photo when the manifest or `saga.json` is refused.
      func read(fileAt url: URL, adopt: @escaping @Sendable (Data) async throws -> String,
                progress: @escaping @Sendable (Double) -> Void) async throws -> SagaCopy
      /// Deletes every file `write` and `read` left in the temporary folder.
      func discardTemporaryFiles() async
  }
  public struct MadeSagaCopy: Hashable, Sendable { public let url: URL; public let byteCount: Int64 }
  public enum SagaCopyError: Error, Equatable {
      case nothingToCopy, notACopy, incomplete, damaged, newerFormat, unreadable, notEnoughSpace
  }
  ```
  `SagaCopyError(_ error:)` recognises `CocoaError(.fileWriteOutOfSpace)` and `POSIXError(.ENOSPC)` as
  `.notEnoughSpace`, so both use cases map a full disk the same way.
- `Repositories/PhotoStore.swift`: add `storedData(id:) async throws -> Data` (the file as stored) and
  `adopt(_ jpeg: Data) async throws -> String` (written as is under a new id; not a JPEG with a size in its header
  throws).
- `UseCases/MakeSagaCopyUseCase.swift`: `MakeSagaCopyUseCase` (`execute(on:progress:) async throws -> MadeSagaCopy`,
  `discardCopies() async`) and `DefaultMakeSagaCopyUseCase(wholeSaga:sagaOffers:photoStore:files:)`. `@concurrent`
  `execute`: `readAll()` (nil → `.nothingToCopy`), the offers answered, photo ids whose files exist
  (`storedPhotos()`), `replacingPhotoIDs` to drop missing ones, then `files.write`.
- `UseCases/RestoreSagaUseCase.swift`: `RestoreSagaUseCase` with
  `open(fileAt:progress:) async throws -> OpenedSagaCopy`, `restore(_:on:) async throws`, `discard(_:) async`, and
  `DefaultRestoreSagaUseCase(wholeSaga:progressRepository:photoStore:sagaOffers:files:schedule:notificationScheduler:)`.
  `OpenedSagaCopy` (Sendable): `madeAt`, `childNames` for the question, and, internal, the copy and the adopted ids.
  - `open` (`@concurrent`): `files.read(fileAt:adopt:)` with `adopt` recording each new id in a `Mutex<[String]>`; on any
    throw (cancel included), every recorded id is deleted and the error mapped to `SagaCopyError`.
  - `restore`: old ids (`referencedPhotoIDs()`), then `replaceAll` (the commit; on throw, adopted ids deleted and
    rethrown), then the old photos deleted, the offer answers replaced (`deleteAll`, then `markAnswered` each), the
    reminders rescheduled through the app's one `ScheduleWeeklyRemindersUseCase`, delivered notes removed.
  - `discard`: deletes the adopted ids.
- `UseCases/StartOverUseCase.swift`: `eraser: any SagaEraser` becomes `wholeSaga: any WholeSagaRepository`.

### 3. Data (`Packages/DadSagaKit/Sources/Data`)
- `Persistence/SwiftDataWholeSagaRepository.swift` replaces `Persistence/SwiftDataSagaEraser.swift` (deleted):
  `@ModelActor actor SwiftDataWholeSagaRepository: WholeSagaRepository`.
  - `readAll()`: the profile row (`first`, as everywhere), children by order, events by date through the same
    `toDomain()` as `fetchEvents`, the wardrobe through `OutfitCoding`, the kept standing from the row's three columns,
    all in one actor turn.
  - `replaceAll(with:)`: inside one `saveAllOrNothing`, delete every row of the four models (the old `deleteEvery`),
    then insert: `ProfileRecord(profile:)` then **set `heldTitleID`, `seenTitleID` and `keptGearIDs` from the copy,
    nil included** (`ProfileRecord(profile:)` sets `[]`, which would freeze a pre-titles saga's gear as nothing);
    `ChildRecord(child:order:)`; `ProgressEventRecord(event:)`; `OutfitRecord` per choice.
  - `eraseAll()`: as today.
- `Persistence/ConnectedRepositories.swift`: `ConnectedWholeSagaRepository` (`@concurrent` methods) replaces
  `ConnectedSagaEraser`. `Persistence/StoreConnection.swift`: `Repositories.wholeSaga`. `Persistence/LocalStore.swift`:
  `public let wholeSaga: any WholeSagaRepository` replaces `eraser`.
- `Persistence/FilePhotoStore.swift`: `storedData(id:)` (`Data(contentsOf:)` of the file); `adopt(_:)`
  (`CGImageSourceCreateWithData`, type `public.jpeg`, width and height in the properties, then written `.atomic` with
  `.completeFileProtectionUntilFirstUserAuthentication`, as `save`, under a new UUID). It never calls `downscaledJPEG`.
- `SagaCopy/SagaCopyFormat.swift`: the format's constants: type id and extension, entry names and order, size limits
  (64 KB, 64 MB, 64 MB), `currentFormatVersion = 1`.
- `SagaCopy/SagaCopyV1DTO.swift`: frozen `Codable` DTOs for format 1 (`ManifestV1`, `SagaV1` with `HeroV1`, `ChildV1`,
  `EntryV1`, `WardrobeChoiceV1`, `StandingV1`, `ChecksumsV1`) and their mappers to and from `SagaCopy`. Enum values
  through explicit switches, never `rawValue` alone, so renaming a Swift case can't change the file. Unknown values
  throw `.damaged`. Dates as `Double` seconds since 1970; birth days as `yyyy-MM-dd`.
- `SagaCopy/AppleArchiveSagaCopyFiles.swift`: `public struct AppleArchiveSagaCopyFiles: SagaCopyFiles` with a folder
  (default `tmp/SagaCopies`).
  - `write`: creates `<uuid>/DadSaga <day>.dadsaga` empty with `.protectionKey: .completeUnlessOpen`, opens it with
    `ArchiveByteStream.fileStream`, wraps it in `compressionStream(using: .lzfse)` and `ArchiveStream.encodeStream`,
    writes the entries with `PAT`/`TYP`/`DAT` only, hashing with `SHA256` as it goes, counts the bytes written, and
    deletes the file on any throw. `try Task.checkCancellation()` between entries.
  - `read`: a coordinated copy of the picked file into the folder (`startAccessingSecurityScopedResource`,
    `NSFileCoordinator.coordinate(with: [.readingIntent(with:)], queue:)` on its own `OperationQueue`, bridged with
    `withCheckedThrowingContinuation`); then `decompressionStream` and `decodeStream` on the local copy; the manifest
    first (version check before anything else), `saga.json` next and `SagaCopyRules.checked` on it before any photo; each
    photo read into a buffer of its header's size (refused over the limit), hashed and handed to `adopt`; the checksums
    last; the local copy deleted at the end, whatever happened.
  - The stream objects are created, used and closed inside one function and never captured by an escaping closure.
- Tests and fixtures: see the test list. `Tests/DataTests/Fixtures/SagaCopyV1/` is created in PR 1 and may be
  regenerated until PR 2 merges; from then on never (ADR-0057 §4).

### 4. Presentation (`Packages/DadSagaKit/Sources/Presentation`)
- `SagaCopy/BackgroundTime.swift`: `public protocol BackgroundTime: Sendable { func run<T: Sendable>(_ name: String,
  _ work: @escaping @Sendable () async throws -> T) async throws -> T }` (asks iOS for time, cancels `work` when it runs
  out) and `ImmediateBackgroundTime` for tests and previews.
- `SagaCopy/SagaCopyFile.swift`: `extension UTType { static let dadSagaCopy = UTType(exportedAs: "app.dadsaga.saga-copy",
  conformingTo: .data) }` and `struct SagaCopyFile: Transferable` (`FileRepresentation(exportedContentType:
  .dadSagaCopy) { SentTransferredFile($0.url) }`), like `SagaFilmFile`.
- `SagaCopy/SagaCopyViewModel.swift` + `SagaCopyViewState.swift`: `@MainActor @Observable`, no SwiftUI. States
  `.ready`, `.making(Double)`, `.made(SagaCopyMade)` (url, size text, labels), `.failed(String)`; `make()`, `cancel()`,
  `discard()` (Settings' `onDismiss`); progress through an `AsyncStream` with `.bufferingNewest(1)`, as
  `SagaFilmRenderer` does; exposes `isWorking`, which the page reports to `UnsavedWork` (an `EditorRegistration`, scope
  `settings`) so a link waits (ADR-0050 §4). Owns a `RestoreSagaViewModel` for its second part.
- `SagaCopy/RestoreSagaViewModel.swift` + `RestoreSagaViewState.swift`: states `.ready`, `.opening(Double)`,
  `.asking(RestoreQuestion)` (title, made line with the date in the dad's locale and the names as a list, the replace
  line only when `replacesSaga`), `.restoring`, `.failed(String)`; `picked(_ url:)`, `confirm()`, `cancel()`; calls
  `onRestored` on success. `isWorking` while opening and restoring, reported the same way. Every failure in Settings
  ends with "Your saga hasn't changed."
- `SagaCopy/SagaCopyView.swift` (the Settings page: a `Form`, two sections, `interactiveDismissDisabled` and the back
  button hidden while working), `SagaCopy/RestoreSagaSection.swift` (the picker button, `fileImporter`, progress,
  `confirmationDialog`), `SagaCopy/RestoreSagaSheet.swift` (onboarding's small sheet around the same section).
- `Settings/SettingsView.swift`: the "Your saga" section and `SettingsPage.sagaCopy`. `Settings/SettingsScreens.swift`:
  `SettingsPages.makeSagaCopy` and `SettingsActions.onSagaRestored`. `Settings/SettingsContent+Make.swift`,
  `SettingsViewState.swift`: labels, and the About statement's new text.
- `Onboarding/OnboardingView.swift`, `OnboardingViewState.swift`: "Restore from a copy" under Continue, opening
  `RestoreSagaSheet` with a view model built by the root (`replacesSaga: false`).
- `Root/RootViewModel.swift`: `sagaRestored()` drops waiting links, selects Adventure, sets `.home` and bumps
  `sagaGeneration`. `Root/RootView.swift`: `prepareScreen` rebuilds home and the timeline when the generation changes
  (today they live as long as the state stays `.home`); `MakeOnboarding` also gets the restore view model.
- `Localization/Resources/Localizable.xcstrings`: every string of ADR-0057 §8, el and en, `translated`,
  `extractionState: manual`; the About statement changed. `content` writes the final words first.

### 5. App and project
- `App/DI/UIKitBackgroundTime.swift`: `BackgroundTime` with `beginBackgroundTask(withName:expirationHandler:)` and
  `endBackgroundTask`; the handler cancels the work's task, then ends the task.
- `App/DI/AppContainer.swift`: `store.wholeSaga` for start over; `AppleArchiveSagaCopyFiles()` once;
  `makeSagaCopyViewModel(actions:)` and `makeRestoreSagaViewModel(replacesSaga:onRestored:)`; `settingsPages` gains the
  page; `discardLeftoverCopies()`. `App/DadSagaApp.swift`: call it at launch beside `discardLeftoverFilms()`.
- `project.yml`: `UTExportedTypeDeclarations` on the app (identifier `app.dadsaga.saga-copy`, description "DadSaga
  copy", `UTTypeConformsTo` `[public.data, public.content]`, `public.filename-extension: [dadsaga]`). No
  `CFBundleDocumentTypes` in v1. Then `xcodegen generate`.
- `docs/ROADMAP.md`: tick "Export and restore of the saga"; reword the iCloud Backup line (it no longer decides v1).

### 6. Web (PR 2, same PR as the UI: ADR-0051)
Exact text in "Web text" below: `web/privacy/index.html`, `web/el/privacy/index.html`, `web/support/index.html`,
`web/el/support/index.html`, with "Last updated" moved to the PR's date.

## Tests
Given/When/Then names; behaviour, not implementation (`.claude/rules/tests.md`).

**Domain**
- A saga of one to four children with unique ids passes; none or five is refused; two children with one id, an empty
  name, two entries with one id, six photos on an entry, one photo on two entries are each refused.
- A child born "tomorrow" (a copy from another time zone), an entry of a child no longer in the family, an unknown
  content id and an unknown hero all pass.
- `replacingPhotoIDs` keeps the dad's order and the cover, and drops an id without a new one.

**Application** (stub repositories, a stub `SagaCopyFiles`)
- Making a copy writes what the store holds plus the offers answered; an entry whose photo file is gone goes without
  that id; no profile throws `.nothingToCopy`; a photo read that fails throws and leaves no file.
- Opening adopts every photo and returns the copy with the new ids; a reader that throws half way, or a cancel, deletes
  every photo adopted so far and never calls `replaceAll`.
- Restoring calls `replaceAll` with the adopted ids, then deletes the old saga's photos, replaces the offers answered,
  reschedules once and removes delivered notes, in that order.
- A `replaceAll` that throws deletes the adopted photos, keeps the old ones, leaves the offers and notifications alone.
- Discarding an opened copy deletes its photos and nothing else.
- Start over still erases in one write first and touches nothing else when it fails (existing tests, new port).

**Data** (real stores in temporary folders, as `FailedSaveTests`)
- **Round trip:** a full saga (a born child and one not born yet; a quest, a boss, a first; a former id
  `q-w2-car-seat`, a retired `q-w1-tummy-time`, an unknown `q-from-the-future`; Greek and emoji notes; entries with
  none to five photos; a wardrobe with `hidden` and an item; kept standing with gear `nil`, and another with `[]`; offers
  answered) is written, then read into a second store: every repository reads exactly what the first one had, the
  photos are byte for byte the same under new ids, and the title and gear `DadStanding` gives are the same.
- **Format 1 fixture:** `Fixtures/SagaCopyV1/` (a copy with three small photos, made by the format-1 build) reads into
  the expected saga, written out in the test.
- **Coverage:** every stored property of every `CurrentSchema` entity (`Schema.Entity.storedPropertiesByName`) is in
  format 1's list or its "not in a copy" list; every case of `Gender`, `SkinTone`, the four look enums, `Skill`, the
  entry kinds and the wardrobe choices is pinned for format 1. A new column or case fails until a format version covers
  it.
- **Damaged files:** cut short after the manifest, inside `saga.json`, inside a photo, and just before `checksums.json`
  → `.incomplete`; a changed byte in a photo → `.damaged`; an unknown entry name, a `../` path, a second manifest, a
  photo `saga.json` doesn't name → `.damaged`; a blob over its limit refused before it is read; `formatVersion: 2`
  → `.newerFormat` with no photo adopted; a JPEG renamed `.dadsaga` → `.notACopy`. In every case the store and the
  photo folder are unchanged.
- **Replace:** `replaceAll` swaps every row in one save; after it, each repository (profile save, a quest, a wardrobe
  choice, `keep`, `markSeen`) writes on the new saga and reads it back; on a store opened read-only (every save throws)
  it throws and every row is as it was; the widget's read-only store reads the new saga.
- **Photos:** `adopt` keeps the bytes as they are, refuses a PNG and non-image data, and its file is today's (so the
  sweep waits 24 hours); `storedData` returns the file's bytes.

**Presentation**
- Making: ready → making (progress) → made, with the size in el and en; Cancel goes back to ready with no file; lost
  background time shows "It stopped when DadSaga left the screen"; a full disk shows its message; `isWorking` is true
  while making and false after, and a link sent meanwhile opens only after it.
- Restoring: opening → asking, with the date in the dad's locale and the children's names; confirm → restoring →
  `onRestored`; Cancel at the question discards; a newer copy and a damaged one show their messages, ending with "Your
  saga hasn't changed."; from onboarding the question has no replace line.
- Root: `sagaRestored()` from home gives new home and timeline view models, drops a waiting link and selects
  Adventure; from onboarding it opens home.
- Strings: every new key has el and en (the catalog tests).

**On screen** (`ui-check`): the page in each state, the question, onboarding's button and sheet, on iPhone 17 and on
iPhone Duo folded and flat, el and en, the largest text size. **On a device:** ADR-0057's verification list.

## PR split
Two PRs, because the format is what must be right first, and the UI touches different files (CLAUDE.md: "the data
model in one, all its UI in the next").
1. **`feature/saga-export`** (this branch): "The saga copy format and the restore engine". Steps 1–3, the
   `AppContainer` rename for start over, the ADR, this plan, every Domain, Application and Data test and the format-1
   fixture. Nothing is reachable from the UI. `reviewer` checks it with the format as its main subject.
2. **`feature/saga-copy-ui`**, from `develop` after PR 1: steps 4–6, `project.yml`, the strings (after `content`), the
   web pages, ROADMAP. `ui-check` draws it; `reviewer` checks it; the device checks before it is called done. Its merge
   freezes format 1.

## Risks

### Swift 6 strict concurrency
- **Apple Archive's classes are not `Sendable`.** Keep every stream inside one function; never store them in an actor
  or struct, never capture them in `withTaskCancellationHandler`'s `@Sendable` handler. Cancel cooperatively between
  entries (`Task.checkCancellation()`), and close the streams in `defer`.
- **`nonisolated(nonsending)` by default** (ADR-0034 §7): the use cases' heavy methods and the Data methods are
  `@concurrent`, or hashing and JSON run on the main actor.
- **The coordinated read blocks** "potentially for a long time" while iCloud downloads: use the asynchronous
  `coordinate(with:queue:byAccessor:)` on an `OperationQueue` of its own, never the synchronous one on Swift's pool. If
  `NSFileCoordinator` isn't `Sendable` in the SDK, its cancel goes through a small `@unchecked Sendable` box with a
  comment, as the `UserDefaults` repositories do.
- **Progress** from a background task to the main actor: an `AsyncStream` with `.bufferingNewest(1)`, never one main
  actor hop per photo.
- **The adopted ids** are written from the reader's task and read on failure: `Mutex` (Synchronization), as the film
  renderer uses.
- **`beginBackgroundTask`'s handler** is `@MainActor @Sendable`; it must cancel and end the task before returning, or
  iOS kills the app.

### SwiftData
- **No schema change** (V7 stays). The format is not the schema; the coverage test ties them.
- **`ProfileRecord(profile:)` writes `keptGearIDs = []`.** A replace that relied on it, or on `StandingRepository.keep`
  (whose `gearIDs` is non-optional), would freeze a pre-titles saga's gear as nothing and take its old gear away
  (ADR-0055 §4). The replace sets the three columns itself; a round-trip test with `nil` guards it.
- **Several contexts on one container.** Other actors' contexts may hold objects for rows the replace deleted; since
  every row is new, their fetches return the new ones. A test writes through every repository after a replace; if it
  fails, the fix is in Data (refetch or reset those contexts), not a guard.
- **One save of thousands of rows** (deletes and inserts) inside `saveAllOrNothing`: measured on the device with a large
  saga; still one transaction.
- **`0xdead10cc`:** an app suspended while holding the store's lock in the App Group is killed. The whole restore runs
  under `beginBackgroundTask`; a kill mid-commit rolls back, and the saga is the old one.

### iOS 26 API availability
- Everything used is iOS 18 or older (Apple Archive 14, `fileImporter` 14, `UTType` 14, `ShareLink` and
  `SentTransferredFile` 16, CryptoKit 13, `NSFileCoordinator` 8, `Mutex` 18), so no `#available`. The package's macOS 26
  tests have Apple Archive, CryptoKit and `NSFileCoordinator`; `UIApplication` stays in the app target.
- `BGContinuedProcessingTask` (iOS 26) is deferred: Info.plist identifiers and a Live Activity for work that takes
  seconds.

### ADR-0006 and the owner's rules
- Nothing asks for a copy: no reminder, card, badge, nudge or "last copy" date, and the app keeps no record of one.
- No XP, title or celebration for making a copy.
- A restore can bring back a lower title: the dad's choice, said in the question, like start over. The game never
  lowers it.
- Never behind a paywall; the pricing ADR must say so.
- Calm words: what goes, never counts or alarm; failures say the saga hasn't changed.

### Found in the code
- `StoreConnection` never closes its container, and the widget may have the file open: never swap the store's files.
- `RootView` keeps home and the timeline for as long as the state stays `.home`: without `sagaRestored()` a restore
  from Settings would leave the old family's child selected and its cards on screen.
- `FilePhotoStore.save` always re-encodes; an import through it would re-encode every photo.
- `FilePhotoStore.delete` and `deleteAll` swallow errors (`try?`): cleanup after a failed restore can leave files; the
  sweep removes them a day later, so tests check the store, not that every delete succeeded.
- `ProgressEventRecord.toDomain()` leaves out rows without a child or with an unknown kind; none exist since ADR-0023,
  and a copy holds what `fetchEvents` maps, so such a row would not travel.
- The offer answers are one defaults key each: replacing them is `deleteAll` then one write each, not atomic; a kill in
  between can bring one film offer back once.
- `ProfileRecord.toDomain` fills a missing look and reads a missing partner answer as yes: a copy carries what the app
  shows, so a V3- or V5-era row comes back with those values written.

## Web text

**`web/privacy/index.html`**
- In "What the app keeps on your iPhone", the paragraph's first sentence becomes: "This data is stored only in the
  app's own storage on your device, protected by iOS, unless you save a copy of your saga (see below)."
- New section `<h2>Copies of your saga</h2>` after it, before "Camera and photos", in three paragraphs:
  > In Settings › Copy of your saga you can save your saga as one file. It holds your hero and
  > look, your children's names, gender, skin tone and birth dates, whether you have a partner, every entry with its
  > date, notes and photos, your wardrobe and titles, and the film offers you answered. Your appearance and haptics
  > preferences, the weekly reminder and your film choices stay with the iPhone and aren't in it.
  >
  > The app makes the file on your iPhone, and you choose where it goes with the iOS share sheet: Files, AirDrop or
  > another app, under that place's terms. Nothing is sent to us. The file has no password, so anyone who has it can
  > open it: keep it where you'd keep your photos. The app deletes its own temporary copy of the file when you close
  > Settings.
  >
  > Restoring a copy, from the same page or from the first screen after installing, reads only the file you pick and
  > replaces everything the app keeps on that iPhone with what the copy holds.
- "Deleting your data", at the end: "Start over doesn't delete copies of your saga you saved: delete those files where
  you keep them."

**`web/el/privacy/index.html`**
- «Τα δεδομένα αυτά αποθηκεύονται μόνο στον χώρο της εφαρμογής στη συσκευή σου και τα προστατεύει το iOS, εκτός αν
  αποθηκεύσεις αντίγραφο της saga σου (δες παρακάτω).»
- New section `<h2>Αντίγραφα της saga σου</h2>` after it, before «Κάμερα και φωτογραφίες», in three paragraphs:
  > Στις Ρυθμίσεις › Αντίγραφο της ιστορίας σου μπορείς να αποθηκεύσεις τη saga σου ως ένα αρχείο. Περιέχει τον ήρωα
  > και το στυλ σου, τα ονόματα, το φύλο, τον τόνο δέρματος και τις ημερομηνίες γέννησης των παιδιών σου, αν έχεις
  > σύντροφο, κάθε καταχώριση με την ημερομηνία, τις σημειώσεις και τις φωτογραφίες της, τη γκαρνταρόμπα και τους
  > τίτλους σου, και τις προτάσεις ταινίας που απάντησες. Οι προτιμήσεις εμφάνισης και δόνησης, η εβδομαδιαία
  > υπενθύμιση και οι επιλογές της ταινίας μένουν στο iPhone και δεν περιλαμβάνονται.
  >
  > Η εφαρμογή φτιάχνει το αρχείο στο iPhone σου και εσύ διαλέγεις πού θα πάει, με το φύλλο κοινοποίησης του iOS: στα
  > Αρχεία, με AirDrop ή σε άλλη εφαρμογή, με τους όρους εκείνης. Τίποτα δεν έρχεται σε εμάς. Το αρχείο δεν έχει
  > κωδικό, οπότε όποιος το έχει μπορεί να το ανοίξει: κράτα το εκεί που θα κρατούσες τις φωτογραφίες σου. Η εφαρμογή
  > σβήνει το δικό της προσωρινό αντίγραφο του αρχείου όταν κλείνεις τις Ρυθμίσεις.
  >
  > Η επαναφορά ενός αντιγράφου, από την ίδια σελίδα ή από την πρώτη οθόνη μετά την εγκατάσταση, διαβάζει μόνο το
  > αρχείο που διαλέγεις και αντικαθιστά ό,τι κρατάει η εφαρμογή σε εκείνο το iPhone με όσα περιέχει το αντίγραφο.
- «Διαγραφή των δεδομένων σου», at the end: «Το «Ξεκίνα από την αρχή» δεν σβήνει τα αντίγραφα της saga σου που
  αποθήκευσες: σβήσ' τα από εκεί που τα κρατάς.»

**`web/support/index.html`**
- "How do I move my saga to a new iPhone?":
  > Save a copy: on your iPhone, open Settings › Copy of your saga › Make a copy, then Save or send, and send it to the
  > new iPhone with AirDrop or keep it in Files. On the new iPhone, install DadSaga and tap Restore from a copy on the
  > first screen. *[Only if the device test passes:]* An iCloud Backup or Quick Start brings DadSaga along too, as any
  > app. DadSaga doesn't sync between devices yet.
- New question after it, "How do I keep a copy of my saga?":
  > Open Settings › Copy of your saga › Make a copy, then Save or send. The copy is one file with your family, your hero
  > and every entry, with its notes and photos. Keep it somewhere other than your iPhone, such as iCloud Drive in Files
  > or a computer. To bring it back, choose Restore from a copy on the same page: it replaces the saga on that iPhone.
- "How do I delete everything?", at the end: "Copies of your saga you saved stay where you keep them."

**`web/el/support/index.html`**
- «Πώς μεταφέρω τη saga μου σε νέο iPhone;»:
  > Αποθήκευσε ένα αντίγραφο: στο iPhone σου άνοιξε Ρυθμίσεις › Αντίγραφο της ιστορίας σου › Φτιάξε αντίγραφο, μετά
  > Αποθήκευση ή αποστολή, και στείλ' το στο νέο iPhone με AirDrop ή κράτα το στα Αρχεία. Στο νέο iPhone εγκατάστησε
  > το DadSaga και πάτα Επαναφορά από αντίγραφο στην πρώτη οθόνη. *[Μόνο αν περάσει ο έλεγχος:]* Το iCloud Backup ή η
  > Γρήγορη έναρξη μεταφέρουν κι αυτά το DadSaga, όπως κάθε εφαρμογή. Το DadSaga δεν συγχρονίζει ακόμα μεταξύ
  > συσκευών.
- New question «Πώς κρατάω αντίγραφο της saga μου;»:
  > Άνοιξε Ρυθμίσεις › Αντίγραφο της ιστορίας σου › Φτιάξε αντίγραφο, μετά Αποθήκευση ή αποστολή. Το αντίγραφο είναι
  > ένα αρχείο με την οικογένεια, τον ήρωα και κάθε καταχώριση, με τις σημειώσεις και τις φωτογραφίες της. Κράτα το
  > κάπου εκτός από το iPhone σου, όπως στο iCloud Drive στα Αρχεία ή σε έναν υπολογιστή. Για να το φέρεις πίσω,
  > διάλεξε Επαναφορά από αντίγραφο στην ίδια σελίδα: αντικαθιστά τη saga σε εκείνο το iPhone.
- «Πώς τα σβήνω όλα;», at the end: «Τα αντίγραφα της saga σου που αποθήκευσες μένουν εκεί που τα κρατάς.»

The manifests (`App/Resources/PrivacyInfo.xcprivacy`, `Widget/PrivacyInfo.xcprivacy`) and the App Store label don't
change (ADR-0057 §9).

## Proposed addition to `.claude/rules/domain-and-data.md` (for the owner to add)
- The saga copy's format versions are read forever: a released format's DTOs never change, and
  `Tests/DataTests/Fixtures/SagaCopyV<n>` is never regenerated. A new stored property or enum case is a new format
  version in the same PR (ADR-0057 §4).

## Questions for the owner
1. **Container:** Apple Archive (recommended: Apple's own, streaming, no code of ours for the container, opens on a Mac
   with `aa`), or ZIP, which a Windows PC can open but needs code of our own (with ZIP64) or a dependency?
2. **No password on the file** (recommended)? A password protects a lost file but loses the copy if forgotten.
3. **What travels:** the reminder, appearance, haptics and film choices stay with the iPhone; the film offers answered
   travel. Agreed?
4. **Restore on onboarding's first screen** (recommended: it is the way back on a new iPhone without a backup)?
5. **"Open with DadSaga"** (tapping a `.dadsaga` file) in v1.x, not v1 (recommended)?
6. **Placement:** a "Your saga" section with one page (recommended), or two rows in "Hero & family"?
7. **The file name** `DadSaga 2027-03-12.dadsaga`, with no names in it (recommended: file names show in AirDrop and
   Files)?
8. **No free-space check** before writing (recommended: a full disk already fails safely, and the check is a
   required-reason API)?
9. **The size shown** when a copy is ready ("· 412 MB")?
10. **iCloud Backup wording:** the support page keeps "iCloud Backup or Quick Start" only if the device test shows App
    Group data comes back; if it doesn't, the privacy page's sentence about backups changes too.
11. **Wording:** `content` writes the final el and en text; is «Αντίγραφο της ιστορίας σου» the right name for the
    page, next to the web pages' «saga»?
