# ADR-0071: 1.0 is free, with no in-app purchases; a "buy me a coffee" tip waits until after it

**Status:** Accepted (2026-11-24, by the owner). Answers the roadmap's open "Pricing decision" (Phase 4).

## Context
- The roadmap left the price open: "free; a one-time unlock later?" (Phase 4).
- DadSaga's rules leave little to sell. XP comes only from the dad's own actions, with no penalties, streaks or
  deadlines (ADR-0006); titles come from what he does, and they bring the hero's gear (ADR-0055). Selling gear, a title
  or a world would break both. The copy of the saga is "never behind a paywall, whatever the pricing ADR decides"
  (ADR-0057).
- The app has no account, server, analytics or ads (ADR-0004), and the privacy label is "Data Not Collected"
  (`docs/RELEASE.md`). A paid app or an in-app purchase needs the Paid Applications Agreement, banking and tax forms in
  App Store Connect, StoreKit code, its tests, and a review of both privacy pages (ADR-0051). None of it is there.
- The App Store Connect record waits on the D-U-N-S number, then the EU trader details (DSA). The owner wants nothing
  else in 1.0's way.
- On 2026-11-24 the owner raised a "buy me a coffee" tip and parked it until after the release: about €2.99, a plain
  tip or a thank-you cosmetic, never the gear titles earn.

## Decision
1. **1.0 is free in every territory, with no in-app purchases and no subscriptions.** No StoreKit code, no
   In-App Purchase capability, no Paid Applications Agreement for 1.0. Everything in the app is in the free app.
2. **The "buy me a coffee" tip is parked until after 1.0.** When it comes back, it starts from what the owner proposed:
   one purchase of about €2.99, either a plain tip (consumable) or a thank-you cosmetic made only for it
   (non-consumable, no XP, no title). It never sells what titles earn, nor any card, world, film or copy of the saga,
   and the app never asks for it in a way that pressures (ADR-0006): no reminders, no badges, nothing withheld. That
   version gets its own ADR, its privacy-page changes (ADR-0051) and the Paid Applications Agreement.
3. **The listing says it plainly.** The App Store text (`docs/appstore/`) promises nothing paid; the price tier in
   App Store Connect is Free.

## Rejected
- **A paid app (a one-off price):** a barrier for a tired new dad trying an app he has never heard of, for a first
  release with no reviews yet.
- **A one-time unlock (free to try, pay for more):** whatever is locked is either cards, worlds or the film, and
  locking them goes against ADR-0006 and ADR-0061 (no world locked).
- **The tip in 1.0:** the agreements, StoreKit and its review would sit in 1.0's way for a few euros.

## Consequences
- 1.0 needs no Paid Applications Agreement, no banking or tax forms and no StoreKit tests.
- Adding the tip later is a new version with a new ADR; the privacy label may stay "Data Not Collected" (Apple handles
  the purchase), but both privacy pages say what the app learns about it.
- An app once free can become paid later, but the owner's rules make that unlikely: anything worth selling is already
  promised free.
