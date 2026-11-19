# ADR-0028: One query per screen, one way to record progress, and the hero art in its own target

**Status:** Accepted (2026-11-19). Follows an architecture review of the whole package. Moves the avatar out of
`DesignSystem`, where ADR-0008 put it.

## Context
- `HomeViewModel.load()` called five use cases one after another (profile, catalog, adventure, progress, outfit) and
  then applied Domain rules itself: `UnlockRules.quests` for the shown world, bosses filtered by world,
  `GearRules.equipped`, and `GearRules.newlyEarned` for the celebration. It kept Domain state (`quests`, `bosses`,
  `gear`, a `HomeSnapshot`). `WardrobeViewModel` did the same with four use cases and decided itself which items could
  be worn. The rules for "what home shows" were reachable only through presenter tests, and the catalog and the event log
  were read several times per load.
- `CompleteQuest`, `DefeatBoss` and `CaptureMoment` each repeated the same steps: check the content exists, read the
  events, record, build the before and after progress. `CaptureMoment` built its `EventRecorder` differently.
- "A boss or a first counts once per child" was a read followed by a write. Two saves at the same moment (only the
  presenter's `isCompleting` stopped them) could both store an event. `Timeline` hid the duplicate from XP, but it kept
  its photo and would come back if the first entry was deleted. Sync and co-op would make this likely.
- `DesignSystem` said "No business knowledge" but held about 2,000 lines of hero and child drawing that switch on the
  game's hero classes and gear.

## Decision

### 1. A screen reads through one query use case
- `GetHomeOverviewUseCase.execute(childID:worldID:on:)` returns a `HomeOverview`: the profile, the chosen child (first
  child as fallback), catalog, `Adventure`, `DadProgress`, the shown world (a chosen unlocked world, else the current
  one), its quests and bosses, and the equipped gear. `nil` while there is no family.
- `HomeOverview`'s initializer derives the shown world, quests, bosses and gear, so test doubles that build one get the
  same rules as the app.
- `Adventure` is built by an initializer (`Adventure(for:childCount:catalog:on:calendar:)`), not a use case.
- `GetWardrobeUseCase` returns a `Wardrobe` (profile, all gear, progress, outfit, `equipped`, `isEarned`).
  `SetOutfitChoiceUseCase` refuses an item that is not earned in that slot (`OutfitError.notEarned`). The presenter still
  ignores taps on locked items, so they do nothing on screen instead of showing an error.
- The query use cases start their repository reads in parallel (`async let`). They are separate reads, not a snapshot.
- Removed: `GetAdventureUseCase`, `GetProgressUseCase`, `GetOutfitUseCase`, `HomeSnapshot`. Presenters still map
  Application types to display models; they no longer call Domain rules.

### 2. One way to record progress
- `ProgressRecorder` (internal to Application) checks `ContentCatalog.contains(kind)`, records, and returns a
  `ProgressChange`. The three use cases are thin wrappers that pass their own "unknown content" error.
- `ProgressChange` carries `newGear`, computed when it is made, so the celebration does not run gear rules.
- The once-per-child rule is `ProgressEvent.Kind.countsOncePerChild` in the Domain. `Timeline` uses it too.

### 3. "Once per child" is enforced where the data is
- `ProgressRepository.addUnlessRecorded(_:) -> Bool` checks and inserts in one step. The SwiftData actor does both
  without suspending in between, so two calls cannot both insert.
- `ProgressRecorder` first checks the progress it has already read (`DadProgress.isAlreadyCounted`), so the usual
  repeat stops before any photo is written. `addUnlessRecorded` catches two saves at the same moment. In that case
  `EventRecorder` deletes the photo it just saved.
- A boss already defeated still returns a change with no `eventID`. A first already captured still throws
  `alreadyCaptured`.

### 4. A wardrobe change writes one slot
- `OutfitRepository.save(_:)` is replaced by `setChoice(_:for:) -> Outfit`. It changes one slot and reads the outfit back
  in one step, so changes to two slots at once never overwrite each other.
- The wardrobe presenter applies and reverts only the slot it changed, so a late reply never undoes a newer tap.

### 5. The hero art is its own target
- New package target `HeroArt` (depends on `DesignSystem`): `HeroAvatar`, `ChildAvatar`, `AvatarSkin`, hero gear,
  items and outfits. Presentation depends on it. The widget doesn't draw avatars and doesn't link it.
- `DesignSystem` keeps tokens and generic components. The sparkle shape moved there as `Sparkle`, because
  `CelebrationBurst` uses it.
- `Color(light:dark:)` is `package`, so the art can define its own fixed palette. Screens still use `DSColor`.
- `Tools/LaunchLogo` imports `HeroArt`.

## Consequences
- Presenters are smaller and test only display. The rules for what home shows have Application tests
  (`HomeOverviewUseCaseTests`).
- A new screen that needs several repositories gets its own query use case rather than several small getters.
- A future sync layer must keep `addUnlessRecorded`'s guarantee, for example by merging duplicates by
  (child, kind, content).
- Changing the art no longer rebuilds what depends only on the tokens.
