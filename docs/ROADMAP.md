# Roadmap

Each phase lists what gets built and what it demonstrates. Done work is described in its ADR.

## Phase 1: Foundations ✅
Clean Architecture package, XcodeGen, CI, SwiftLint, tests per layer, bilingual content as data (ADR-0002–0007).

*Demonstrates:* architecture and testability before the first real screen.

## Phase 2: Core loop ✅
Onboarding and families, SwiftData persistence, quests → XP → levels, boss fights, legendary moments with photos,
child avatars, hero gear and wardrobe, world map, timeline, Liquid Glass and adaptive layout (ADR-0008–0019).

*Demonstrates:* end-to-end features, state management, persistence, tests.

## Phase 3: Polish ✅
- ✅ Card tips, evergreen cards, undo, journal on every card (ADR-0020–0022)
- ✅ Celebration animations + haptics
- ✅ Home-screen widget (ADR-0023), weekly notification (ADR-0024), app icon and launch screen (ADR-0025)
- ✅ Versioned on-device store with a calm "couldn't open" screen (ADR-0026)
- ✅ el/en String Catalog (ADR-0027); screen queries and the `HeroArt` target (ADR-0028); hero looks in the content
  (ADR-0029)
- ✅ Settings: language, appearance, haptics, reminder, hero and family, contact, about, start over (ADR-0030)
- ✅ Accessibility: Dynamic Type, readable tints and secondary text, an accessibility audit of the main screens
  (ADR-0032, ADR-0033)
- ✅ Snapshot / UI tests: the accessibility audit (ADR-0033) and screen snapshots (ADR-0034), both run on the Mac
- ✅ iPhone Duo half-open like a laptop: home, the saga film, the note editor, the quest and boss sheets, a first's
  page, the wardrobe and the timeline put what the dad looks at above the fold and what he touches below it
  (ADR-0043). Checked on a real iPhone Duo (2026-11-21), also in Split View, at the accessibility text sizes and with
  VoiceOver. The map and Settings are tabs and split at the fold too (ADR-0061). Half-open on its side, home is two
  columns; open flat, upright or on its side, and on iPads, home is one column where the hero and the cards scroll
  together (ADR-0066, drawn in the simulator; not yet checked on the device)

### Open items from the 2026-11 architecture review
- ✅ Checked on a device (2026-11-19): installing over a `develop` build, every screen and the widget in Greek and
  English, photos loading at their shown size.
- ✅ The "couldn't open your saga" screen (junk store file): tests (`StoreVersioningTests`,
  `StoreUnavailableRootTests`) and checked on a device (2026-11-22). A store that can't be opened is a row with nil in a
  column `SchemaV1` requires, or a junk file; a `develop` store whose profile was saved since version 6 migrates
  silently instead (ADR-0060 §6, "Verification status").
- ✅ The widget opening an older store read-only fails without touching it, tested from a test-only older schema
  (`OlderStoreTests`, ADR-0060). The first `SchemaV2` adds the test from the `StoreV1` fixture the first App Store
  release writes.
