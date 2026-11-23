# ADR-0069: What the sync core left open: edits kept through a gap, a delete for good made apart, a family with no child, an import, a leftover zone

**Status:** Accepted (2026-11-24, by the owner). Answers the questions ADR-0065's PR 4 (the sync core, #106) raised
in its review; built in PR 5 and PR 6. It changes ADR-0065:
- **§2 "History's two edges" and "A full send with no change token":** edits made while the change feed can't read
  them are kept, not overwritten by the server's values (1).
- **§4 "`gone` is final":** a delete for good made while a partner was apart from the family is asked about on
  rejoining (2).
- **§4 "A removal that would leave no child":** a family can end with no child; the app then asks calmly for one (3).
- **§4 and §6, an import:** it makes `Sync.store` forget its family (4).
- **§4 "Zones are deleted only by a parent's act":** one exception, a zone an iPhone built itself that `saga` never
  named (5).

## Context
- The sync core (ADR-0065 §9 item 4, ADR-0068) was built and reviewed against a fake cloud. Its review found five
  places where ADR-0065, read as written, loses a dad's edit, deletes what the partner recorded, reaches a state no
  screen handles, or leaves data in iCloud for good. None is reachable in 1.0, which ships the core unwired
  (ADR-0067).

## Decision
1. **Edits made in a gap are kept.** While sync is off for a family `Sync.store` still names (an account switched and
   back, iCloud turned off), the history is read into pending changes before it is trimmed, as the ids of children
   deleted for good already are. After an expired token, the rows changed since the last read the feed can still
   name are sent as changes, not taken from the server. The server's values win only for rows no local change names.
   So a photo added to an entry in the gap is sent, never orphaned and swept. Built in PR 5, with the wiring that
   makes `trim()` run.
2. **A delete for good made apart is asked about on rejoining.** A child the partner deleted for good while their saga
   was their own (after a stop or a leave) was confirmed for that saga only. On rejoining, if the family still holds
   the child, the join asks the partner, calmly, whether to delete them for both parents too or to keep the family's
   child. Keeping brings the child back on the rejoiner's iPhone with every entry the family holds, and drops the id
   from `Sync.store`'s list of children deleted for good. Without an answer nothing is sent. Built in PR 6, with
   `JoinFamilyUseCase` (words by `content`).
3. **A family with no child is a state the app handles.** It is reached only when each parent deletes the other's
   last child for good at the same time. Nothing brings a removed child back by itself (ADR-0068 Decision 6).
   Instead the app opens "My family" with calm words, where a dad adds a child or brings one back. Nothing is lost
   meanwhile: entries stay and still count for their author. Built in PR 6 (words by `content`, checked by
   `ui-check`).
4. **An import forgets the family `Sync.store` names.** An import replaces this iPhone's saga (ADR-0057 §1), so it
   also clears `Sync.store`'s family, its system fields and its ids of children deleted for good. Turning iCloud on
   again then finds a saga in iCloud that `Sync.store` doesn't name and asks which to keep (ADR-0065 §2). A copy that
   brings back a child deleted for good is never deleted again by the old zone's `gone` marker. Built in PR 6, with
   the import while iCloud is off; an import stays refused while shared (ADR-0065 §6).
5. **A zone an iPhone built that `saga` never named is deleted by that iPhone.** When both of a partner's iPhones
   rebuild after a stop before either has saved `saga`, each builds a zone and `saga` names one. The iPhone that then
   follows deletes the zone it built itself, once every record of its own is in the named zone and every photo it
   lists is known there. It never deletes a zone it didn't build or one `saga` has named. This is the one exception
   to "zones only by a parent's act": that zone holds only what is already elsewhere. Built in PR 5.

## Rejected
- **Leaving the gap's edits to the server** (ADR-0065 §2 as written): a dad's photo added in the gap would be swept a
  day later.
- **A delete for good made apart, sent to the family without asking:** the partner confirmed it for their own saga,
  and it would take what the other parent recorded after the split.
- **Bringing the first removed child back by itself** when no child is left: a child removed after a loss would come
  back on both iPhones with no one's act (ADR-0065 §5).
- **Letting the zone's `gone` marker win over an import:** a copy is how a dad undoes a delete for good.
- **Keeping the leftover zone:** a full copy of the family in iCloud that no screen shows and no one can delete.

## Consequences
- PR 5 adds the history read while off, the rows named after an expired token, and the leftover zone's deletion,
  each with a `FakeCloud` test.
- PR 6 adds the rejoin's question, the no-child state in "My family", and the import's clearing of `Sync.store`.
- No change to 1.0: the core stays unwired (ADR-0067).
