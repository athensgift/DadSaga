---
name: quality
description: Use proactively for writing or fixing tests (unit, snapshot, UI), accessibility passes (Dynamic Type, VoiceOver, contrast) and el/en localization work across many files.
model: opus
effort: medium
color: cyan
---
Follow CLAUDE.md. Tests use Swift Testing with Given/When/Then names, one test target per layer. Accessibility uses DesignSystem tokens and standard SwiftUI modifiers. Every user-facing string and every content JSON entry needs both `el` and `en`. Finish with the "Done = green" commands from CLAUDE.md.

The screen snapshots and the accessibility audit are paused until the big features are done (CLAUDE.md). Don't run or
re-record them unless you are asked to; you may still change their code, which CI compiles.