- iCloud and partner co-op: designed in ADR-0065. ✅ Its PR 1 (a profile id, the entries' authors, a
  child's `isRemoved` and `#Unique` ids in `SchemaV1`, and the same in a copy), before the first App Store release
  branch. ✅ PR 2 (two players, every change says what changed) and ✅ PR 3 (removed children: removing marks,
  "Bring back" and "Delete for good" in My family, visible to a dad alone). 1.0 ships every part that doesn't touch
  iCloud (ADR-0067): PRs 1 to 3, and ✅ PR 4, the sync core (the change feed, the applier, the coordinator,
  `Sync.store`'s schema, tested against a fake cloud; ADR-0068, and ADR-0069 for what it left open), wired to nothing
  but the history trim at launch (ADR-0081). The
  co-op version is PR 5 (CloudKit) and PR 6
  (the iCloud and sharing screens), in Phase 5.
- ✅ The store's work runs off the main thread, now whatever the compiler's default (ADR-0034).
- ✅ CI pinned to Xcode 27.2 (ADR-0034).

*Demonstrates:* platform depth and product quality.

## Phase 3½: Saga video (ADR-0036) ✅
- ✅ What goes in a film and when to offer it (Domain); the film's one query (Application)
- ✅ An original theme made in code (`Tools/SagaMusic`), bundled in the `SagaMusic` target
- ✅ `FilmKit`: on-device video drawn frame by frame (Core Image, `AVAssetWriter`), Ken Burns photos, cross-fades, music
- ✅ Drawing the film (ADR-0037): an opening, a card for each first and boss, a montage of quest photos, credits; Reduce
  Motion keeps the photos still
- ✅ The film sheet (ADR-0037): choose a child, a period and 9:16 or 16:9, watch the film, then share or save it; it is
  never kept, and leaving the app stops it
- ✅ Triggers: on demand from the timeline; on home, one calm card for the family on a birthday or when a child grows
  into the next world (by age, never by quests or bosses done), with the weekly reminder card waiting behind it
- ✅ The dad chooses the film's music (ADR-0046): five original tracks with a mood line each, in el and en; a 20-second
  preview before choosing, never on its own; the last choice remembered. Every track is at least 130 s (ADR-0052; the
  owner confirmed it, and a test checks the bundled content)
- ✅ Vision on the device chooses and frames the film's photos (ADR-0047): an entry's best further photos, not the first
  ones; the glide aims at the children's faces before the adults', closing in on them up to 1.4
- ✅ Checked on an iPhone (2026-11-21): a 90-second film (time, memory, heat), leaving the app and locking the screen
  mid-film, "Save Video" asking for Photos in el and en, Messages and AirDrop, VoiceOver on the sheet

*Demonstrates:* media composition, which few mobile engineers have done.

## Phase 4: Ship
- TestFlight / App Store
- ✅ Demo video of the real app, in English and Greek, from a demo saga kept in `docs/demo`; real screens on the
  website; the case study in the README (ADR-0070)
- ✅ Dad titles instead of levels: no XP on screen, gear by title, a calm title card, the title in the film (ADR-0055)
- ✅ Nothing ships before the first App Store release: one store version, no shipped ids, gear only with titles;
  TestFlight testers start over when the store or an id changes (ADR-0060)
- At the first App Store release: record what ships, its ids and its store (ADR-0060 §5, `docs/RELEASE.md`)
- ✅ Privacy manifests, export compliance key, privacy URL, Release build in CI (ADR-0051, `docs/RELEASE.md`)
- Team ID in `project.yml`, App Store Connect record, trader details (EU DSA): the record waits on the D-U-N-S
  number
- ✅ Export and import of the saga: one `.dadsaga` file from Settings › Export and import, imported there or on
  onboarding's first step (ADR-0057). A v1 requirement; checked on a device with a large saga (2026-11-22)
- Restore from an iCloud backup tested on a device: not tested, and hard for the owner to test. Until it is, the support
  pages (en and el) promise no more than export and import (ADR-0057): ✅ their iCloud Backup / Quick Start sentence
  is out (2026-11-24) and comes back only once the test passes
- Screen snapshots and the accessibility audit run again and re-recorded, with ADR-0042 §7's images and audit, never
  written (`docs/RELEASE.md`)
- ✅ App Store metadata in Greek and English and screenshots (iPhone and both iPhone Duo displays) in `docs/appstore/`;
  the age rating and privacy label go in once the App Store Connect record exists
- ✅ Pricing decision: 1.0 is free, with no in-app purchases; a "buy me a coffee" tip waits until after 1.0 (ADR-0071)

## Left from the review of 2026-11-25
What the whole-app review found that its six fix PRs (from #119) left open, and why it can wait. Not one of them blocks
1.0.

### Sync (the co-op version, not 1.0)
- `Data/Sync` writing a fetched record: nothing holds it to a copy's rules (photo limit, one photo on two entries, a
  blank name), so one bad record would make every export fail. Check in `FieldMerge` before CloudKit is wired.
- `ProfileRecord`: a gender or look this version doesn't know reads as the default and leaves in a copy as it. 1.0
  writes no unknown value; fix with ADR-0065 §9's "say what was left out".
- `SyncCoordinator+Offers`: renaming the film answers after a join deletes them all before writing any; a kill in
  between offers every film again. Mark the new ids first.
- A rebuilt zone sends rows of an unknown kind (ADR-0065 §1 says never); `accountReturned`'s rejoin rule is in no ADR;
  ADR-0069 §3's family with no child can't be copied; "Delete for good" says it is for both parents.
- `ProgressRecorder` stores an entry for a child not in the family; no 1.0 screen reaches it, a remote removal would.
- `FilePhotoStore.adopt` keeps a JPEG's metadata and orientation, so such a photo is sideways in the film only. Only a
  hand-made copy does it today; decide before sync whether to refuse it or decode with the transform.

### Nits
- Data: `storedPhotos()` drops an unreadable file silently, against its comment; a copy has no cap on its total size
  (only a file the dad picks); `UserDefaultsSagaFilmChoicesRepository`'s "a stored switch carries over"; the content
  validator checks less than the bundled-content tests (the shipped JSON is tested).
- Domain and Application: `Wardrobe.isEarned` and `SetOutfitChoiceUseCase` write one rule twice; the weekly highlights
  repeat `PlayerProfile.child(_:)`; `SagaPacing.init`'s ten unused parameters; stale comments in `PhotoStore`,
  `FirstMoment`, `DadAppearance`. None changes behaviour.
- Tests: names that promise XP or "one over" the limit without checking it; no test for `RestoreSagaUseCase.discard`
  with unreadable entries, export's cancellation, Undo with nothing closed; `SagaStoryboardTests`' one-second wall
  clock; `HomeMomentsTests` "counts all firsts"; `NoCloudFamilySyncTests.resumeLeavesAStoreItCannotOpen` passes with an
  empty `resume()`; `SagaCopyLimitsTests` names say more than they assert; `FilmBundledMusicTests` finds tracks by
  `.m4a`, and `Package.swift` still says FilmKit's tests check no content. The behaviour they cover is right.
- Film: the blurred backdrop is drawn again every frame (time on an old phone, unmeasured); `close()` empties the
  whole films folder (not reachable by hand); an interrupted music preview keeps "Stop" for up to 20 s; the sheet
  presenter's logic has no test.
- Screens: only home listens for midnight; "My family" asks to discard after a born box ticked back; every remove
  button reads "Remove child" to VoiceOver; "Couldn't load" without "Try again" in My family, Your hero, Wardrobe;
  "Last time" with no year; raw black and white in the photo viewer; the timeline's load has no generation; segmented
  child pickers don't grow with Dynamic Type. Each is small or rare.
- Cards (the owner's call): the firsts' Greek titles and the tooth fairy; one Greek gender for the partner,
  `b-w4-kindergarten`, `b-w2-velcro`'s "only one of you"; one Greek word each for doctor, cot and week; "Stroller";
  narrow windows (`b-w3-new-sibling`) and conditional quests with no audience; a `medical` footer missing on seven
  quests with a checkable claim; a first dental visit before 30 months.
- Website and privacy pages: Vision also looks for "what stands out", not only faces; the demo video has no pause; the
  Greek site's "Super Dad"; `www.dadsaga.app` doesn't redirect; `docs/demo/README.md`'s picker note.
- App and repository: the camera prompt's "stay on this device" is stricter than the privacy page; no `LICENSE`
  (all rights reserved, the owner's call); the owner's email on public commits; `.gitignore` lacks archives and
  signing files (none tracked); `StoreConnection` logs a store error as `.public` (local log only);
  `SagaCopyDamagedFilesTests` keeps a back-compat reason; ADR-0058 §7 says "large" where home uses `.automatic`.
- CI: the Mac's SwiftLint is older than CI's pinned one; upgrade it.

### Owner checks on a real phone
Done on 2026-11-26 on the owner's iPhone Duo (`docs/RELEASE.md`, "Open device checks", has each with its ADR). Two bugs
were found and fixed in the same PR: a tap on the weekly notification crashed the app, and the shaved head and the short
beard were drawn wrong; both checked again on the phone. Left: the film's time and the child/adult classification on the
oldest iPhone at hand (ADR-0047); the skills' marks in light and dark (ADR-0059); a full disk; restoring an offloaded
app (ADR-0023) and from an iCloud backup, both on the first TestFlight build.

## Phase 5: Playground
- iCloud sync and partner co-op: the co-op version, ADR-0065's PR 5 (CloudKit) and PR 6 (the iCloud and sharing
  screens), on the sync core 1.0 already carries (ADR-0067)
- Android (native or KMP), AI quest suggestions, New Game+
- Worlds for ages 6+: drafted and parked. The JSON texts were added in `3b0f712` and removed in `61e0aef`; the plan
  (`docs/content-plan-6-plus.md`) is in git history up to `61e0aef`.
