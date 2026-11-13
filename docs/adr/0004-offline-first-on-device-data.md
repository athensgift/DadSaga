# ADR-0004: Offline-first, all child data on device

**Status:** Accepted

## Context
The app stores photos and details of minors. A server would bring GDPR obligations (children's data, consent, breach
handling) and running costs that a portfolio project can't justify.

## Decision
- All data (child profile, progress events, photos, generated videos) stays on device.
- No accounts, no backend, no third-party analytics SDK that receives personal data.
- Optional sync (Phase 5) will use the user's own iCloud (CloudKit private database).

## Consequences
- Strong privacy story, zero infra cost, works offline.
- No cross-device sync until Phase 5. Losing the phone without a backup means losing data, so an export feature is needed.
- Partner co-op (Phase 5) needs CloudKit sharing.
