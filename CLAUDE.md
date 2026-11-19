# DadSaga: personal project

This is a **personal portfolio / playground project**. Replies to the owner are in Greek.

## Conventions
- Swift 6, strict concurrency, iOS 26+. Modern stack: SwiftUI, Observation, async/await, SwiftData.
- 4-space indentation, 130 columns, no force-unwrap / `try!` / `as!`.
- **Clean Architecture** ([ADR-0007](docs/adr/0007-clean-architecture.md)), one SwiftPM target per layer:
  `Domain` (entities + rules, imports only Foundation) ← `Application` (use cases + repository protocols)
  ← `Data` (repository impls, DTOs, mappers) / `Presentation` (ViewModels + views). Data and Presentation never import each other.
  The full target map is in `README.md`.
- New feature flow: entity/rule in Domain → use case (protocol + `Default…`) and any repository protocol in Application
  → repository impl in Data → ViewModel + ViewState + View in Presentation → wire it in `App/DI/AppContainer.swift`.
- ViewModels are `@MainActor @Observable`, don't import SwiftUI, and expose display models only (no Domain types in views).
- Domain entities are not `Codable`. Persistence/wire formats use DTOs in Data.
- Colours, spacing and fonts only via `DesignSystem` tokens (`DSColor`, `DSSpacing`, `DSFont`).
- Game content is JSON in `Sources/Data/Resources`, bilingual (`el` + `en`). Don't hardcode it in Swift.
- UI text: `strings.text("English text")` plus an entry with `el` and `en` (state `translated`, `extractionState: manual`)
  in `Sources/Localization/Resources/Localizable.xcstrings`; plurals as catalog variations (ADR-0027).
- Tests use Swift Testing with Given/When/Then names.
- Record significant decisions as a new ADR in `docs/adr/`.
- Product rules in `docs/adr/0006-no-pressure-game-design.md` are non-negotiable (no penalties, no milestone deadlines).

## Engineering habits
- Subtract before you add: when new code covers an old path, delete the old path in the same change.
- Fix root causes: reproduce the bug in a test first, then fix the cause. A guard that hides the symptom is not a fix.
- Test behaviour, not implementation: call the code the way the screen does and check what the user would see.
  If a test would still pass with every function returning nothing, rewrite it.
- Redesign, don't bolt on: for a new requirement, ask what you would have built had it been there from the start.

## Subagents (`.claude/agents/`)
- A new feature: `architect` plans, the main session implements, `reviewer` checks, then the PR.
- `fable-hard` costs usage credits on the Pro plan. Never start it on your own: suggest it, say why, and wait for the owner.
- If a fix fails twice in the main session, stop and suggest `fable-hard` instead of trying a third time.

## Git
- Commit and push only when asked.
- **Gitflow** ([ADR-0009](docs/adr/0009-gitflow.md)): `develop` is the integration branch, `main` holds releases only.
  - `feature/<name>` branches from `develop` and merges back into `develop` through a PR.
  - `release/<version>` branches from `develop`, then merges into `main` (tagged `v<version>`) and back into `develop`.
  - `hotfix/<name>` branches from `main`, then merges into `main` (tagged) and into `develop`.
  - Never commit directly to `main` or `develop`.

## Done = green
```bash
swiftlint --strict
(cd Packages/DadSagaKit && swift test --build-system swiftbuild)
xcodegen generate && xcodebuild build -project DadSaga.xcodeproj -scheme DadSaga \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```
