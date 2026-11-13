# ADR-0002: SwiftUI, iOS 26+, Swift 6 strict concurrency

**Status:** Accepted

## Context
The project doubles as a playground for the modern Apple stack, so it should use what day-to-day work may not allow.

## Decision
- SwiftUI only, Observation for state, async/await for concurrency, SwiftData for persistence (from Phase 2).
- Minimum iOS 26. Swift 6 language mode with complete concurrency checking.
- Swift Testing for unit tests.

## Consequences
- Modern, idiomatic code with no legacy compatibility layers.
- A small share of older devices is excluded, which is acceptable for a portfolio app.
- Android comes later as a separate client. Domain rules are kept pure so they can be ported or shared (e.g. via KMP).
