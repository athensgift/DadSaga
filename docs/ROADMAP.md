# Roadmap

Each phase lists what gets built and what it demonstrates.

## Phase 1: Foundations ✅
- Clean Architecture package (Domain / Application / Data / Presentation / DesignSystem), XcodeGen, CI, SwiftLint
- Entities, level curve, unlock rules, progress aggregation; use cases; repository + DTO mapping; ViewModel; DI container
- Tests per layer (26)
- Bundled bilingual content (el/en): 2 worlds, 20 quests, 4 bosses, 14 firsts, validated at load time
- Design tokens (light/dark) + `XPBar`, `QuestCard`
- Placeholder content explorer screen

*Demonstrates:* architecture and testability before the first real screen.

## Phase 2: Core loop ✅
- ✅ Onboarding: 1–4 children (name, birth date, gender, skin tone), dad's hero class and skin tone (ADR-0010, 0012)
- ✅ Persistence (SwiftData) for the family and progress events, with migration from the single-child store
- ✅ Quest completion → XP → level up, per child, shared XP
- ✅ Boss fights with survival guide + badge, once per child
- ✅ Liquid Glass redesign, adaptive two-column layout for iPhone Duo and landscape (ADR-0011)
- ✅ Child avatars by age stage next to the dad (ADR-0013)
- ✅ Hero gear from skill XP and boss medals (ADR-0014)
- ✅ Legendary moments: capture firsts per child with date and note, gold cards, companion traits (ADR-0015)
- ✅ Photos on legendary moments (on device), edit and delete moments (ADR-0016)
- ✅ World map with age-based unlocking; earlier worlds replayable; worlds for ages 2–6 (ADR-0019)
- ✅ Timeline of memories across children, in its own tab (ADR-0017)
- ✅ Wardrobe: choose which earned gear the hero wears (ADR-0018)

*Demonstrates:* end-to-end features, state management, persistence, tests.

## Phase 3: Polish
- ✅ Level-up / legendary / unlock animations + haptics
- ✅ Home-screen widget (weekly quest + latest legendary moment, ADR-0023)
- ✅ Gentle local notifications (max one a week, ADR-0024)
- Accessibility (Dynamic Type, VoiceOver, contrast)
- ✅ el/en localization: UI text in one String Catalog, plurals, camera prompt (ADR-0027)
- ✅ Versioned on-device store, calm "couldn't open" screen instead of a silent fallback (ADR-0026)
- Snapshot / UI tests

### Later: left over from the 2026-11 architecture review
- Check on a device: the "couldn't open your saga" screen (junk store file), installing over a `develop` build, every
  screen and the widget in Greek and English, photos loading at their shown size.
- Before the first schema V2 ships: a test that the widget opening an older store read-only fails without touching it
  (ADR-0026).
- Sync ADR before Phase 5: CKSyncEngine over the event log, V2 schema (non-optional `childID` column, `#Unique` ids),
  photos, export/backup (ADR-0004, ADR-0026).
- Hero look enums exist three times (Domain, Presentation, DesignSystem); move them to one SwiftUI-free place and give
  heroes a `look` in the JSON.
- Hero colour tokens still carry old class names (`heroMage`, `heroRanger`, `heroKnightShade`).
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
- iCloud sync, partner co-op, Android (native or KMP), AI quest suggestions, worlds for ages 6+ (planned and drafted in `docs/content-plan-6-plus.md`, parked; the app stays 0–6 for now), New Game+
