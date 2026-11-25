# ADR-0081: 1.0 trims the saga store's history at launch, through a `FamilySync` with no iCloud

**Status:** Accepted (2026-11-26). From the Data review of 2026-11-25 (should-fix 1). It changes:
- **ADR-0067, Decision 1:** one call of PR 4 runs in 1.0: `StoreChangeFeed.trim()`, at launch, through
  `NoCloudFamilySync`. The rest of the sync core stays wired to nothing, and no 1.0 build creates `Sync.store`.
- **ADR-0069 §1:** `trim()` runs from 1.0, not only "with the wiring" of PR 5. Reading a gap's history before the trim
  stays PR 5's: it needs `Sync.store`.
- **ADR-0065 §9 (PR 5):** wiring sync puts `SyncCoordinator` in `NoCloudFamilySync`'s place, behind the app's one
  `FamilySync`, and deletes it; PR 5 adds no launch trim of its own.

## Context
- ADR-0065 §2: while iCloud is off, `StoreChangeFeed.trim()` deletes the history at launch, beside the orphan sweep,
  so it never grows. The call for it is `FamilySync.resume()` ("at launch… with iCloud off it trims the store's
  history"), and its only implementation, `SyncCoordinator`, ships with 1.0 wired to nothing (ADR-0067).
- So in 1.0 every save adds a history transaction, with a tombstone for every deleted row, and nothing deletes one.
  `docs/RELEASE.md` listed it as known and accepted, the first co-op launch trimming it.
- Nothing in 1.0 reads the history, and the co-op version never needs what 1.0 wrote: turning iCloud on enqueues
  every row once (ADR-0065 §2).
- A trim expires every history token. Once iCloud can be on it may run only on the coordinator's chain, and with a
  `Sync.store` that names a family only after the gap is read (ADR-0069 §1).

## Decision
1. **Data gains `NoCloudFamilySync`,** the `FamilySync` of a build with no iCloud: `status()` is off, and `resume()`
   trims the saga store's history. A failure is logged (its domain and code only) and the launch goes on; the next
   launch tries again. It opens the store as any repository does, and creates, resets or deletes nothing.
2. **The app holds one `any FamilySync` and calls `resume()` at launch,** at utility priority, beside the orphan sweep.
   In 1.0 that is `NoCloudFamilySync`.
3. **It checks nothing for iCloud:** a 1.0 build can't turn iCloud on (no CloudKit, no entitlement, no `Sync.store`,
   ADR-0067 §3), and the type wired is the guard.
4. **PR 5 replaces it, never adds beside it:** `SyncCoordinator` goes behind the same `FamilySync`, and
   `NoCloudFamilySync` and its tests are deleted. The coordinator's own trims (no `Sync.store`, or iCloud off once the
   gap is read) take its place, and its chain keeps a trim from landing after turning on has taken its token.

## Rejected
- **A use case for the trim:** the history has no meaning in the Domain, and the port is already in Application.
- **A public `LocalStore.trimHistory()` called from the app:** enough for 1.0, but PR 5 must remember to remove it.
  Left beside the coordinator, a launch trim that runs after turning on expires the new token, and one that runs
  before the gap is read drops edits ADR-0069 §1 keeps.
- **Wiring `SyncCoordinator` in 1.0 with a cloud that does nothing:** its off path does trim and makes no `Sync.store`,
  but it brings the whole sync core and a `SyncCloud` that isn't CloudKit into every 1.0 launch for one call.
- **Leaving it to the first co-op launch:** the store, which the widget opens too, grows for all of 1.0, against
  ADR-0065 §2.

## Consequences
- A 1.0 store's history holds only what was written since the launch. The file stops growing from it; what SQLite
  freed is reused, not given back.
- PR 5's change here is one line in `AppContainer` and one file deleted.
- `docs/RELEASE.md` loses its "known and accepted" item about the untrimmed history.
- No privacy change (ADR-0051): nothing new is stored, read or sent, and no required-reason API is added.
