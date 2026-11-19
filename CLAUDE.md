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
- Accessibility audit of the main screens (UI test, about a minute; run it after UI changes):
  `xcodebuild test -project DadSaga.xcodeproj -scheme DadSaga -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
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
- A new feature: `architect` plans, the main session implements, `reviewer` checks, then the PR.
- If a fix fails twice, stop and suggest `fable-hard`. It costs usage credits: never start it until the owner asks.

## Git
Gitflow ([ADR-0009](docs/adr/0009-gitflow.md)): `feature/<name>` from `develop`, PR back into `develop`.
