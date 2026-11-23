# ADR-0065: Partner co-op: both parents share one family's saga through iCloud, each with their own hero and title

**Status:** Accepted (2026-11-23, by the owner, with its PR 1; proposed 2026-11-22, revised after review 2026-11-23). Drafted by the architect for the version after
the first App Store release, as the roadmap asks ("Sync ADR before Phase 5") and ADR-0026 §6 deferred. One part is for
**before** that release: §5's changes to `SchemaV1` and to format 1 of a copy, since both freeze with that build
(ADR-0060); `docs/RELEASE.md` checks it. The owner answered the product questions on 2026-11-22 and 2026-11-23
(folded in, listed at the end); none is open. It changes:
- **ADR-0003:** a `CloudSync` target, and its tests, hold the CloudKit code; the app links it, the widget doesn't.
- **ADR-0004:** once a parent turns iCloud on, their saga goes to their own iCloud; once they share it, the family
  lives in the inviting parent's iCloud and reaches the partner. Still no account, backend or server of ours.
- **ADR-0006:** with two parents, each one's XP, title and gear come only from the entries they recorded; firsts are
  the family's; nothing compares the two (§3).
- **ADR-0012:** both parents edit the family; a first counts once per child; the limit of four children is checked
  when adding, so sync may bring more; a removed child is marked, not deleted, to be brought back or deleted for good
  (§4).
- **ADR-0016:** with iCloud on, photos go to iCloud as stored, byte for byte.
- **ADR-0017, ADR-0022:** a partner's timeline rows carry their name and open to read, not to edit.
- **ADR-0021:** each parent undoes and deletes only their own entries; deleting a child for good takes every entry
  with that child, the partner's too (§4).
- **ADR-0023:** the widget's latest moment is anyone's; it reloads after a fetch that changed something.
- **ADR-0026 §6 and Deferred:** decided here. §3 (`cloudKitDatabase: .none`) stays, and now matters: with an iCloud
  entitlement, SwiftData would otherwise mirror the store by itself.
- **ADR-0030 §7, §8:** the About statement names iCloud; start over with iCloud on first ends this parent's part.
- **ADR-0036 §7, ADR-0037 §5:** the film offers answered are the parent's: kept in the defaults as now, and with iCloud
  on also in `Personal`, so each parent is offered a film once on all their iPhones.
- **ADR-0051 §1:** data that goes only to the parent's own iCloud and to the people in the share changes the privacy
  pages, not the manifests or the label, on §7's conditions.
- **ADR-0053, ADR-0054:** every member sees every card the family's facts allow; a joiner's partner answer starts at
  yes.
- **ADR-0055:** a title comes from its parent's own entries; the kept title merges as the higher; an iPhone keeps its
  parent's title before applying a fetched deletion of their entries.
- **ADR-0057 §2, §3, §7:** format 1 carries the hero's id, each entry's author and whether each child is removed; a
  copy of a shared family holds both parents' entries; a copy leaves out a kind or value this version can't name, and
  says so; its reader needs one child in the family and takes any number; no import while the saga is shared.
- **ADR-0060 §1, §2 and Deferred:** `SchemaV1` gains a profile id, an author on every entry, a child's `isRemoved`,
  `#Unique` ids, and ids kept in history; copies made by earlier builds no longer import (the new keys are required).

## Context
- **What is stored** (`SchemaV1`, ADR-0060 §2): one `ProfileRecord` (hero, look, partner answer, `heldTitleID`,
  `seenTitleID`) with no id of its own; `ChildRecord` by `childID`; `ProgressEventRecord` by `eventID` with its child,
  kind, content id, date, note and `photoIDs`, and no author; `OutfitRecord` by `skill`. No `#Unique`. Photos are
  `MomentPhotos/<UUID>.jpg` in the App Group (`FilePhotoStore`); the orphan sweep deletes a file no entry points to
  once it is a day old (ADR-0048 §6). Nothing derived is stored: XP, skills, cards done and the title come from the
  events (`DadProgress`, `DadStanding`), with the kept title on the profile row (ADR-0055 §3).
- **Writes** go through five `@ModelActor` repositories, each in one `saveAllOrNothing`. "My family" saves the whole
  family: `SwiftDataProfileRepository.save` deletes every stored child the edited list lacks. `replaceAll` (a restore)
  deletes every row and inserts the copy's in one save. Removing a child deletes its row; its entries stay, hidden, and
  a child added again gets a new id (ADR-0012).
- **Counting and limits.** `Timeline.countedEntries` counts a boss or a first once per child, whoever recorded it, and
  the timeline shows only what it counts; `addUnlessRecorded` checks kind, content and child.
  `ProfileRules.validatedChildren` refuses more than four children on any family save, and `SagaCopyRules.checked`
  refuses a copy with more than four, when it is made and when it is read.
- **What a version can't name.** `ProgressEventRecord.toDomain()` skips a kind it doesn't know, so `readAll` and a
  copy leave that entry out. An unknown look part reads as the standard one, an unknown gender as a boy, an unknown
  wardrobe choice as automatic. Only a content id is kept and copied as stored (ADR-0057 §5).
- **The content speaks to a dad.** Heroes are dad archetypes (ADR-0010); bosses such as "The Big Day" speak of "her";
  partner-only cards follow the dad's partner answer (ADR-0053, ADR-0054).
- **The timing.** Until the first App Store release, `SchemaV1` and format 1 of a copy change in place; both freeze
  with that build (ADR-0060 §1, §5). After it, a column added with a value per row (an id, an author) needs a custom
  stage, or an optional column whose nil means nothing, which ADR-0060 §2 has just removed; a `#Unique` added to a
  released store holding one duplicate stops that store from opening; and a new copy field is a format 2, read
  forever (ADR-0057 §4).
