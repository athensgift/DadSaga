# ADR-0067: 1.0 ships every part of ADR-0065 that doesn't touch iCloud

**Status:** Accepted (2026-11-23, by the owner). Records the owner's release decision of that day; drafted by the
architect. It changes ADR-0065:
- **§9:** PRs 2 to 4 are no longer "the co-op version": PRs 1, 2a, 2b, 3 and 4 ship in 1.0, PR 4 wired to nothing.
  The co-op version is PR 5 and PR 6.
- **§4 "Removing a child marks them removed", §5 "A removed child in PR 1…" and "Nothing on screen changes…", the
  owner's answer 8, the status line and the Consequences:** removing a child marks them, and "Bring back" and "Delete
  for good" are there, from 1.0, not from the co-op version. "PR 1 only stores it" and "until the co-op version,
  removing still deletes" no longer hold.

And, through ADR-0065, **ADR-0012**: a removed child is marked from 1.0.

## Context
- ADR-0065 put PR 1 before the first App Store release and PRs 2 to 6 in "the co-op version" after it (§9), with a
  removed child only stored by 1.0 (§4, §5, answer 8).
- On `develop` now: PR 1, PR 2a (#103), PR 2b (#104) and PR 3 (#105). None touches iCloud: no CloudKit, no
  entitlement, no Info.plist key, nothing leaves the iPhone. PR 3 is visible to a dad alone ("My family" lists removed
  children), and the privacy pages already say a removed child stays until deleted for good (ADR-0065 §7).
- PR 4, the sync core, imports no CloudKit and is wired to nothing (§9): no `Sync.store` is created, no history is
  read, nothing is sent. Only what it changes in code that already runs (how the saga store's repositories reach the
  store, and checks moved into the store's own write, ADR-0068) runs in 1.0, the same for one parent as before.
- PR 5 (the `CloudSync` target, entitlements, Info.plist, the scene delegate, the wiring) is the first PR in which data
  could leave (ADR-0065 §7); PR 6 holds the iCloud and sharing screens.

## Decision
1. **1.0 ships ADR-0065's PRs 1, 2a, 2b, 3 and 4,** each that is on `develop` when the release branch is cut, PR 4
   unwired. Removing a child marks them, and either "Bring back" or "Delete for good" follows, for every dad.
2. **The co-op version is PR 5 (CloudKit) and PR 6 (the iCloud and sharing screens):** the first release in which
   data can leave the iPhone. Its privacy pages, About statement and camera words change there (ADR-0065 §7), and
   CloudKit's schema goes to production before its first TestFlight build (ADR-0065 §8).
3. **`Sync.store` doesn't ship with 1.0:** no 1.0 build creates it. `SyncSchemaV1` ships with the co-op version, and
   until then it changes in place, as `SchemaV1` did before 1.0 (ADR-0060 §1).
4. **What 1.0 freezes is unchanged:** `SchemaV1` and format 1 of a copy, at that release (ADR-0060 §5). PRs 2 to 4
   change neither, so no TestFlight build from them asks testers to delete the app first.
5. **No privacy change for PR 4:** the manifests, the App Store label and both privacy pages stay as PR 3 left them.

## Rejected
- **Cutting the release branch before PR 3:** a 1.0 dad who removed a child would lose them for good, their row
  deleted and their entries hidden with no way back (ADR-0065 §4).
- **Holding PR 4 until the co-op version:** it changes nothing a dad sees, and the code that runs from it in 1.0 is
  checked by the same tests as the rest of the store.

## Consequences
- Every dad of 1.0 can bring a removed child back or delete one for good; the co-op version adds only the second
  parent and iCloud.
- 1.0 carries code it doesn't run, the sync core, tested in every CI run like the rest.
- `docs/RELEASE.md` and `docs/ROADMAP.md` say what 1.0 ships and that `Sync.store` isn't in it.
