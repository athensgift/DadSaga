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

## Phase 2: Core loop
- Onboarding: child (name, birth date) and dad avatar
- Persistence (SwiftData) for child, progress events, photos (on device)
- World map with age-based unlocking
- Quest completion with photo/note → XP → level up
- Boss fights with guide + badge
- Legendary moments: capture firsts with photos, gold cards, companion traits
- Timeline of memories

*Demonstrates:* end-to-end features, state management, persistence, tests.

## Phase 3: Polish
- Level-up / legendary / unlock animations + haptics
- Home-screen widget (weekly quest + latest legendary moment)
- Gentle local notifications (max one a week)
- Accessibility (Dynamic Type, VoiceOver, contrast), full el/en localization
- Snapshot / UI tests

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
- iCloud sync, partner co-op, Android (native or KMP), AI quest suggestions, worlds for ages 2–4, New Game+