- **What Apple documents (checked 2026-11-22 and 2026-11-23):**
  - `CKSyncEngine` (iOS 17): "You can have multiple instances … each targeting a different database. For example, you
    may have one syncing a person's private database and another syncing their shared database." It "requires the
    CloudKit and Remote notifications entitlements", and "it's your responsibility to persist that state"
    (`Event.stateUpdate`). Changes are added with `state.add(pendingRecordZoneChanges:)` and handed over from
    `nextRecordZoneChangeBatch(_:syncEngine:)`; "Each batch is bounded by the server's per-request limit of 250 records
    (saves plus deletes combined)", and `RecordZoneChangeBatch(pendingChanges:recordProvider:)` walks the changes in
    order and stops when a batch is full. The engine retries network, account and rate-limit errors itself; "if you
    try to save a record and get a `serverRecordChanged`, you need to handle that error yourself". After a save,
    "encode the system fields of this record to use the next time you save". On an account change it "resets its
    internal state, including unsaved changes to both records and record zones", and sends `accountChange` with
    `signIn`, `signOut` or `switchAccounts` and the user record ids. A zone deletion has a reason: `deleted`, `purged`
    (the person deleted the app's data in Settings) or `encryptedDataReset`. `CKSyncEngineDelegate` is
    `AnyObject, Sendable`; events come one at a time, and `fetchChanges`/`sendChanges` are not called from
    `handleEvent`. Never for the public database. WWDC23 (10188): one engine per database; `automaticallySync = false`
    and two engines as two devices in tests; "it will automatically start listening for push notifications".
  - `CKShare(recordZoneID:)` (iOS 15): custom zones in the private database can be shared whole; "A record zone, and
    the records it contains, can take part in only a single share." The participant finds the zone in their shared
    database. `CKShare.allowsAccessRequests` (iOS 26): "By default, this property is `NO`. … When this property is
    `NO`, the server prevents uninvited users from requesting access and does not indicate whether the share exists."
    The iOS 26 beta notes called the request-access APIs "nonfunctional" (as quoted on Apple's forums).
  - Inviting: `CKShareTransferRepresentation` (iOS 16) for `ShareLink`, with
    `ExportedShare.prepareShare(container:allowedSharingOptions:preparationHandler:)` or
    `.existing(_:container:allowedSharingOptions:)`; `CKAllowedSharingOptions` (permission and access options;
    `allowsParticipantsToInviteOthers` and `allowsAccessRequests` off by default).
    `UICloudSharingController(share:container:)`: the owner adds or removes people and stops sharing; a participant
    views the people and leaves. `init(preparationHandler:)` is deprecated since iOS 17.
  - Accepting: `CKSharingSupported` "tells the system to launch your app when the user taps or clicks a share's URL".
    `UIWindowSceneDelegate.windowScene(_:userDidAcceptCloudKitShareWith:)`, or on a cold launch
    `UIScene.ConnectionOptions.cloudKitShareMetadata`; the share is accepted with `CKAcceptSharesOperation`. "To use
    this method in a SwiftUI app, you must first add scene and application delegates"
    (`application(_:configurationForConnecting:options:)` sets the scene's `delegateClass`).
  - `CKRecord.encryptedValues` (iOS 15): any type but `CKAsset` ("encrypted by default") and `Reference`; encrypted on
    the device; "When you enable Advanced Data Protection, the encryption keys are available exclusively to the
    record's owner and, if the user shares the record, that share's participants." "Only encrypt new fields. CloudKit
    doesn't allow encryption on fields that already exist in your app's schema." No index on an encrypted field.
  - SwiftData history (iOS 18; "Fetching and filtering time-based model changes"): transactions fetched after a token
    and filtered by the writing context's `author`; an update lists its `updatedAttributes`; a deletion keeps the
    attributes marked `@Attribute(.preserveValueOnDeletion)` in its `tombstone` (attributes only, Apple DTS on the
    forums); `deleteHistory(_:)`; a deleted token throws `historyTokenExpired`. History is available on the default
    store, with no switch named. `#Unique` (iOS 18) upserts on a matching value; nothing says what it does when one
    save deletes a row and inserts another with the same value. Most of these pages are declarations only, as
    ADR-0060 found for migrations.
  - App privacy details: "Collect" means "transmitting data off the device in a way that allows you and/or your
    third-party partners to access it"; under CloudKit: "You are not responsible for disclosing data collected by
    Apple."
  - iCloud Shared Photo Library (support.apple.com/111758): a member who leaves chooses "Keep everything" or "Keep only
    what I contributed"; when the organizer deletes the library, members receive everything.
  - Nothing here needs more than iOS 26, which the app requires (ADR-0002).

## Decision

### 1. What syncs, and where
- **Off until a parent turns iCloud on.** Until then nothing leaves the iPhone, as today. Two steps, in the same
  version: **iCloud** alone keeps a dad's saga on his own iPhones (the private engine, no share); **sharing** with a
  partner (§2) needs iCloud on and adds the share.
- **Two kinds of custom zone:**
  - **`Personal`,** in each parent's private database: their hero, look, partner answer, kept and seen title,
    wardrobe, the film offers they answered, and which family their saga is in. Only their own iPhones read it. A new
    iPhone on the same Apple Account gets the same profile id back, so the entries they recorded stay theirs.
  - **`Family-<UUID>`,** in the private database of the parent who invites (the owner), shared whole with a zone-wide
    `CKShare`: the members, the children, every entry, every photo. The partner reads and writes it through their
    shared database.
- **Records.** A record's name is its type and its stable id. Every field but a photo's asset is in
  `encryptedValues`, from the first deployment (it can't be added later). Values are the strings the store holds,
  never Swift case names.

  | Type | Name | Zone | Fields |
  |---|---|---|---|
  | `Hero` | `hero-<profileID>` | Personal | `classID`, `skinTone`, `hair`, `hairColor`, `beard`, `glasses`, `hasPartner`; `heldTitleID`, `seenTitleID` (absent: nil) |
  | `Wardrobe` | `wardrobe-<skill>` | Personal | `choice` (`hidden` or `item:<id>`); an automatic slot has no record |
  | `Offer` | `offer-<occasion id>` (its `/` escaped) | Personal | none: the film offer for that occasion was answered (ADR-0037 §5) |
  | `Saga` | `saga` | Personal | `familyZone`, `familyOwner` (the owner's real user record name); `childMap` (this parent's child ids to the family's, from the last join) |
  | `Member` | `member-<profileID>` | Family | `userRecordName`: the real user record name of the parent who writes it, from `CKContainer.userRecordID()`; their own only |
  | `Child` | `child-<childID>` | Family | `name`, `gender`, `skinTone`, `order`, `isRemoved`; `birthDay` as `yyyy-MM-dd`, absent while not born, one field so a day moves whole; `gone` once deleted for good, every other field cleared (§4) |
  | `Entry` | `entry-<eventID>` | Family | `author` (a profile id), `kind`, `contentID`, `childID`, `date`, `note` (absent: none), `photoIDs` (in order) |
  | `Photo` | `photo-<photoID>` | Family | `image`: a `CKAsset` of the stored JPEG; `entryID` |

- **Two iPhones on different versions.** The partners, or one dad's two iPhones, may run different versions of
  DadSaga for weeks, so each version takes what a newer one writes without losing it:
  - **Kept in the store and on the server.** An entry of a kind this version doesn't know, and a value it doesn't
    know in a known field (a look part, a gender, a skin tone, a wardrobe choice), are stored as they came (the store
    holds strings), never sent back or deleted by this version, and read as the store reads them today (Context). A
    value is written back only when this parent changes that field (§4).
  - **Not in this version's copy.** A copy reads the saga through the Domain, so it leaves out an unknown kind and
    writes an unknown value as read. When the store holds any, the export page says to update DadSaga so the copy
    holds everything. An unknown content id is kept and copied as it is (ADR-0057 §5).
  - **Fields it doesn't know stay on the server while the zone lives.** A save carries only the fields this iPhone
    changed (§4), so a field a newer version added keeps its value, and the applier never removes it. A zone rebuilt
    from this iPhone's store (`encryptedDataReset`, an import, iCloud turned on again) carries only what this version
    knows, and a newer field is lost then. Accepted: a newer version only adds fields an older one can do without.
  - **Content ids are permanent after the first App Store release:** never deleted, renamed or reused. A rename keeps
    the old one in `formerIDs`, and a card that goes is `retired`, not removed (ADR-0060 §4 keeps both mechanisms;
    `ShippedContentIDs.json`, written at that release by ADR-0060 §5, and its test guard them). An entry with a former
    id counts as the card it became.
  - **Record types and fields are only ever added** (as the production schema requires anyway, §8). A change that would
    alter a field's meaning is a new field.
  - Nothing else asks a parent to update, and nothing is refused for an older partner; their iPhone shows what it
    knows, and the rest appears after the update.
- **No references and no `parent`:** a zone-wide share needs no hierarchy, references aren't encrypted, and removing
  a child must not cascade to its entries (ADR-0012). Records name each other by id.
- **A photo is a record of its own,** written once and never changed, so editing a note never uploads a photo again.
  A batch is filled in order: members, children, entries, then photos, so a partner's timeline fills before its
  pictures. An entry that arrives before its photo shows without it until the photo comes. A downloaded photo is
  written under its own id, byte for byte, by a new `PhotoStore.place(_:id:)` (today's `adopt` gives a new id), never
  re-encoded (ADR-0042 §1). A photo an entry names but this iPhone lacks (swept, or a download cut short) is fetched
  again from `photo-<id>` when it is asked for.
- **Offers follow the parent, the rest stays with the iPhone.** The film offers answered travel in a copy
  (ADR-0057 §2), so they are the parent's and go in `Personal`, through the offer repository: the one change not read
  from the store's history (§2). Each parent is offered the family's film once, on whichever of their iPhones.
  - The answers stay in the defaults (ADR-0037 §5), so a kill between the answer and its record could lose one: at
    every launch the stored answers are compared with the `offer-` records `Sync.store` knows, as photos are, and the
    missing are sent.
  - An occasion id begins with its child's id (`<childID>/birthday/<n>`), so `childMap` renames the answers too: the
    old records go and the family child's are written.
  - An import replaces the records with the copy's answers; start over deletes them with `Personal`.
  - The weekly reminder (its permission is per iPhone), the preferences (ADR-0030 §3) and the film sheet's choices stay
    with the iPhone, as ADR-0057 §2 has them.

### 2. Sharing, joining, and how changes move
- **Sharing.** Settings gets a page to share the saga with a partner (words by `content`). Sharing needs iCloud on,
  then offers the invitation: `ShareLink` with `CKShareTransferRepresentation` and `prepareShare`, which saves a
  zone-wide `CKShare` with read and write for invited people only, no inviting others, and `allowsAccessRequests`
  off (in the share and in the sharing options): the invitation is the only way in. The share's title and thumbnail
  carry no names or photos ("DadSaga"): the invitation travels through Messages or Mail. Once shared, "Manage sharing"
  opens `UICloudSharingController(share:container:)`.
- **Where the CloudKit views live.** Presentation declares `FamilySharingViews`, a port that returns the invitation
  button and the manage sheet as views; the App target implements it with CloudKit (`CloudKitSharingViews`), as it
  implements Presentation's `BackgroundTime` with `UIKitBackgroundTime` (ADR-0057 §10). Presentation doesn't import
  CloudKit.
- **Two parents only.** The page offers an invitation only while the family has no partner. If a second person accepts
  anyway (the owner added one in "Manage sharing"), their DadSaga says calmly that this family already has two parents
  and doesn't join; the owner's sharing page shows the extra person to remove. Nothing in the records counts to two:
  the limit is the app's. A new partner may join once the last one has left.
- **Members.** On sharing and on joining, each parent writes their own `member-<profileID>`. CloudKit names the current
  user `__defaultOwner__` (`CKCurrentUserDefaultName`) in their own zone ids and in the share's own participant, so a
  member holds the real name from `CKContainer.userRecordID()`, and `saga`'s `familyOwner` holds the owner's: "is
  this family mine" compares it with this account's, and picks the private or the shared database. A member counts
  only when the record's `creatorUserRecordID`, resolved the same way, is the user it names. A partner's name is the
  share participant's whose user record matches that member; an author with no member, or whose member is no longer
  in the share, gets the neutral label (§3.7). So an earlier partner's entries are never shown under a new partner's
  name. A zone this iPhone rebuilds carries only this parent's own member, never one it would re-create as its
  creator; on a join or a rejoin, a parent whose member exists with another creator deletes it and writes it again.
- **Accepting.** `CKSharingSupported` opens DadSaga from the invitation. A scene delegate
  (`windowScene(_:userDidAcceptCloudKitShareWith:)`, and `cloudKitShareMetadata` on a cold launch) puts it in a
  `ShareInbox`, which waits like any link while an editor holds unsaved changes (ADR-0050 §4). The app says who
  invited them and asks; only a yes accepts. The family's records reach the store only once the join is finished:
  until then they wait in `Sync.store`, and their photos in a folder of its own beside it, out of the orphan sweep's
  reach (ADR-0048 §6) and out of the timeline.
- **Joining an iPhone with no saga:** the partner chooses their own hero and look; the family comes from the share.
- **Joining an iPhone with a saga:** their hero, look, wardrobe and title stay theirs. Each of their children is
  matched to one of the family's (by name first; they confirm), and its entries move to that child and join the family
  as theirs; the matched child's own row goes under the `sync` author (§4). A child they don't match joins the family
  as a new one; past four children, one is matched or removed first. Nothing they recorded is dropped.
- **A profile id already in the family.** If the family has a member with this iPhone's profile id from another Apple
  Account (a copy of the partner's saga was imported here), this iPhone takes a new profile id, and the entries it
  recorded under the old one that the family lacks move to the new one; entries the family has keep their author.
- **Rejoining** (after a stop, a leave or `encryptedDataReset`): the same id is the same child or entry, with no
  question and no matching. No row stays on this iPhone only, since a later full send would upload it anyway and no one
  could delete it. An entry of the joiner's that the family lacks is sent. Another author's that the family lacks is
  deleted here when that author is a current member (it is their deletion); otherwise it is sent as it is and shows
  under the neutral label.
- **One `CKSyncEngine` per database:** the private one (Personal, and Family for the owner) and the shared one (Family
  for a partner), reporting to one delegate actor. Each engine's state is persisted on every `stateUpdate`.
- **Local changes come from the store's history, not from every call site.** `StoreChangeFeed` reads the SwiftData
  history after its token. Each change in a transaction whose author isn't `sync` becomes a pending save with the
  fields it changed (`updatedAttributes`), or a pending delete named by the id its tombstone kept (§5). An entry's
  photos to save or delete come from comparing its `photoIDs` with the photos `Sync.store` knows for it. The pending
  changes and the new token are written in one save of `Sync.store`, then given to the engine; at every launch all of
  them are given again. A change leaves `Sync.store` once the engine reports it sent, and history is deleted up to the
  token. So a write and its sync can't come apart, and a write path added later syncs without anyone remembering to.
- **History's two edges.** If the token has expired (`historyTokenExpired`), every row is enqueued again behind a
  fetch from the engine's own change token, which reports the deletions since (a fetch from scratch reports none, and
  would bring back rows the partner deleted): a record the server lacks is then sent, and one it has keeps the
  server's values. While iCloud is off, `StoreChangeFeed.trim()` deletes the history at launch, beside the orphan
  sweep, so it never grows.
- **A full send with no change token** (iCloud turned on again for the family `Sync.store` still names, a rejoin,
  `encryptedDataReset`) follows a fetch of the whole zone and the rejoin's rule above: a row the family has merges as
  usual, an entry it lacks is sent or deleted as there, a child it lacks is sent, and a child it holds as `gone` is
  deleted here with their entries (§4). A parent's own entry they deleted on another iPhone while this one was off
  comes back: never lost, at worst back.
- **Remote changes** are written by one `@ModelActor`, `SwiftDataSyncApplier`, whose context's `author` is `sync`, so
  they never come back as local changes. It fetches each row by id and sets only the fields that came, leaving any
  field whose local change is still waiting (§4); `#Unique` guards it but is never how it writes, since an implicit
  upsert would overwrite the waiting fields. After a fetch that changed something, the widget's timelines reload
  (ADR-0023).
- **Starting.** Turning iCloud on enqueues every row once; the change feed starts from the token taken then.
  Onboarding's first step offers "Continue from iCloud" beside "Import data": it reads the Personal and Family zones of
  that Apple Account, only when tapped. An iPhone with a saga whose Apple Account's iCloud already holds another (one
  `Sync.store` doesn't name) asks which to keep, in the import's words (ADR-0057 §8); neither is merged or deleted
  without that answer.

### 3. Two parents, and what ADR-0006 means for them
1. **Each parent is a player.** Their hero, look, wardrobe, XP, skills, title, level and gear come only from entries
   whose `author` is their profile id. A partner's entry never adds to them or takes from them.
2. **The family is shared.** The children, the timeline, firsts and moments, every photo, the film's entries and the
   widget's latest moment come from every entry, whoever recorded it.
3. **Quests and bosses are what a parent does:** each parent's cards, map and weekly line show their own, and a boss
   counts once per child for each parent. **Firsts are what a child does:** captured once per child, by whichever
   parent was there. The one who captured it gets its XP (ADR-0006 §1); the other sees it captured, with the name of
   who did. If both captured it before either synced, the timeline shows both entries, and the captured state and the
   film count it once, the earlier.
4. **Each parent edits, undoes and deletes only their own entries** (ADR-0021); the partner's open to read. Both edit
   the family: add, change, remove and bring back children, and delete a removed one for good (§4). Neither is above
   the other.
5. **Nothing compares them.** The partner's hero, look and kept title never reach the other's iPhone (they live in
   `Personal`). Their XP, skills, card count, title and level could be worked out from their entries and the catalog,
   so the rule is in the code: no Domain query builds a standing (`DadProgress`, `DadStanding`, a skill's mark, a
   title) for any author but this iPhone's profile, and `AuthorshipTests` pin it. No totals for the two, no "who did
   more", no leaderboard; no notification, badge or count about the partner's entries: they appear in the timeline.
   The film's credits name the title of the parent who makes it, as now (ADR-0055).
6. **Nothing is lost.** A parent's entries stay theirs on a new iPhone (§1), when sharing ends (§4) and in a copy
   (§6).
7. **Neutral.** A partner is shown by the first name the share gives for their member (§2;
   `CKShare.Participant.userIdentity.nameComponents`, short form), or by a neutral label without one; never by a role
   or a gendered word. The app never asks a member's gender or whether they are a dad. A partner who isn't a dad joins
   the same game, heroes and cards (owner, 2026-11-22). Each member's partner-only cards follow their own partner
   answer, which starts at yes for a joiner.
8. **Every member sees every card** the family's facts allow (owner, 2026-11-22), including cards that speak of
   "her", such as "The Big Day": nothing hides a card from the member it is about, and the app asks nothing to know who
   that is.

### 4. Conflicts, zones, and when sharing ends
- **Merge by field.** A pending save carries only the fields this iPhone changed, set on the record rebuilt from the
  last system fields `Sync.store` keeps. On `serverRecordChanged` the delegate takes the error's server record, sets
  its own changed fields on it, and saves again: every field it didn't change keeps the server's value. The same field
  changed on both sides: the later save wins. A remote record that arrives while a local change waits is applied
  except for the waiting fields, which go after it.
- **Fields that time doesn't decide.** `heldTitleID` takes the higher of the two titles, whatever the order of saves,
  since a kept title never goes down (ADR-0055 §3; a Domain rule on `KeptStanding`); a kept title this version doesn't
  know is never replaced. Two children with the same `order` are shown by order, then id.
- **The limit of four children applies to adding only.** "My family" adds none while there are four or more, but a
  family edit accepts the number sync produced (both parents adding offline), and so does a copy (§5). Bringing a
  child back is adding. A removal that would leave no child in the family is not applied: the child whose removal
  arrived last stays, and is sent again.
- **Every edit says what changed.** "My family" saves a `FamilyEdit` (children added and removed, and the fields
  changed on each), taken from what the editor showed when it opened, not the whole family as it stands; hero and
  entry edits do the same, and a row update sets only the columns whose value changes. Otherwise a family edited on one
  iPhone while the partner added or renamed a child would delete that child or undo the rename.
- **Entries rarely meet.** Only an entry's author edits it, so a conflict on one is between that parent's own iPhones,
  merged by field. A first captured twice keeps both entries, with both notes and both sets of photos (§3.3). No entry
  is merged away.
- **Deletions** travel as CloudKit deletions; the saga store keeps no tombstone rows. **Sync deletes a local row only
  for a deletion fetched from the zone.** The other ways rows go are the parent's confirmed acts: a join (§2), a
  follow (below), "which to keep" (§2), an import (§6), start over, and deleting a child for good (below). A zone
  that goes is never one of them. The rows a join, a follow, "which to keep" or an import replaces go under the
  `sync` author, so the change feed never reads them as local changes; the zone they need is built by a full send
  (§2). A save that fails with `unknownItem` clears that record's system fields and stays
  pending behind a fetch: if the fetch reports the deletion, the change is dropped and the row deleted (a deletion
  wins over an edit made at the same time); if not, it is sent as a new record. A `Hero` is never deleted by sync.
  `Sync.store` drops a zone's system fields when the zone goes, when the account changes and when iCloud is turned on
  again, so a re-created zone never meets stale ones. An entry is deleted by its author, or with its child (below).
  Before applying a fetched deletion of this parent's own entries, the iPhone keeps their title, as a deletion does
  (ADR-0055 §3).
- **Removing a child marks them removed** (the owner, 2026-11-23). Today a removed child is deleted, and their
  entries stay, hidden, with no way back (ADR-0012); with two parents, one parent's removal would hide the other's
  moments with that child for good. From the co-op version:
  - **Removed:** either parent removes a child, for both. The child leaves home, the map, the timeline, the film and
    the widget, and leaves the family's counts: the limit of four, the cards for siblings, the child picker. Their
    entries stay, hidden with them, and still count for their author's XP, skills, cards and title: removing and
    bringing back change no one's standing (ADR-0012, ADR-0006 §2). Removing sets `isRemoved`, a field change, so it
    merges like any other field.
  - **Brought back:** "My family" lists the removed children; either parent brings one back with every entry.
  - **Deleted for good:** from the same list, either parent deletes a removed child for good: the child, every entry
    with them (the partner's too) and their photos. Those entries' XP and skill marks go for both parents, as a
    deletion's do, and each parent's title is kept (ADR-0055 §3). A calm confirmation says it is for both parents and
    can't be undone, and shows no counts. The words are calm, since this is also how a child on the way leaves after
    a loss: no talk of death (`content` writes them).
  - **Nothing brings one back by itself:** deleting for good leaves `child-<id>` as a marker, `gone`, with every other
    field cleared, so a full send from an iPhone that was off (§2) can't send the child again; an entry whose child is
    gone is deleted there, never sent. `gone` is final: a save onto a gone record (a bring-back racing a delete for
    good) is ignored, and the iPhone that sent it deletes the child when the marker arrives. `Sync.store` keeps the
    ids of the children deleted for good, from this iPhone's own acts and from fetched markers, and every zone
    this iPhone builds carries their `gone` records, so a zone
    rebuilt after a leave, a stop or `encryptedDataReset` keeps them too. Rows a confirmed act replaces go under the
    `sync` author (above), so the change feed's only local child deletion is deleting for good, which it sends as
    the marker.
  - **PR 1 only stores it** (§5): until the co-op version, removing still deletes, as today.
- **Leaving:** a partner who leaves from "Manage sharing" is asked once, calmly: **Keep everything** (first) or **Keep
  only what I recorded** (the children and their own entries). The family zone keeps what they recorded, as Shared
  Photo Library keeps a leaver's photos. **Stopping:** when the owner stops sharing, every partner keeps everything,
  without a question, and the owner keeps the zone. Afterwards each iPhone's saga is its own.
- **Zones are deleted only by a parent's act** (start over, a join, an import, a choice they confirmed), never by a
  clean-up comparing iCloud with a list kept on the iPhone, which a stale iPhone could get wrong. **A parent's other
  iPhones follow `saga`:** when it names another family, each asks once to follow, in "Continue from iCloud"'s words.
  Following applies `childMap` to the stored rows and to anything still waiting: a mapped child's row goes (under the
  `sync` author, so it is never read as deleted for good), its entries keep their ids with the family's child, and
  the offer answers are renamed (§1); then the family's records
  arrive as for a join. `saga` says how it changed: a follow after a join, a leave or a stop merges what was
  waiting, as above; a follow after an import or "which to keep" replaces this iPhone's saga with the zone's, as an
  import does (ADR-0057 §1: no merging), and its question says so.
  Until it follows, only the family's sync is off there: `Personal` keeps fetching, or that
  iPhone would never see `saga` change, and its saga stays. So:
  - **joining with iCloud on alone:** once their entries are in the family zone, their own Family zone is deleted and
    `saga` names the family;
  - **leaving or stopped, with iCloud on:** their saga goes to a new Family zone of theirs, and `saga` names it;
  - **importing with iCloud on** (never while shared, §6), and "which to keep" answered with this iPhone's saga: the
    Family zone is deleted and the saga goes into a new one; `Personal`'s `Hero`, `Wardrobe` and `Offer` records are
    deleted and written again from the store, not merged, so the copy's own title stands (ADR-0057 §7) and an
    automatic wardrobe slot leaves no record behind. The rows are written by `replaceAll` on a context whose author is
    `sync`; the coordinator then sends the new zones in full. `saga` names the new zone and says it was replaced;
  - **start over with iCloud alone:** the Family and Personal zones are deleted; the dad's other iPhones see Personal
    go (`deleted`), turn sync off and keep their saga.
- **A zone that goes by itself:** `purged` (the parent deleted DadSaga's iCloud data in Settings) turns sync off on
  that iPhone, and nothing is uploaded again by itself. `encryptedDataReset` re-creates this iPhone's Personal and
  owned Family zones under the same names and uploads them again, so when two of the owner's iPhones both do it,
  their uploads merge by the full-send rule (§2), system fields being dropped; a partner is invited again. `deleted`
  by another of this parent's iPhones turns sync off here, unless `saga` names a family to follow. For a partner, the
  shared zone going is the owner stopping. A zone that goes never deletes the saga on the iPhone.
- **The account.** `signOut`: sync pauses, the saga stays, and `Sync.store`'s pending changes are given again when
  the same account returns (its user record id is kept). `switchAccounts`, or a sign-in to another account: sync stays
  off for this saga until the parent turns it on for that account. Nothing is uploaded into another person's iCloud by
  itself, and nothing is deleted (ADR-0026 §1), where Apple's sample deletes local data.
- **iCloud full** (`quotaExceeded`, which the engine doesn't retry): changes wait in `Sync.store`, the saga is
  untouched, and the iCloud page says whose iCloud is full; the family's photos count in the owner's.
- **Start over on a shared family** first ends this parent's part: the owner stops sharing and deletes the Family and
  Personal zones; a partner leaves and deletes their Personal zone. Then it erases the iPhone, `Sync.store` included
  (ADR-0030 §8). Its confirmation says the partner keeps their saga.

### 5. The store: what goes in `SchemaV1` now, and what never goes in it
**Before the first App Store release,** in one PR before the release branch (`docs/RELEASE.md` checks it; devices
running `develop` delete the app first, ADR-0060 §2):

| Change | Why now, not in a `SchemaV2` |
|---|---|
| `ProfileRecord.profileID: UUID`, made at onboarding; Domain `PlayerProfile.id` | An author needs an identity. Later: a custom stage to make one, or an optional column whose nil means nothing |
| `ProgressEventRecord.authorID: UUID`, the profile's id on every entry; Domain `ProgressEvent.authorID`, set by `EventRecorder` | The same. Later: a stage that fills every row |
| `#Unique` on `ChildRecord.childID`, `ProgressEventRecord.eventID`, `OutfitRecord.skill`, `ProfileRecord.profileID` | One row per id, which the applier and the change feed assume. Later: a released store with one duplicate fails to open at the migration and shows a real dad the calm screen (ADR-0026 §1), unless a stage removes duplicates first |
| `@Attribute(.preserveValueOnDeletion)` on those four ids | The change feed names a deleted row by its id (§2). Later: one more change to a released model, with its version and fixture test (ADR-0026 §2), for one option |
| Format 1 of a copy: `hero.id` and each entry's `author`, both required | The format freezes with the same build (ADR-0060 §1). Later: a format 2, read forever (ADR-0057 §4) |
| `ChildRecord.isRemoved: Bool`, written false (no literal default, ADR-0060 §2), and a required `removed` on each child in format 1 | The co-op version marks a removed child (§4). Later: the same two freezes |

- **Subtracted with it:** the duplicate-child clean-up in `SwiftDataProfileRepository.save` (a duplicate can't exist
  any more); `SwiftDataOutfitRepository.setChoice`'s delete-then-insert becomes an update or a delete of the one row;
  `SchemaV1`'s comment "no `#Unique`". The single-profile rule stays: an iPhone holds one player, and the partner's hero
  is never stored there.
- **`#Unique` meets `replaceAll`,** which deletes every row and inserts the copy's in one save, often with the same
  ids. A package test on a store on disk restores the same copy twice, and a copy over a saga that shares its ids,
  then reads everything back through each repository. If it fails, `replaceAll` updates rows by id and deletes the
  rest instead.
- **A restore** sets the profile id to the copy's `hero.id` and keeps every entry's author; an author is any id,
  since a partner's entries carry theirs.
- **`SagaCopyRules` takes any number of children from one,** in PR 1, when a copy is made and when it is read. The 1.0
  reader is frozen with the release, and with today's limit of four it would call a valid five-child copy from a
  co-op version damaged. The one it needs is a child in the family: a removed child is in none of the family's counts,
  so a copy whose children are all removed is damaged. Ids are unique, and names non-empty, across every child,
  removed ones included. The limit on adding stays in `ProfileRules` (§4).
- **A removed child in PR 1 is stored, read and kept, never set.** Removing still deletes until the co-op version, so
  no saga PR 1 can make holds one. One can only arrive in a copy from a newer version, and the frozen 1.0 code must not
  bring back a child removed after a loss. So `isRemoved` keeps them off every screen and out of the family's counts
  (the limit of four, the cards for siblings, the picker), while their entries still count for their author (§4); a
  family save leaves their row alone, and a copy carries them again (`StoredSaga.removedChildren`).
- **Earlier copies stop importing.** With three required keys, a copy made by a `develop` or TestFlight build before
  PR 1 no longer reads, against ADR-0060 §1's "still reads". Nothing has shipped, so no reader is kept for them; the
  next TestFlight build's notes say it, beside "delete DadSaga first". The `SagaCopyV1` fixture is recorded again, as
  ADR-0060 §5 does at the release anyway.
- **Nothing on screen changes** for any saga PR 1 can make, and the privacy pages don't: the ids are random and stay
  on the iPhone, and no child is kept removed. Until co-op ships, every entry's author is the one profile.

**Sync's bookkeeping never goes in the saga's store: it is `Sync.store`,** a second SwiftData store beside
`DadSaga.store` in the App Group, with its own versioned schema (`SyncSchemaV1`), created when iCloud is first turned
on, never opened by the widget, never in a copy, erased by start over. It holds each record's system fields by name;
the pending changes and their fields; each engine's state; the history token; the family zone, whether this iPhone owns
it or joined it, and the account's user record id; the members and the partner's name from the share; the photos known
for each entry and the `offer-` records known; the ids of children deleted for good (§4); and a joining family's
records until the join ends, with their photos in its folder. Its shape follows the engine work, so it isn't guessed
into `SchemaV1` now; kept apart, the copy test (every stored property in format 1, ADR-0057 §4), start over and the
widget stay about the saga. It sits beside the saga so an iCloud Backup brings both back together.

**So co-op is expected to need no `SchemaV2`.** If it ever does, it is an additive, lightweight version from the
`StoreV1` fixture (ADR-0060 §5).

### 6. Copies of the saga, and backups
- **A copy** (ADR-0057) of a shared family is the saga as this iPhone has it: every child, every entry with its author
  (the partner's too, with notes and photos), and this parent's hero, title and wardrobe; never `Sync.store`. Either
  parent's copy holds the whole family (owner, 2026-11-22); the export text says it holds the partner's entries, and,
  when the store holds a kind or value this version can't name, to update DadSaga first (§1).
- **No import while the saga is shared:** the import part of the page says to stop sharing or leave first, since
  replacing the family would replace it for the partner too. After that, an import replaces this iPhone's saga and
  keeps its authors: the restorer becomes the copy's hero, and a partner's entries stay the partner's and count for no
  one here. With iCloud on, it goes to a new family zone (§4).
- **iCloud Backup** is unchanged; `Sync.store` comes back with the store, and the engines carry on from the restored
  state (checked on a device). With iCloud on, a new iPhone also gets the saga from iCloud without a backup (§2).

### 7. Entitlements, Info.plist and privacy
- **`project.yml`, the app only** (the widget never syncs):
  - entitlements: `com.apple.developer.icloud-services: [CloudKit]`; `com.apple.developer.icloud-container-identifiers:
    [iCloud.com.athinodoros.dadsaga]` (a container can never be deleted or renamed: chosen once); `aps-environment:
    development`, which the App Store export signs as `production` (checked in the archive);
  - Info.plist: `CKSharingSupported: true`; `UIBackgroundModes: [remote-notification]`; `NSCameraUsageDescription`
    stops saying "Photos stay on this device" (words by `content`).
  - `NotificationDelegate` returns a scene configuration naming the scene delegate (§2).
- **CloudKit stays out of the widget.** The widget links `Data` (ADR-0051 §1), so `CloudKitSyncEngine` and its record
  conversion live in a target of their own, `CloudSync`, linked by the app only, as `SagaMusic` is (ADR-0003). `Data`
  keeps the sync core, which imports no CloudKit.
- **Every `ModelConfiguration` keeps `cloudKitDatabase: .none`** (ADR-0026 §3), `Sync.store`'s too.
- **The privacy manifests and the App Store label don't change** ("Data Not Collected"): CloudKit isn't a
  required-reason API, the developer can't read anyone's private or shared database, and Apple's page counts CloudKit
  as data Apple collects. This holds while the app uses no public database, and nothing from a record (a name, a note,
  a photo, an id) goes into a log, a crash report or a support email the app writes. This narrows ADR-0051 §1, where
  data the app starts handling changes the manifests and the label too. `ITSAppUsesNonExemptEncryption` stays false:
  the encryption is Apple's.
- **Both privacy pages** change in the PR where data can first leave (ADR-0051 §1):
  - a new section on iCloud and the partner: off until you turn iCloud on; what goes where (your saga to your iCloud;
    once shared, the family to the inviting parent's iCloud, in their storage; your hero, title and wardrobe to your
    own iCloud only); who sees it (the people in the share, and Apple under its terms); encrypted on the iPhone before
    it goes, and with Advanced Data Protection only the people in the share hold the keys; that your first name, from
    your Apple Account, is shown on your partner's iPhone and kept there, with an identifier of your iCloud account for
    this app (the `Member` record); that your entries stay on your partner's iPhone and in their copies after sharing
    ends; how to stop (stop sharing or leave, start over, or delete DadSaga's data in iCloud settings) and what stays
    after (§4);
  - "In short", the storage paragraph, "Children", "Notifications" (iCloud's silent pushes come through Apple),
    "Deleting your data", "Your rights" and "Changes" change with it.
- **Both privacy pages change again for removed children,** in the PR where removing starts to mark (§9, PR 3): a
  removed child's name and birth day stay on the iPhone and in copies (with iCloud on, also in iCloud and on the
  partner's iPhone) until the child is deleted for good; "Deleting your data" names deleting for good. Calm words, as
  in the app (§4).
  The About statement (ADR-0030 §7) adds iCloud; the support pages answer how to move to a new iPhone through iCloud.

### 8. Testing
- **Seams.** A `SyncEngine` protocol covers what the delegate uses of `CKSyncEngine` (add pending changes, fetch,
  send, events, state), over `SyncRecord`, a `Sendable` value (type, name, fields, asset file, system fields as data).
  Only `CloudSync`, and in the App the sharing views, the scene delegate and `ShareInbox` (`CKShare.Metadata`), import
  CloudKit; a `CKRecord` never leaves `CloudKitSyncEngine`. In
  tests a `FakeCloud` keeps zones and change tags, answers `serverRecordChanged` with the server record and
  `unknownItem` for a deleted record or stale system fields in a re-created zone, deletes zones with each reason
  (`encryptedDataReset` on Personal too), changes accounts and runs out of quota; two `FakeSyncEngine`s on one
  `FakeCloud` are two iPhones.
- **Suites:** `ChangeFeedTests` (history to pending changes on a store on disk: fields, ids kept on deletion, `sync`
  writes skipped, an expired token), `FieldMergeTests`, `SyncRecordMappingTests` (in `CloudSyncTests`: real
  `CKRecord`s, offline, and the creator check on a member), `AuthorshipTests` (§3, in the Domain: a partner's entry
  changes nothing of mine, no standing is built for another author, and a removed child's entries still count for
  their author), `FamilyEditTests`, `TwoParentsSyncTests` (both record offline; both edit a child; one removes it; a
  first captured twice; more than four children; leave; stop; purge; a zone re-created with stale fields;
  `encryptedDataReset` on two of the owner's iPhones, one zone each; account switch; quota; an iPhone following a
  join, with no child shown twice and no mapped child read as deleted for good; an import with iCloud on, then the
  dad's other iPhone following it: its old saga replaced, never merged back, and `Personal` rewritten with the copy's
  title), `JoinFamilyTests` (matching; a
  profile id already in the family; a rejoin after a stop, a leave and `encryptedDataReset`; on a rejoin, a current
  member's entry the family lacks is deleted here, and an earlier partner's is sent under the neutral label; a member
  with another creator written again; a rebuilt zone with only this parent's member), `VersionSkewTests` (an unknown
  kind, content id, field and look value arrive, are kept and never sent back or deleted; the unknown content id is
  copied, and the export says to update), and the import refused while shared. `RemovedChildTests`:
  - PR 1: a copy with a removed child imports, stays off every screen and out of the family's counts, survives a
    family save and is copied again; their entries still count; a copy whose children are all removed is damaged.
  - PR 3: removing and bringing back change no standing; deleting for good takes the entries' XP and keeps the title,
    and its confirmation shows no counts.
  - PR 4, with `FakeCloud`: removing and bringing back merge by field; the last child stays; deleting for good leaves
    the `gone` marker; a save onto a gone record is ignored; a full send never brings a gone child back, nor after a
    delete for good, a stop, and a stale iPhone that follows and sends; the partner's title is kept when their
    entries go.

  PR 1 also adds the `#Unique` and `replaceAll` test (§5).
- **On devices:** two iPhones, two Apple Accounts with iCloud, Debug builds (CloudKit's development environment):
  invite through Messages; accept with DadSaga open and closed; both offline, then online; a child edited on both; 500
  photos sent and received; a push with the app in the background, and the widget after it; leave, stop and start over
  on each side; sign out and switch account; DadSaga's data deleted in iCloud settings; an iCloud Backup restored; a
  dad's second iPhone following a join.
- **Schema:** the development schema comes from the first saves. Before the first TestFlight build with co-op
  (TestFlight and App Store builds use the production environment), it is deployed to production in CloudKit Console.
  From then on record types and fields can only be added, and which fields are encrypted is fixed (§1).

### 9. Where the code goes
Each PR goes Domain → Application → Data → Presentation → `AppContainer` (ADR-0007). Each is planned by `architect`
and reviewed with Fable (persistence and sync). Strings by `content`; every screen through `ui-check`.
1. **Ids and authors, before the first App Store release branch.** Domain: `PlayerProfile.id`,
   `ProgressEvent.authorID`. Application: `EventRecorder` and the three recording use cases take the author, read
   through `ProfileRepository`; onboarding makes the id; `SagaCopyRules` takes any number of children from one, at
   least one not removed; `StoredSaga.removedChildren`. Data: §5's `SchemaV1` (`isRemoved` included), the mappers
   (profiles read only children not removed; a family save leaves removed rows alone), `SagaCopyV1DTO` (`removed`),
   the fixture copy, the two subtractions, the `#Unique` and `replaceAll` test. App: wiring. Nothing on screen.
2. **Two players** (co-op version, as are the rest). Domain: `DadProgress` from one author's entries; the family's
   captured firsts from all; `Timeline.countedEntries` counts a boss or a first once per child per author, and the
   timeline lists every entry of a known card; `TimelineEntry.authorID`; `FamilyEdit`; the `KeptStanding` merge;
   `ProfileRules` checks the limit only when adding.
   Application: home, map, timeline, film, highlights and edits split into own and family; `ProfileRepository` saves
   a `FamilyEdit`; `WholeSagaRepository.readAll` says whether it left anything out. Data: `addUnlessRecorded` checks
   the author for a boss and any author for a first; updates set only changed columns. Nothing visible changes for one
   parent.
3. **Removed children.** Domain: `PlayerProfile.removedChildren`; a removed child out of the family's queries and
   counts (the picker, siblings, the limit of four), their entries still counting for their author.
   Application: `FamilyEdit` removes by marking; `BringBackChildUseCase`; `DeleteChildForGoodUseCase` (the child,
   their entries and photos). Data: the mappers write `isRemoved`. Presentation: "My family" lists removed children
   with "Bring back" and "Delete for good", and its calm confirmation. Web: both privacy pages (§7). Visible to a dad
   alone too.
4. **Sync core, without CloudKit.** Application: a `FamilySync` port and `ShareStatus`. Data: `Sync.store`,
   `StoreChangeFeed` (with `trim()`), `SwiftDataSyncApplier`, `SyncRecord` and its mappings, `FieldMerge`,
   `SyncCoordinator`, the `SyncEngine` port, the offer repository's sync and its comparison at launch, `childMap`,
   the `gone` marker and the ids kept for it, `FakeCloud`. Nothing wired.
5. **CloudKit.** `CloudSync`: `CloudKitSyncEngine` (the two engines and the delegate actor), zones, members, the
   share, accepting; `CloudSyncTests`, a test target of its own. Data: `FilePhotoStore.place`. App: the scene
   delegate, `ShareInbox`, wiring with iCloud off, `project.yml` (§7). Web: both privacy pages, the About statement,
   the camera's words: the first PR in which data could leave.
6. **The iCloud and sharing screens.** Application: `TurnOnICloudUseCase`, `StartSharingUseCase`, `JoinFamilyUseCase`
   (with the matching), `EndSharingUseCase`, `KeepAfterLeavingUseCase`, `FollowSagaUseCase`. Presentation:
   `FamilySharingViewModel`, `FamilySharingViewState`, `FamilySharingView` and the `FamilySharingViews` port;
   `JoinFamilyViewModel` and its view; the leaving question; the partner's name on timeline rows and their entries
   opened to read; the export and import pages' notes. App: `CloudKitSharingViews` (`ShareLink` with
   `CKShareTransferRepresentation`, and `UICloudSharingController`).
Then §8 on devices, the schema to production, and TestFlight.

## Risks
- **Swift 6:** `CKSyncEngineDelegate` is `AnyObject, Sendable` with `async` methods: an actor. `CKRecord` and
  `CKAsset` stay inside it; only `SyncRecord` crosses. The scene delegate is on the main actor and only hands the
  invitation to `ShareInbox`. Remote writes go through the applier's `@ModelActor`, never a repository's context, which
  would echo them back.
- **The App Group lock:** a fetch woken by a push writes the shared SQLite file; the app must not be suspended
  mid-write (`0xdead10cc`, ADR-0057), so applying runs under `beginBackgroundTask`.
- **SwiftData:** history, tombstones and `#Unique` are documented by declaration; every behaviour this leans on is
  pinned by a package test (PR 1 and PR 4), and a row update setting an equal value must not count as a change.
- **Deleting by mistake:** a stale iPhone must never delete a zone or a row: zones only by a parent's act, rows only
  by a fetched deletion or a parent's confirmed act (§4), never because a zone went.
- **CloudKit's production schema is permanent:** record types, field names and encryption are reviewed once more
  before it is deployed.
- **ADR-0006:** every Domain query that counts says whose entries it counts; `AuthorshipTests` pin it. Review looks
  for any screen that would show a partner's standing.

## Rejected
- **SwiftData's own CloudKit sync** (`cloudKitDatabase: .private`): the private database only, so no partner
  (ADR-0026 §6), with its own conflicts, encryption and schema.
- **`NSPersistentCloudKitContainer` with a shared store:** a Core Data stack over the same file beside SwiftData,
  mirroring every attribute: no field rules (the kept title) and no say in what stays when sharing ends.
- **A share per child, or a record hierarchy** (`CKShare(rootRecord:)`): a parent chain on every record for what one
  zone-wide share does.
- **Hiding a card from the member it is about** (an `onlyFor` word and a birth-parent answer on the profile): the
  owner chose that everyone sees every card, which spares a stored field and a question.
- **Heroes and titles in the family zone:** a partner's iPhone would hold the other's hero and kept title outright;
  with entries alone, a comparison takes code that §3.5 forbids.
- **An outbox row written at every call site:** every write path would have to remember it; history comes with the
  write.
- **Whole-record last-writer-wins:** a rename lost to a skin-tone fix on the other phone.
- **Merging a first captured twice into one entry:** one parent's note or photos would go.
- **The iCloud user record id as the author:** there is none before sync, and a saga recorded offline needs an author
  from its first entry. The `Member` record ties the two once sync is on.
- **Deleting a row on `unknownItem`:** a re-created zone answers stale system fields the same way, and the saga would
  go row by row.
- **Writing remote changes by `#Unique`'s implicit upsert:** it would overwrite fields whose local change still waits.
- **Access requests to the share:** a way in for someone not invited, in an API Apple's iOS 26 betas called
  nonfunctional; the invitation is enough for two parents.
- **Deleting the saga on sign-out or an account switch** (Apple's sample): ADR-0026 §1.
- **A partner losing everything when sharing ends,** which is what a shared database alone gives: ADR-0006 §2.
- **An import into a shared family:** it would replace the partner's saga too.
- **Leaving the ids, authors and `#Unique` for a `SchemaV2`:** a custom stage, or columns whose nil means nothing; a
  stage removing duplicates that a real store could still fail; a format 2 of the copy.
- **Sync's bookkeeping in `SchemaV1`:** guessed now, frozen with the release, and inside every copy and start over.
- **`UICloudSharingController(preparationHandler:)`:** deprecated since iOS 17.
- **Telling a parent about the partner's entries** (a notification, a badge): pressure; ADR-0024 keeps one weekly
  notification.

## Deferred
- A parent adding their own words or photos to a first the partner captured; editing a partner's entry.
- More members than two: the owner chose two parents only (2026-11-22). Nothing in the records counts to two.
- The price of iCloud and co-op: decided with the pricing ADR. Copies stay free (ADR-0057 §1).
- `BGContinuedProcessingTask` for a very large first upload, if one stalls.

## The owner's answers (2026-11-22 and 2026-11-23)
1. iCloud without a partner: yes, in the same version as co-op (§1).
2. A partner who leaves is asked "Keep everything" or "Keep only what I recorded" (§4).
3. A partner who isn't a dad plays the same game, heroes and cards (§3.7), and every member sees every card,
   those that speak of "her" included (§3.8; first asked hidden, then changed the same day).
4. Two parents only (§2).
5. Either parent's copy holds the whole family, the partner's entries and photos included (§6).
6. The partner is shown by the first name from their Apple Account (§3.7).
7. Price: later, with the pricing ADR (Deferred).
8. A removed child is marked, not deleted, from the co-op version: either parent brings them back with every entry, or
   deletes them for good, for both, with calm words; PR 1 stores the mark only (2026-11-23; §4, §5).

## Verification status
Not built. The APIs above were checked against Apple's documentation on 2026-11-22 and 2026-11-23. What the
documentation doesn't settle, to check:
- whether `CKSyncEngine` gets its pushes without the app calling `registerForRemoteNotifications()`; if not, the app
  calls it while iCloud is on;
- `aps-environment` as `production` in the App Store archive;
- that `preserveValueOnDeletion` keeps a `UUID` and a `String` in the tombstone, that a `SchemaV1` store has history,
  that `#Unique` and the outfit's update agree, and that `replaceAll` restores over the same ids (package tests in
  PR 1 and PR 4, on a store on disk);
- that the engines resume from a `Sync.store` an iCloud Backup brought back, or fetch again without bringing back
  anything deleted;
- `ShareLink` with `CKShareTransferRepresentation` on iOS 26 through Messages and Mail, and the invitation opening
  DadSaga, warm and cold.

## Consequences
- Two parents keep one family's story on two iPhones, each with their own game and nothing to compare, without an
  account or server of ours; a dad alone keeps his saga on his own iPhones.
- One small PR before the first App Store release; the rest after it, in five PRs. Every entry has an author from the
  first saga, so co-op needs no migration of the saga's store.
- A second store, `Sync.store`, with its own versions, and a `CloudSync` target the widget never links.
- The privacy pages, the About statement, the camera's words and the support pages change when co-op ships; the
  manifests and the App Store label don't, while §7's conditions hold.
- Copies made before PR 1 no longer import, and a copy made by an older version leaves out what it can't name.
- A removed child can always come back, with every entry, until a parent deletes them for good: the one way a child
  and their entries go.
- The family's photos live in the inviting parent's iCloud storage, and a full iCloud becomes something the app says
  calmly.
- CloudKit's production schema, once deployed, can't be taken back.
