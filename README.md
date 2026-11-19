# DadSaga

> An RPG for new dads. You're the hero, your kid is your companion, and real life is the campaign.

DadSaga turns the first years of fatherhood into a game, without turning your child into a scoreboard.

- **Quests** are real things you do: a night shift, bath time, a walk on your own.
- **Boss fights** are real challenges, like the first fever or the sleep regression, and each comes with a short survival guide.
- **Legendary moments** (first smile, first steps…) are celebrated with photos when they happen, never expected by a date.
- **Saga**: the app turns those photos into a short film, whenever you ask and gently offered on each birthday.

## Why

Parenting apps are written mostly for mothers, and dads find them unappealing ([JMIR Pediatrics, 2025](https://pediatrics.jmir.org/2025/1/e64171/PDF)).
Almost half of new fathers report a mental-health problem in the first two years ([Fatherhood Institute](https://www.fatherhoodinstitute.org/_files/ugd/efff1d_046d651fc2744dd99ab3d28e20e3008c.pdf)).
And parents drop baby trackers because the logging starts to feel like pressure and guilt ([University of Edinburgh](https://medicalxpress.com/news/2018-04-baby-apps-parents-guilty-pressured.html)).

So DadSaga follows a few rules (see [ADR-0006](docs/adr/0006-no-pressure-game-design.md)):

1. XP rewards the **dad's actions**, never the child's development.
2. Nothing is ever lost: no penalties and no breakable streaks.
3. Worlds unlock by the child's **age**, never by milestones.
4. One skill branch, **Resilience**, is about the dad's own wellbeing.

## Architecture

[Clean Architecture](docs/adr/0007-clean-architecture.md): one SwiftPM target per layer, so the compiler enforces that dependencies point inward.

```
DadSaga (app)              composition root: AppContainer wires everything (DI)
Packages/DadSagaKit
├── Presentation           @Observable ViewModels → display models; SwiftUI views
├── WidgetPresentation     what the home-screen widget shows (no WidgetKit, unit-tested)
├── Localization           UI text: one String Catalog (el + en) for the app and the widget
├── Data                   repository implementations, DTOs, mappers, bundled JSON
├── Application            use cases + repository protocols (ports)
├── Domain                 entities + business rules (level curve, unlocks, progress)
├── HeroArt                the code-drawn hero and children (ADR-0028)
├── DesignSystem           tokens + reusable SwiftUI components
├── FilmKit                writes a film frame by frame; Apple frameworks only, knows nothing of the game (ADR-0036)
└── SagaMusic              the saga film's bundled theme and its credits, carried by the app only (ADR-0036)

Presentation ───────┐
WidgetPresentation ─┼─▶ Application ─▶ Domain
Data ───────────────┘
```

- Swift 6 with strict concurrency, iOS 26+, Swift Testing, with a test target per layer.
- The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) and isn't committed ([ADR-0003](docs/adr/0003-modular-spm-and-xcodegen.md)).
- Offline-first: photos and the child's data never leave the device ([ADR-0004](docs/adr/0004-offline-first-on-device-data.md)).
- Game content is data, not code ([ADR-0005](docs/adr/0005-content-as-data.md)); UI text lives in a String Catalog
  ([ADR-0027](docs/adr/0027-ui-string-catalog.md)).
- The on-device store is versioned and never silently replaced ([ADR-0026](docs/adr/0026-versioned-store-and-unavailable-screen.md)).

- The website [dadsaga.app](https://dadsaga.app) (landing, privacy, support in el/en) is static HTML in [`web/`](web),
  deployed by Cloudflare Pages ([ADR-0031](docs/adr/0031-website-on-cloudflare-pages.md)).

All decisions are recorded in [`docs/adr`](docs/adr).

## Getting started

```bash
brew install xcodegen swiftlint
xcodegen generate
open DadSaga.xcodeproj
```

Run the package tests (no simulator needed):

```bash
cd Packages/DadSagaKit && swift test --build-system swiftbuild
```

## Roadmap

See [docs/ROADMAP.md](docs/ROADMAP.md).

## Disclaimer

DadSaga's guides are general information, not medical advice. Always consult your paediatrician.
