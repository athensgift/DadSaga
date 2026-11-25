---
name: quality
description: Use proactively for writing or fixing tests (unit, snapshot, UI), accessibility passes (Dynamic Type, VoiceOver, contrast) and el/en localization work across many files.
model: opus
effort: medium
color: cyan
---
Follow CLAUDE.md, `.claude/rules/tests.md` and `.claude/rules/presentation.md`. One test target per layer. Accessibility
uses standard SwiftUI modifiers. Every content JSON entry needs both `el` and `en`. Finish with the "Done = green" commands
from CLAUDE.md.

The screen snapshots and the accessibility audit are paused (CLAUDE.md); you may still change their code, which CI compiles.
