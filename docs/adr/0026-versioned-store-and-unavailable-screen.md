# ADR-0026: A versioned store, and a calm stop instead of a silent fallback

**Status:** Accepted (2026-11-18). Replaces the session-only fallback of ADR-0008 and resolves its open consequence (a lost
profile "needs a user-facing message before release"). From here on every stored-schema change is migrated; ADR-0023's
"no migration" applied to that one move only.

## Context
- `AppContainer` opened the store with `(try? LocalStore.live(…)) ?? LocalStore.sessionOnly()`. When the file could not be
  opened (a failed migration, a full disk, a damaged file), the app quietly ran on in-memory repositories: the dad landed
  in onboarding, entered his family again, and everything he recorded was gone when the app quit. His real data was still
  on disk, out of reach.
- `RootViewModel.onAppear` read the profile with `try?`, so a read error also meant "no family" and opened onboarding.
  Saving a family there gives the children new ids, and their moments drop out of home and the timeline.
- The `@Model` classes had no `VersionedSchema`. SwiftData runs a staged migration only from a store version it
  recognises. The baseline has to exist before the first TestFlight build.
- `ModelConfiguration(url:allowsSave:)` defaults to `cloudKitDatabase: .automatic`. There is no iCloud entitlement today;
  the day one is added, SwiftData would start mirroring this store by itself.
- `ProgressEvent.childID` was `UUID?`, left over from the pre-family migration that ADR-0023 deleted. Every write path
  takes a child.
- Saving the family deleted every `ChildRecord` and inserted them again, and read the profile row with `.first`.
- Partner co-op (Phase 5, ADR-0004) needs a CloudKit shared database. `ModelConfiguration.CloudKitDatabase` offers only
  `automatic`, `none` and `private(_:)`.

## Decision

### 1. If the store cannot be opened, the app says so and touches nothing
- `LocalStore.sessionOnly()` and the three `InMemory…Repository` actors are deleted. There is nothing to fall back to.
- `LocalStore` opens the SwiftData container on first use inside one `StoreConnection` actor, so opening (and any future
  migration) never runs on the main actor. If it fails, that call throws and the next call tries again. Nothing is
  created, deleted or reset; the error is logged.
- `RootViewModel` has a fourth state, `.unavailable`, for any error while reading the profile. Only "no profile" opens
  onboarding.
- The screen offers one action, **Try again**, and also tries again when the app returns to the foreground. No "start
  over" and no reset, not even the developer menu: nothing on this screen can delete what is on disk.
- Copy (ADR-0006: no blame, no alarm):

  | | el | en |
  |---|---|---|
  | Title | Δεν μπορέσαμε να ανοίξουμε την ιστορία σου | We couldn't open your saga |
  | Message | Ό,τι έχεις καταγράψει είναι ακόμα σε αυτό το iPhone και δεν αλλάξαμε τίποτα. Δοκίμασε ξανά σε λίγο. Αν συνεχίσει, δες αν το iPhone έχει ελεύθερο χώρο. | Everything you've recorded is still on this iPhone, and nothing was changed. Try again in a moment. If it keeps happening, check that your iPhone has some free storage. |
  | Button | Δοκίμασε ξανά | Try again |

- A link from the widget or a notification waits and opens once home does.
- The weekly reschedule (ADR-0024) leaves pending notifications alone when it cannot read the family; only "no family"
  clears them.
- The widget keeps its behaviour: a failed read shows "Open DadSaga" and retries after an hour.

### 2. The schema is versioned from today
- `SchemaV1` (`VersionedSchema`, 1.0.0) holds `ProfileRecord`, `ChildRecord`, `ProgressEventRecord` and `OutfitRecord`
  exactly as they were: names, properties, types, optionality, defaults. A store written by the build before this change
  is a test fixture (`Tests/DataTests/Fixtures/StoreBeforeV1`), and a test opens a copy of it read-write and read-only,
  so this is checked, not assumed. The fixture is never regenerated.
- `DadSagaMigrationPlan` lists `[SchemaV1]` and no stages. The rest of Data uses typealiases (`ProfileRecord =
  CurrentSchema.ProfileRecord`, …) and mapping extensions, so the `SchemaV1` file never changes again.
- Every later change to a stored property: a new `SchemaVn` with copies of the models it changes; a `.lightweight` stage
  when SwiftData can infer it, `.custom` otherwise; never edit a released version; a test that opens a store written with
  the previous version, read-write (app) and read-only (widget).
- Only the app migrates (ADR-0023). Before the first V2 ships, a test must show that the widget opening an older store
  read-only fails without changing the file.

### 3. On-device only, said explicitly
Every `ModelConfiguration` passes `cloudKitDatabase: .none`; the in-memory one also passes `groupContainer: .none`. Sync
will be its own decision (§6), never a side effect of adding an entitlement.

### 4. Every event has a child; the column follows with V2
- In the Domain, `ProgressEvent.childID`, `TimelineEntry.childID` and every `DadProgress` query take a non-optional `UUID`.
- The stored column stays `UUID?` in V1, so nothing is migrated now. The mapper skips a row without a child, as it skips a
  kind it does not know. No store since ADR-0023 holds such a row.
- The column becomes non-optional in the first V2 that is needed anyway (most likely the sync ADR), with a custom stage
  that drops rows without a child.

### 5. The family is updated in place
`save` updates the single profile row and each child's row by `childID`, inserts new children, and deletes removed
children and any duplicate rows, in one save. Rows keep their identity, which sync and future relationships need.
Removing a child still keeps its events (ADR-0012).

### 6. Partner co-op will need CKSyncEngine
SwiftData's managed CloudKit sync covers the private database only, so it cannot share a family with a partner. Co-op
will sync the event log with `CKSyncEngine`, which can run one engine on the private database and one on the shared
database. The log suits it: append-mostly, stable UUIDs, nothing derived is stored. A separate sync ADR decides the
record design, conflicts on the family, photos (ADR-0004 keeps them on the device) and the V2 schema (sync metadata,
non-optional `childID`, `#Unique` on `ChildRecord.childID` and `ProgressEventRecord.eventID`).

### Deferred
Uniqueness constraints and indexes, a profile id instead of the single-row rule, the non-optional `childID` column (all
V2); export and backup (ADR-0004); a widget message for "the store cannot be read".

## Consequences
- The app never runs on a store that is not the dad's. In return it can stop at launch until the store opens.
- The first stored-schema change after release has a place to go, and a test that proves old stores open.
- One actor hop on every repository call; the first call pays for opening the store.
- Adding an iCloud entitlement later changes nothing until the sync ADR says so.
- A fixture store (three small binary files) lives in the repository and is never regenerated.
