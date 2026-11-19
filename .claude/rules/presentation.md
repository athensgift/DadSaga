---
paths:
  - "Packages/DadSagaKit/Sources/Presentation/**"
  - "Packages/DadSagaKit/Sources/WidgetPresentation/**"
  - "Packages/DadSagaKit/Sources/HeroArt/**"
  - "Packages/DadSagaKit/Sources/Localization/**"
  - "Widget/**"
  - "App/**"
---
- ViewModels are `@MainActor @Observable`, don't import SwiftUI, and expose display models only: no Domain types in views.
- Colours, spacing and fonts only through `DesignSystem` tokens (`DSColor`, `DSSpacing`, `DSFont`).
- UI text: `strings.text("English text")` plus an entry with `el` and `en` (state `translated`, `extractionState: manual`)
  in `Sources/Localization/Resources/Localizable.xcstrings`; plurals as catalog variations (ADR-0027).
- After changing how an avatar looks, regenerate the launch image and the website's images (ADR-0025, ADR-0033):
  `swift run --package-path Tools/LaunchLogo -Xswiftc -enable-testing LaunchLogo` from the repository root.
