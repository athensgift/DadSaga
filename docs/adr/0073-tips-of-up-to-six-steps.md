# ADR-0073: A card's tip has one to six steps

**Status:** Accepted (2026-11-25, by the owner). Changes ADR-0020 §1 ("One to five steps").

## Context
- ADR-0020 §1 gives a tip one to five steps. Nothing checked the upper end, and two cards of the v1 set (ADR-0053) have
  six. Each of their steps says something of its own; cutting one to keep to five would lose it.
- `ContentValidator` checked that a tip has steps, not how many (ADR-0005: content mistakes are caught at load).

## Decision
1. **A tip has one to six steps.** Six still reads as one list under the card, with the same look as a boss's guide.
2. **`ContentValidator` refuses a longer one** (`maxTipSteps`), as it refuses one with no steps. A boss's guide has no
   upper limit: it is the whole of its card.

## Rejected
- **Cutting the two cards to five steps:** each of their steps says something of its own.
- **No limit, as for a boss's guide:** a tip is the short "how" under a quest, not the card itself.

## Consequences
- No card changes. A seventh step stops the content from loading, in the tests first.
