# ADR-0068: The saga store has one queue: its repositories and the sync applier share one context

**Status:** Accepted (2026-11-24, by the owner, with ADR-0065's PR 4); proposed 2026-11-23 by the architect, planning
that PR. It changes ADR-0065:
- **§2 "Remote changes are written by one `@ModelActor`, `SwiftDataSyncApplier`, whose context's `author` is
  `sync`":** the applier is an actor on the saga store's one queue and context, and each of its saves carries the
  author `sync`.
- **Risks, "Remote writes go through the applier's `@ModelActor`, never a repository's context":** they go through
  the applier, whose saves alone carry `sync`; the context is shared.
- **§2 "history is deleted up to the token":** it is deleted before the token, whose own transaction stays (Decision
  5).
- **§2 and §4, where they leave the core's reading open:** what a fetched record and a fetched deletion mean, and when
  the partner's family is taken as stopped (Decision 6).

## Context
- The saga store has five `@ModelActor` repositories (profiles, progress, outfit, standing, the whole saga), each with
  a context of its own over one container. Until now only the dad's taps write, one after another.
- PR 4 adds a sixth writer, the sync applier, which writes whenever a fetch brings changes. Two contexts each fetch,
  check and save on their own; the store orders their saves, not their checks. Three rules would break without a
  word:
  - **No child left** (ADR-0065 §4): a local removal and a fetched one, each checked against what its own context
    read, can both land and leave the family with no child.
  - **A kept title never goes down** (ADR-0055 §3): `keep(titleID:)` writes the title a use case worked out from
    what it read; a higher one the applier kept from another of the parent's iPhones in between would be lowered.
  - **The limit of four on adding** (ADR-0065 §4), checked by the use case against a family read before the write.
- SwiftData documents neither whether a context sees another context's update of a row it has already loaded, nor
  how it merges two contexts' changes to one row.
- What Apple documents (checked 2026-11-23): `ModelActor` requires `modelContainer` and `modelExecutor`; its
  `modelContext` and `unownedExecutor` come from the executor. `DefaultSerialModelExecutor` is a `SerialExecutor` made
  with `init(modelContext:)`. `ModelContext.author` is `String?`, get and set (iOS 18). Swift's `SerialExecutor` page:
  actors that share one serial executor result "in only one of such actors ever being run at the same time", and the
  executor an actor returns "must always be the same object". Nothing here needs more than iOS 26.

## Decision
1. **One queue per open saga store.** `StoreConnection` makes one `ModelContext` and one
   `DefaultSerialModelExecutor` over it, and every actor that touches the store runs on it: the five repositories,
   `StoreChangeFeed` and `SwiftDataSyncApplier`. Each conforms to `ModelActor` by hand (the macro would give it a
   context of its own). So one write runs at a time, and each reads every row as last saved.
2. **The author is set for one save.** The applier's saves, and those of `replaceAll`, `eraseAll` and applying a
   `childMap`, set the context's `author` to `sync` for that save only and put it back, in one turn. No change waits in
   the context between turns: every write saves or rolls back in its turn (`saveAllOrNothing`), so a save carries only
   its own turn's changes and its own author.
3. **Every rule a write keeps is checked in that write's turn,** against the rows as stored: no child left (as
   today); the limit of four when an edit adds a child and when a child is brought back; a title kept only when it is
   higher than the one kept (`StandingRepository.keep` takes the catalog and merges as `KeptStanding.keeping`); a
   child deleted for good only while removed (as today). A use case may check first to refuse early; the check in the
   turn is the one that holds.
4. **Unchanged:** the `Connected…` wrappers stay `@concurrent` (ADR-0034 §7); the widget opens its own read-only
   store; `Sync.store` has its own container and actor.
5. **The change feed deletes history before its token,** never through it: a token expires as soon as its own
   transaction is deleted (found on a store on disk), so the transaction it names stays as the anchor. A token from
   another store file reads to SwiftData as "nothing changed"; the feed compares its store with the latest
   transaction's and reads a mismatch as expired.
6. **How the sync core reads what it fetches** (ADR-0065 PR 4, against a fake cloud; PR 5 confirms on devices):
   - A fetched record is the whole server record: a field this version maps that the record lacks clears the row's
     value (a cleared note, a birth day taken back, a title), except a field whose local change still waits. A field
     this version doesn't map is never touched.
   - A fetched deletion is applied only to a record this iPhone knows (it holds its system fields, or it waits behind
     that fetch), so an iPhone's own deletion handed back to it never deletes a row set again since.
   - For a partner, the family is taken as stopped when its shared zone is reported deleted, or when a save answers
     `zoneNotFound` and the fetch that follows doesn't list the zone: their saga goes to a zone of their own
     (ADR-0065 §4). A parent's own zone deleted by another of their iPhones turns sync off with the reason
     `zoneDeleted`, unless `saga` names a family to follow.
   - Nothing brings a removed child back by itself. A fetched removal that would leave no child is not applied: the
     child whose removal arrived last stays and is sent again (ADR-0065 §4). A fetched `gone` marker brings no removed
     child back, so a family can still end with no child in it (each parent deleting the other's last child for good).
     What the app does then is decided with PR 6, before any screen can reach it.

## Rejected
- **A context of its own for the applier,** as ADR-0065 §2 had it: the three rules above would hold only while no
  fetch lands between a check and its save, and reads of rows another context changed would rest on undocumented
  behaviour.
- **An async lock around each write:** actors re-enter at every `await`, and the sync engine calls back into the
  coordinator while a send is under way, so a lock held across them can deadlock.
- **Leaving conflicts to SwiftData's merge policy:** undocumented, and it would decide fields that ADR-0065 §4 decides.

## Consequences
- The store's work runs one call at a time: a screen's read can wait for an applied batch (one save, a few hundred
  rows at most), and a fetch waits for a screen's read.
- The five repositories lose `@ModelActor` for a hand-written conformance of a few lines each.
- `StandingRepository.keep(titleID:)` becomes `keep(titleID:catalog:)`; deleting an entry and deleting a child for good
  pass the catalog they already read.
- Bringing a child back checks the limit in the repository; the use case's own check goes.

## Verification status
Built in PR 4 (stage 4a, `SagaStoreQueueTests`, `ChangeFeedHistoryTests`). Found on a store on disk, and changing
ADR-0065 §2's "history is deleted up to the token": a token expires as soon as its own transaction is deleted, so the
change feed deletes history *before* the token and keeps its transaction as the anchor; a token from another store
file reads as "nothing changed", not as expired, so the feed compares its store with the latest transaction's and
treats a mismatch as expired; `model(for:)` returns a fault for a row that is gone, so the feed fetches by id and names
a missing row by its tombstone. Package tests on a store on disk, in PR 4: a save under `sync` is skipped by the change feed and the
repository save right after it is read; a row the applier changed is read by every repository that had loaded it; an
applier save between a use case's read and its write never leaves the family without a child or lowers a kept title.
