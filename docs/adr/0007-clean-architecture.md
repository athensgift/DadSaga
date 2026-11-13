# ADR-0007: Clean Architecture

**Status:** Accepted

## Context
Two concerns: business rules must stay testable without UI or storage, and the app must be able to change frameworks
(e.g. JSON → remote content, SwiftData → CloudKit, iOS → Android) without rewriting its core.
References: [GeeksforGeeks: Complete Guide to Clean Architecture](https://www.geeksforgeeks.org/system-design/complete-guide-to-clean-architecture/),
[Clean Architecture in iOS](https://medium.com/@shweta.trrev/clean-architecture-in-ios-a-complete-guide-82e243224127).

## Decision
Four layers, each a separate SwiftPM target, so the compiler enforces the **dependency rule** (dependencies point inward only):

| Clean Architecture layer | Target | Contains |
|---|---|---|
| Entities | `Domain` | Entities (`World`, `Quest`, `Child`, …) and enterprise rules (`LevelCurve`, `DadProgress`, `UnlockRules`). Depends on nothing. Not `Codable`. |
| Use Cases | `Application` | Use case protocols + `Default…` implementations, and repository **protocols** (ports) such as `ContentRepository`. |
| Interface Adapters (gateways) | `Data` | Repository implementations, DTOs, DTO → entity mappers, validation. |
| Interface Adapters (presenters) | `Presentation` | `@Observable` ViewModels that call use cases and map entities to plain display models (`ViewState`). |
| Frameworks & Drivers | `Data/DataSources`, `Presentation` views, `DesignSystem`, App | Bundle/JSON access, SwiftUI views, UI kit. |
| Main / composition root | App target (`AppContainer`) | The only place that knows concrete types and wires them via constructor injection. |

Rules:
- `Domain` imports only Foundation. `Application` imports only `Domain`.
- `Data` and `Presentation` never import each other.
- ViewModels do not import SwiftUI. Views receive display models only, never Domain entities.
- Use cases are protocols, so ViewModels can be tested with stubs. Repositories are protocols, so use cases can be tested with stubs.
- Every abstraction must earn its place. No use case or protocol is added "just in case" (per the GfG guidance on over-engineering).

## Consequences
- Each layer has its own test target: `DomainTests`, `ApplicationTests`, `DataTests`, `PresentationTests`.
- Adding a feature touches several targets (entity → use case → repository → ViewModel → view). This is more files, but each is small and focused.
- SwiftUI views live in the `Presentation` target next to their ViewModels for ergonomics. The "no SwiftUI in ViewModels" rule keeps the presenter layer framework-free.
- The JSON format (DTOs) can change without touching Domain.
