# ADR-0034: Screen snapshots, a pinned CI toolchain, and where the store's work runs

**Status:** Accepted (2026-11-19). The owner asked to close Phase 3, chose swift-snapshot-testing for the snapshot
tests, and chose to run them on the Mac, not in CI. Closes the Phase 3 open items "Snapshot / UI tests", "CI runs on an unpinned `macos-latest`", "measure whether
the `@ModelActor` repositories run off the main thread", and the widget test ADR-0026 asks for before the first V2.

## Context
- Nothing showed what a screen looks like. The accessibility audit (ADR-0033) checks labels, contrast and hit regions
  at the default text size only; the largest sizes were checked by hand, once.
- CI ran on `macos-latest`, which had moved to Xcode 26.6 while the Mac builds with Xcode 27.2. Images drawn by two
  different toolchains never match.
- ADR-0026: only the app migrates; the widget opens the store read-only. Nothing showed what the widget does when it
  meets a store from before a migration, which happens after every update with a new schema, until the app is opened.
- Whether the store's fetches and saves ran on the main thread had never been measured.

## Decision
1. **`DadSagaSnapshotTests`, an iOS test target with [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)**
   (1.19.7, exact). The project's first third-party dependency, linked by this test target only, never by the app, the
   widget or `DadSagaKit`. It draws onboarding, home, the wardrobe, the timeline and settings, each in Greek and light
   mode, in English and dark mode, and in English at the largest accessibility text size: 15 images in
   `SnapshotTests/__Snapshots__`, committed.
2. **The screens are drawn from a fixed saga** (`SagaFixture`): the real content, a store in memory, 15 June 2026 at
   noon, a four-month-old, three quests, two firsts. View models get the locale and the clock passed in, the way
   `AppContainer` builds them otherwise. They run from their own scheme, `DadSagaSnapshots`, whose test action
   launches the app with region en_US and time zone UTC: iOS formats the date picker by the simulator's region, which
   is the Mac's (en_GR here) locally and en_US on CI. The other schemes, and Run, keep the device's. Each view model
   is loaded before its screen is drawn.
   The images are 390 × 844 pt, whatever the simulator's size.
3. **Hosted by the app, in its window.** Liquid Glass (buttons, the toolbar, home's cards) is drawn only in a real
   window; without a host, home and onboarding came out empty. While XCTest is injected into it, the app runs on the
   test data of ADR-0033 (`DeviceData`, debug builds only), so the host never opens a saga of its own. The test bundle
   links no `DadSagaKit` product and uses the app's (`BUNDLE_LOADER`): linked twice, each module had two copies, and
   an environment value set from the test's copy of `HeroArt` was never read by the app's `Presentation`.
4. **Still pictures:** `EnvironmentValues.avatarsAreStill` (HeroArt) draws the hero and the children at rest and
   already in place, as Reduce Motion does for the idling (which SwiftUI does not let a test set). The snapshots also
   turn animations off, and run one at a time in the one window. The new image goes through PNG before it is compared, like the
   reference (`savedScreen`): compared straight from memory, its other pixel format made the library count a few
   hundred pixels one level apart as 1–15 % of pixels changed, most of all on CI's virtual GPU. Through PNG, Liquid
   Glass's run-to-run noise is under 250 pixels, at most three levels in 255. Tolerance: 99.9 % of pixels, 98 %
   perceptual; renaming the child from "Alex" to "Alexa" fails home in all three looks.
5. **CI is pinned, and the snapshots run on the Mac only.** CI runs on the `xcode-27` image with `DEVELOPER_DIR` on
   Xcode 27.2, the Mac's. The snapshots ran in CI at first and took it from about 4 to about 15 minutes, nearly all of
   it a second build and a simulator boot; the owner chose to keep CI fast and run them on the Mac whenever a change
   touches the UI or the content (`CLAUDE.md`), on an iPhone 17 with iOS 27.2. Moving to a new Xcode means moving the
   image and `DEVELOPER_DIR` together, and re-recording the snapshots. The
   accessibility audit stays on the iOS 26.0 simulator it was tuned on: on iOS 27.2, three glass buttons fail its
   contrast check, which is its own piece of work.
6. **The widget before a migration is tested now:** the store can be opened at any version (`StoreVersions`), and a
   test-only `SchemaV2Draft` stands in for the first V2. Opening a version 1 store read-only at version 2 throws and
   leaves the database and its write-ahead log byte for byte as they were, while the app that wrote it still has it
   open (closing it moves the log into the database); the app then migrates it and the widget reads it. SQLite rewrites the `-shm` file, its index of the log, on every open, read-only ones too: it holds no
   saga and is not compared. When V2 ships, the tests use the real plan.
7. **The store's work runs off the main thread, now by design.** Measured: a `@ModelActor` runs a call on the thread
   that sends it, so called from the main actor it fetches on the main thread. Screens reach it through the
   `Connected…` repositories, whose `nonisolated async` methods left the main actor first, so the work ran off it, but
   only because of the compiler's default: with Swift 6.2's `nonisolated(nonsending)` default (Xcode's for new
   projects) it moved onto the main thread. Those methods are now `@concurrent`.

## Consequences
- A change to how a screen looks fails the snapshots until its new images are recorded and committed; review sees the
  images. Only if they are run: CI does not, so it is a habit, like the accessibility audit, not a gate.
- Content edits (titles, taglines, XP) change the images too.
- Snapshots need Xcode 27.2 and the iOS 27.2 simulator. On another Xcode they fail by design; re-record on the new
  pair. They were stable in CI too once compared through PNG and on a region of their own, so moving them back is one
  step in `ci.yml`.
- The `xcode-27` runner image is still a preview on GitHub, and an image keeps only the newest patch of each Xcode:
  when 27.2.1 arrives, `/Applications/Xcode_27.2.app` goes and CI fails until the pin moves.
- swift-snapshot-testing is pinned exactly; its own dependencies (swift-custom-dump, swift-issue-reporting,
  swift-syntax) are resolved on every CI run, since the generated project and its `Package.resolved` are not kept.
- Not covered by snapshots: the quest, boss and moment sheets, the world map, the settings pages, and the timeline with
  photos. The accessibility audit still runs by hand, not in CI.
