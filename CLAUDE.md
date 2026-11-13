# DadSaga: personal project

This is a **personal portfolio / playground project**. Replies to the owner are in Greek.

## Conventions
- Swift 6, strict concurrency, iOS 26+. Modern stack: SwiftUI, Observation, async/await, SwiftData.
- 4-space indentation, 130 columns, no force-unwrap / `try!` / `as!`.
- **Clean Architecture** ([ADR-0007](docs/adr/0007-clean-architecture.md)), one SwiftPM target per layer:
  `Domain` (entities + rules, imports only Foundation) ← `Application` (use cases + repository protocols)
  ← `Data` (repository impls, DTOs, mappers) / `Presentation` (ViewModels + views). Data and Presentation never import each other.
- New feature flow: entity/rule in Domain → use case (protocol + `Default…`) and any repository protocol in Application
  → repository impl in Data → ViewModel + ViewState + View in Presentation → wire it in `App/DI/AppContainer.swift`.
- ViewModels are `@MainActor @Observable`, don't import SwiftUI, and expose display models only (no Domain types in views).
- Domain entities are not `Codable`. Persistence/wire formats use DTOs in Data.
- Colours, spacing and fonts only via `DesignSystem` tokens (`DSColor`, `DSSpacing`, `DSFont`).
- Game content is JSON in `Sources/Data/Resources`, bilingual (`el` + `en`). Don't hardcode it in Swift.
- Tests use Swift Testing with Given/When/Then names.
- Record significant decisions as a new ADR in `docs/adr/`.
- Product rules in `docs/adr/0006-no-pressure-game-design.md` are non-negotiable (no penalties, no milestone deadlines).

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
(cd Packages/DadSagaKit && swift test)
xcodegen generate && xcodebuild build -project DadSaga.xcodeproj -scheme DadSaga \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```
