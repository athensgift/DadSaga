# DadSaga

Personal portfolio / playground project. Replies to the owner are in Greek.

## Commands (Done = green)
```bash
swiftlint --strict
(cd Packages/DadSagaKit && swift test --build-system swiftbuild)
xcodegen generate && xcodebuild build -project DadSaga.xcodeproj -scheme DadSaga \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```
- One suite: `swift test --build-system swiftbuild --filter DeepLinkTests` (from `Packages/DadSagaKit`).
- **Paused until the big features are done** (owner, 2026-11-20): screen snapshots and the accessibility audit are not
  run during development. Once the work is close to final, run both, re-record the snapshots and look at every image,
  then put the snapshots back in CI. Until then, check a UI change by drawing it once in the simulator.
  - Screen snapshots: `xcodebuild test -project DadSaga.xcodeproj -scheme DadSagaSnapshots -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.2'`.
    A deliberate change: delete its images in `SnapshotTests/__Snapshots__`, run twice (record, then check).
  - Accessibility audit of the main screens (UI test, about five minutes):
    `xcodebuild test -project DadSaga.xcodeproj -scheme DadSaga -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.2' -only-testing:DadSagaUITests`
- While iterating, run only the suite you're changing (`--filter`); run the whole package once before the PR.
- `DadSaga.xcodeproj`, `Info.plist` and the entitlements are generated: change `project.yml`, then `xcodegen generate`.

## Rules that aren't in the code
- The product rules in [ADR-0006](docs/adr/0006-no-pressure-game-design.md) are non-negotiable: XP for the dad's actions
  only, no penalties, no streaks, no milestone deadlines.
- Game content is JSON in `Packages/DadSagaKit/Sources/Data/Resources`, in `el` and `en`. Never hardcode it in Swift.
- A new feature goes Domain → Application (use case protocol + `Default…`) → Data → Presentation (ViewModel + ViewState +
  View) → `App/DI/AppContainer.swift` ([ADR-0007](docs/adr/0007-clean-architecture.md)).
- Before a feature or a design question, check the [ADR index](docs/adr/README.md) for the ADRs on that topic.
- Record a significant decision as a new ADR in `docs/adr/`. Accepted ADRs aren't rewritten; a new one supersedes them.
  Add its row to the index, and note it under "Changed by" on any ADR it changes.

## Engineering habits
- Subtract before you add: when new code covers an old path, delete the old path in the same change.
- Fix root causes: reproduce the bug in a test first, then fix the cause. A guard that hides the symptom is not a fix.
- Redesign, don't bolt on: for a new requirement, ask what you would have built had it been there from the start.

## Subagents
- A change across layers, or one touching persistence, sync, media or the film: `architect` plans first. A change in
  one layer only (a UI tweak, copy) skips the plan.
- `reviewer` checks every PR before it is opened, small ones too: it finds the most.
- If a fix fails twice, stop and suggest `fable-hard`. It costs usage credits: never start it until the owner asks.

## Git
Gitflow ([ADR-0009](docs/adr/0009-gitflow.md)): `feature/<name>` from `develop`, PR back into `develop`.
- Work that touches the same files goes in one PR rather than several (e.g. the data model in one, all its UI in the next).
- Several sessions at once: each works in its own git worktree, never in another session's checkout, which may switch
  branch under it.
