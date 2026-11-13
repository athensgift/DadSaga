# ADR-0003: Modular Swift package + XcodeGen

**Status:** Accepted

## Context
A single app target encourages UI and logic to tangle. `.xcodeproj` files cause merge noise and are hard to review.

## Decision
- All non-app code lives in a local Swift package `DadSagaKit`, with one target per Clean Architecture layer
  (`Domain`, `Application`, `Data`, `Presentation`) plus `DesignSystem`. See [ADR-0007](0007-clean-architecture.md).
- The app target is a thin shell. The Xcode project is generated from `project.yml` with XcodeGen and is git-ignored.

## Consequences
- `swift test` runs domain and content tests on macOS in seconds, without a simulator.
- Module boundaries enforce dependency direction (Domain depends on nothing).
- Contributors need `brew install xcodegen`.
