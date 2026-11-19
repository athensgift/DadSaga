# Roadmap

Each phase lists what gets built and what it demonstrates. Done work is described in its ADR.

## Phase 1: Foundations ✅
Clean Architecture package, XcodeGen, CI, SwiftLint, tests per layer, bilingual content as data (ADR-0002–0007).

*Demonstrates:* architecture and testability before the first real screen.

## Phase 2: Core loop ✅
Onboarding and families, SwiftData persistence, quests → XP → levels, boss fights, legendary moments with photos,
child avatars, hero gear and wardrobe, world map, timeline, Liquid Glass and adaptive layout (ADR-0008–0019).

*Demonstrates:* end-to-end features, state management, persistence, tests.

## Phase 3: Polish
- ✅ Card tips, evergreen cards, undo, journal on every card (ADR-0020–0022)
- ✅ Celebration animations + haptics
- ✅ Home-screen widget (ADR-0023), weekly notification (ADR-0024), app icon and launch screen (ADR-0025)
- ✅ Versioned on-device store with a calm "couldn't open" screen (ADR-0026)
- ✅ el/en String Catalog (ADR-0027); screen queries and the `HeroArt` target (ADR-0028); hero looks in the content
  (ADR-0029)
- Accessibility (Dynamic Type, VoiceOver, contrast)
- Snapshot / UI tests

### Open items from the 2026-11 architecture review
- Check on a device: the "couldn't open your saga" screen (junk store file), installing over a `develop` build, every
  screen and the widget in Greek and English, photos loading at their shown size.
- Before the first schema V2 ships: a test that the widget opening an older store read-only fails without touching it
  (ADR-0026).
- Sync ADR before Phase 5: CKSyncEngine over the event log, V2 schema (non-optional `childID` column, `#Unique` ids),
  photos, export/backup (ADR-0004, ADR-0026).
- Measure with Instruments whether the `@ModelActor` repositories run off the main thread.
- CI runs on an unpinned `macos-latest`.

*Demonstrates:* platform depth and product quality.

## Phase 3½: Saga video
- On-device video generation with AVFoundation (`AVMutableComposition`, Core Animation overlays)
- Ken Burns photos, title cards per first, bundled royalty-free music, end "credits"
- Triggers: birthday, world completed, on demand
- Export/share in 9:16 and 16:9

*Demonstrates:* media composition, which few mobile engineers have done.

## Phase 4: Ship
- TestFlight / App Store, demo video (made by the app itself), case study write-up

## Phase 5: Playground
- iCloud sync, partner co-op, Android (native or KMP), AI quest suggestions, New Game+
- Worlds for ages 6+: drafted and parked. The JSON texts were added in `3b0f712` and removed in `61e0aef`; the plan
  (`docs/content-plan-6-plus.md`) is in git history up to `61e0aef`.
