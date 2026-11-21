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
  (ADR-0043); open and upright, home keeps those two panes (ADR-0045). Checked on a real iPhone Duo (2026-11-21), also in
  Split View, at the accessibility text sizes and with VoiceOver

### Open items from the 2026-11 architecture review
- ✅ Checked on a device (2026-11-19): installing over a `develop` build, every screen and the widget in Greek and
  English, photos loading at their shown size.
- The "couldn't open your saga" screen (junk store file) is covered by tests (`StoreVersioningTests`,
  `StoreUnavailableRootTests`), not checked on a device: it needs a damaged store, which is unlikely in practice.
- ✅ The widget opening an older store read-only fails without touching it, tested with a draft V2 (ADR-0034).
- Sync ADR before Phase 5: CKSyncEngine over the event log, V2 schema (non-optional `childID` column, `#Unique` ids),
  photos, export/backup (ADR-0004, ADR-0026).
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
  preview before choosing, never on its own; the last choice remembered
- ✅ Vision on the device chooses and frames the film's photos (ADR-0047): an entry's best further photos, not the first
  ones; the glide aims at the children's faces before the adults', closing in on them up to 1.4
- ✅ Checked on an iPhone (2026-11-21): a 90-second film (time, memory, heat), leaving the app and locking the screen
  mid-film, "Save Video" asking for Photos in el and en, Messages and AirDrop, VoiceOver on the sheet

*Demonstrates:* media composition, which few mobile engineers have done.

## Phase 4: Ship
- TestFlight / App Store, demo video (made by the app itself), case study write-up
- ✅ Dad titles instead of levels: no XP on screen, gear by title, a calm title card, the title in the film (ADR-0055)
- ✅ Privacy manifests, export compliance key, privacy URL, Release build in CI (ADR-0051, `docs/RELEASE.md`)
- Team ID in `project.yml`, App Store Connect record, trader details (EU DSA)
- Restore from an iCloud backup tested on a device: it decides whether export ships in v1 or v1.1
- Export and restore of the saga
- Screen snapshots and the accessibility audit run again and re-recorded
- App Store metadata in Greek and English, screenshots, age rating
- Pricing decision (free; a one-time unlock later?), with its own ADR

## Phase 5: Playground
- iCloud sync, partner co-op, Android (native or KMP), AI quest suggestions, New Game+
- Worlds for ages 6+: drafted and parked. The JSON texts were added in `3b0f712` and removed in `61e0aef`; the plan
  (`docs/content-plan-6-plus.md`) is in git history up to `61e0aef`.
