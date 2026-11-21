# ADR-0054: Cards about the pregnant partner are for a dad with a partner

**Status:** Accepted (2026-11-22). The owner's decision during the card-set review (2026-11-21), after the content was
written. Changes ADR-0053 §4 (which cards are only for a partner).

## Context
ADR-0053 §4 named six cards for `onlyFor: ["partner"]`: five quests about the couple and `b-w1-fourth-trimester`. Once
the World 0 text was final, several more cards turned out to talk to a dad whose partner is pregnant: they ask him to
go to her appointment, to learn what she wants at the birth, to pack the bag together, to talk to the bump, to choose a
name together, and the two bosses are about her labour and her caesarean. A dad on his own, or one whose child comes
by adoption or surrogacy, would read them as cards about someone who isn't there. The owner asked that these show only
to a dad with a partner, the same rule as the couple cards.

## Decision
- These carry `"onlyFor": ["partner"]` as well:
  - World 0 quests: `q-w0-appointment`, `q-w0-birth-partner`, `q-w0-feeding-plan`, `q-w0-go-bag`, `q-w0-name`,
    `q-w0-voice`.
  - World 0 bosses: `b-w0-birth-day`, `b-w0-caesarean`.
  - World 1: `q-w1-feeding-wingman` (it assumes someone else feeds the baby).
- With the six from ADR-0053 §4, a dad who answers "no" to «Έχω σύντροφο» / "I have a partner" stops seeing 15 cards:
  12 quests and 3 bosses.
- World 0 then has 8 quests and no boss for him. That is accepted: both World 0 bosses are about the partner's birth,
  and a world needs no boss (ADR-0006: nothing is owed). The content test that every world has a boss checks the whole
  catalog, not a dad's view of it, and stays as it is.

## Consequences
- The partner answer matters more before the birth than ADR-0053 expected; its wording and default (on) are unchanged.
- A new card that speaks to a pregnant or feeding partner gets `onlyFor: ["partner"]`, or is written so it holds for a
  dad on his own.
