# ADR-0065: Partner co-op: both parents share one family's saga through iCloud, each with their own hero and title

**Status:** Proposed (2026-11-22). Drafted by the architect for the version after the first App Store release, as the
roadmap asks ("Sync ADR before Phase 5") and ADR-0026 §6 deferred. One part is for **before** that release: §5's
changes to `SchemaV1` and to format 1 of a copy, since both freeze with that build (ADR-0060). The product questions
were answered by the owner on 2026-11-22 (folded in below; the answers are listed at the end). It changes:
- **ADR-0004:** once a parent turns sharing on, the family leaves the iPhone for the inviting parent's iCloud and
  reaches the partner, and each hero goes to its own parent's iCloud. Still no account, backend or server of ours.
- **ADR-0006:** with two parents, each one's XP, title and gear come only from the entries they recorded; firsts are
  the family's; nothing compares the two (§3).
- **ADR-0016:** with sharing on, photos go to iCloud as stored, byte for byte.
- **ADR-0026 §6 and Deferred:** decided here. §3 (`cloudKitDatabase: .none`) stays, and now matters: with an iCloud
  entitlement, SwiftData would otherwise mirror the store by itself.
- **ADR-0030 §7, §8:** the About statement names iCloud; start over on a shared family first ends this parent's part
  in it.
- **ADR-0053 §4:** a new `onlyFor` word, `notBirthParent`, and the fact behind it, whether this player is the parent
  who gave birth (§3).
- **ADR-0057 §2, §3, §7:** format 1 carries the hero's id and each entry's author; a copy of a shared family holds
  both parents' entries; no import while the saga is shared.
- **ADR-0060 §2 and Deferred:** `SchemaV1` gains a profile id, an author on every entry, the birth-parent answer,
  `#Unique` ids, and ids kept in history.

## Context
- **What is stored** (`SchemaV1`, ADR-0060 §2): one `ProfileRecord` (hero, look, partner answer, `heldTitleID`,
  `seenTitleID`) with no id of its own; `ChildRecord` by `childID`; `ProgressEventRecord` by `eventID` with its child,
  kind, content id, date, note and `photoIDs`, and no author; `OutfitRecord` by `skill`. No `#Unique`. Photos are
  `MomentPhotos/<UUID>.jpg` in the App Group (`FilePhotoStore`). Nothing derived is stored: XP, skills, cards done and
  the title come from every event (`DadProgress`, `DadStanding`), with the kept title on the profile row (ADR-0055 §3).
- **Writes** go through five `@ModelActor` repositories, each in one `saveAllOrNothing`. "My family" saves the whole
  family: `SwiftDataProfileRepository.save` deletes every stored child the edited list lacks. A boss or a first is
  checked and stored in one step, by kind, content and child (`addUnlessRecorded`).
- **The content speaks to a dad.** Heroes are dad archetypes (ADR-0010); bosses such as "The Big Day" speak of "her";
  partner-only cards follow the dad's partner answer (ADR-0053, ADR-0054).
- **The timing.** Until the first App Store release, `SchemaV1` and format 1 of a copy change in place; both freeze
  with that build (ADR-0060 §1, §5). After it, a column added with a value per row (an id, an author) needs a custom
  stage, or an optional column whose nil means nothing, which ADR-0060 §2 has just removed; a `#Unique` added to a
  released store holding one duplicate stops that store from opening; and a new copy field is a format 2, read
  forever (ADR-0057 §4).
- **What Apple documents (checked 2026-11-22):**
  - `CKSyncEngine` (iOS 17): "You can have multiple instances … each targeting a different database. For example, you
    may have one syncing a person's private database and another syncing their shared database." It "requires the
    CloudKit and Remote notifications entitlements", and "it's your responsibility to persist that state"
    (`Event.stateUpdate`). Changes are added with `state.add(pendingRecordZoneChanges:)` and handed over from
    `nextRecordZoneChangeBatch(_:syncEngine:)`; `RecordZoneChangeBatch(pendingChanges:recordProvider:)` walks them in
    order and stops at the 250-record limit. The engine retries network, account and rate-limit errors itself; "if
    you try to save a record and get a `serverRecordChanged`, you need to handle that error yourself". After a save,
    "encode the system fields of this record to use the next time you save". On an account change it "resets its
    internal state, including unsaved changes to both records and record zones", and sends `accountChange` with
    `signIn`, `signOut` or `switchAccounts` and the user record ids. A zone deletion has a reason: `deleted`, `purged`
    (the person deleted the app's data in Settings) or `encryptedDataReset`. `CKSyncEngineDelegate` is
    `AnyObject, Sendable`; events come one at a time, and `fetchChanges`/`sendChanges` are not called from
    `handleEvent`. Never for the public database. WWDC23 (10188): one engine per database; `automaticallySync = false`
    and two engines as two devices in tests; "it will automatically start listening for push notifications".
  - `CKShare(recordZoneID:)` (iOS 15): custom zones in the private database can be shared whole; "A record zone, and
    the records it contains, can take part in only a single share." The participant finds the zone in their shared
    database.
  - Inviting: `CKShareTransferRepresentation` (iOS 16) for `ShareLink`, with
    `ExportedShare.prepareShare(container:allowedSharingOptions:preparationHandler:)` or
    `.existing(_:container:allowedSharingOptions:)`; `CKAllowedSharingOptions` (permission and access options,
    `allowsParticipantsToInviteOthers` off by default). `UICloudSharingController(share:container:)`: the owner adds or removes people and stops sharing;
    a participant views the people and leaves. `init(preparationHandler:)` is deprecated since iOS 17.
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
    store, with no switch named. `#Unique` (iOS 18) upserts on a matching value. Most of these pages are declarations
    only, as ADR-0060 found for migrations.
  - App privacy details: "Collect" means "transmitting data off the device in a way that allows you and/or your
    third-party partners to access it"; under CloudKit: "You are not responsible for disclosing data collected by
    Apple."
  - iCloud Shared Photo Library (support.apple.com/111758): a member who leaves chooses "Keep everything" or "Keep only
    what I contributed"; when the organizer deletes the library, members receive everything.
  - Nothing here needs more than iOS 18; the app requires iOS 26 (ADR-0002).

## Decision

### 1. What syncs, and where
- **Off until a parent turns iCloud on.** Until then nothing leaves the iPhone, as today. Two steps, in the same
  version: **iCloud** alone keeps a dad's saga on his own iPhones (the private engine, no share); **sharing** with a
  partner (§2) needs iCloud on and adds the share.
- **Two kinds of custom zone:**
  - **`Personal`,** in each parent's private database: their hero, look, partner answer, kept and seen title, and
    wardrobe. Only their own iPhones read it. A new iPhone on the same Apple Account gets the same profile id back, so
    the entries they recorded stay theirs.
  - **`Family-<UUID>`,** in the private database of the parent who invites (the owner), shared whole with a zone-wide
    `CKShare`: the children, every entry, every photo. The partner reads and writes it through their shared database.
- **Records.** A record's name is its type and its stable id. Every field but a photo's asset is in
  `encryptedValues`, from the first deployment (it can't be added later). Values are the strings the store holds,
  never Swift case names; an unknown one is read as the store reads it (an unknown kind is skipped, an unknown look
  part is the standard one).

  | Type | Name | Zone | Fields |
  |---|---|---|---|
  | `Hero` | `hero-<profileID>` | Personal | `classID`, `skinTone`, `hair`, `hairColor`, `beard`, `glasses`, `hasPartner`, `isBirthParent`; `heldTitleID`, `seenTitleID` (absent: nil) |
  | `Wardrobe` | `wardrobe-<skill>` | Personal | `choice` (`hidden` or `item:<id>`); an automatic slot has no record |
  | `Child` | `child-<childID>` | Family | `name`, `gender`, `skinTone`, `order`; `birthDay` as `yyyy-MM-dd`, absent while not born, one field so a day moves whole |
  | `Entry` | `entry-<eventID>` | Family | `author` (a profile id), `kind`, `contentID`, `childID`, `date`, `note` (absent: none), `photoIDs` (in order) |
  | `Photo` | `photo-<photoID>` | Family | `image`: a `CKAsset` of the stored JPEG; `entryID` |

- **No references and no `parent`:** a zone-wide share needs no hierarchy, references aren't encrypted, and removing
  a child must not cascade to its entries (ADR-0012). Records name each other by id.
- **A photo is a record of its own,** written once and never changed, so editing a note never uploads a photo again.
  A batch is filled in order: children, entries, then photos, so a partner's timeline fills before its pictures. An
  entry that arrives before its photo shows without it until the photo comes. A downloaded photo is written under its
  own id, byte for byte (`PhotoStore.place(_:id:)`), never re-encoded (ADR-0042 §1).
- **Never synced:** the film offers answered, the weekly reminder, the preferences and the film sheet's choices, which
  belong to each iPhone (ADR-0057 §2). Each parent is offered the family's film on their own phone.

### 2. Sharing, joining, and how changes move
- **Sharing.** Settings gets a page to share the saga with a partner (words by `content`). Sharing first uploads the
  Personal and Family zones, then offers the invitation: `ShareLink` with `CKShareTransferRepresentation` and
  `prepareShare`, which saves a zone-wide `CKShare` with read and write for invited people only, and no inviting
  others.
- **Two parents only.** The page offers an invitation only while the family has no partner. If a second person accepts
  anyway (the owner added one in "Manage sharing"), their DadSaga says calmly that this family already has two parents
  and doesn't join; the owner's sharing page shows the extra person to remove. Nothing in the records counts to two:
  the limit is the app's. The share's title and thumbnail carry no names or photos ("DadSaga"): the invitation travels through
  Messages or Mail. Once shared, "Manage sharing" opens `UICloudSharingController(share:container:)`. These CloudKit
  views live in the App target and reach Presentation as views through `AppContainer`, as `UIKitBackgroundTime` does
  (ADR-0057 §10); Presentation doesn't import CloudKit.
- **Accepting.** `CKSharingSupported` opens DadSaga from the invitation. A scene delegate
  (`windowScene(_:userDidAcceptCloudKitShareWith:)`, and `cloudKitShareMetadata` on a cold launch) puts it in a
  `ShareInbox`, which waits like any link while an editor holds unsaved changes (ADR-0050 §4). The app says who
  invited them and asks; only a yes accepts. The family's records reach the store only once the join is finished;
  until then they wait in `Sync.store` (§5).
- **Joining an iPhone with no saga:** the partner chooses their own hero and look; the family comes from the share.
- **Both are asked one question** when they turn sharing on or join, in neutral words (by `content`): some cards speak
  about the parent who gave birth; is that you? The answer is theirs alone, in their Personal zone, and they can change
  it in "Your hero" (§3.8).
- **Joining an iPhone with a saga:** their hero, look, wardrobe and title stay theirs. Each of their children is
  matched to one of the family's (by name first; they confirm), and its entries move to that child and join the family
  as theirs. A child they don't match joins the family as a new one; past four children, one is matched or removed
  first (a removed child's entries stay, hidden, ADR-0012). Nothing they recorded is dropped.
- **One `CKSyncEngine` per database:** the private one (Personal, and Family for the owner) and the shared one (Family
  for a partner), reporting to one delegate actor. Each engine's state is persisted on every `stateUpdate`.
- **Local changes come from the store's history, not from every call site.** `StoreChangeFeed` reads the SwiftData
  history after its token. Each change in a transaction whose author isn't `sync` becomes a pending save with the
  fields it changed (`updatedAttributes`), or a pending delete named by the id its tombstone kept (§5). An entry's
  photos to save or delete come from comparing its `photoIDs` with the photos `Sync.store` knows for it. The pending
  changes and the new token are written in one save of `Sync.store`, then given to the engine; at every launch all of
  them are given again. A change leaves `Sync.store` once the engine reports it sent, and history is deleted up to the
  token. So a write and its sync can't come apart, and a write path added later syncs without anyone remembering to.
- **Remote changes** are written by one `@ModelActor`, `SwiftDataSyncApplier`, whose context's `author` is `sync`, so
  they never come back as local changes. It upserts by id. After a fetch that changed something, the widget's
  timelines reload (ADR-0023).
- **Starting.** Turning sharing on enqueues every row once; the change feed starts from the token taken then.
  Onboarding's first step offers "Continue from iCloud" beside "Import data": it reads the Personal and Family zones of
  that Apple Account, only when tapped. An iPhone with a saga whose Apple Account's iCloud already holds another asks
  which to keep, in the import's words (ADR-0057 §8); neither is merged or deleted without that answer.

### 3. Two parents, and what ADR-0006 means for them
1. **Each parent is a player.** Their hero, look, wardrobe, XP, skills, title, level and gear come only from entries
   whose `author` is their profile id. A partner's entry never adds to them or takes from them.
2. **The family is shared.** The children, the timeline, firsts and moments, every photo, the film's entries and the
   widget's latest moment come from every entry, whoever recorded it.
3. **Quests and bosses are what a parent does:** each parent's cards, map and weekly line show their own. **Firsts
   are what a child does:** captured once per child by whichever parent was there. The one who captured it gets its XP
   (ADR-0006 §1); the other sees it captured, with the name of who did.
4. **Each parent edits and deletes only their own entries** (ADR-0021); the partner's open to read. Both edit the
   family: add, change and remove children. Neither is above the other.
5. **Nothing compares them.** The partner's hero, title, level, XP, skills and card counts never reach the other's
   iPhone (they live in the Personal zone), so no screen can show them. No totals for the two, no "who did more", no
   leaderboard; no notification, badge or count about the partner's entries: they appear in the timeline. The film's
   credits name the title of the parent who makes it, as now (ADR-0055).
6. **Nothing is lost.** A parent's entries stay theirs on a new iPhone (§1), when sharing ends (§4) and in a copy (§6).
7. **Neutral.** A partner is shown by the first name the share gives
   (`CKShare.Participant.userIdentity.nameComponents`, short form), or by a neutral label without one; never by a role
   or a gendered word. The app never asks a member's gender or whether they are a dad. A partner who isn't a dad joins
   the same game, heroes and cards (owner, 2026-11-22). Each member's partner-only cards follow their own partner
   answer, which starts at yes for a joiner.
8. **A card about the parent who gave birth is hidden from that parent** (owner, 2026-11-22). Such cards (bosses such
   as "The Big Day", quests that speak of "her" recovering or feeding) carry `"onlyFor": ["partner", "notBirthParent"]`
   in the content. `Audience.notBirthParent` holds when the player's `isBirthParent` is false; `FamilyFacts` takes it
   from the profile, so `UnlockRules` needs no change. The fact is the one question of §2, not a gender: it asks
   nothing the cards don't need, and it fits a dad who gave birth, two dads, or a family where no one did (every
   answer no: the cards show, as today). It is a fact about the player, not the family, so it lives on the profile
   and never reaches the partner. `content` marks the cards, and the owner reviews the list; a content rule checks that
   `notBirthParent` comes only with `partner`. The mark changes no stored id. A card already done stays in the
   timeline, whatever the answer.

### 4. Conflicts, and when sharing ends
- **Merge by field.** A pending save carries only the fields this iPhone changed, set on the record rebuilt from the
  last system fields `Sync.store` keeps. On `serverRecordChanged` the delegate takes the error's server record, sets
  its own changed fields on it, and saves again: every field it didn't change keeps the server's value. The same field
  changed on both sides: the later save wins. A remote record that arrives while a local change waits is applied
  except for the waiting fields, which go after it.
- **Fields that time doesn't decide:** `heldTitleID` takes the higher of the two titles, whatever the order of saves,
  since a kept title never goes down (ADR-0055 §3; a Domain rule on `KeptStanding`). Two children with the same
  `order` are shown by order, then id. More than four children after two offline additions are all kept, and "My
  family" adds none until there are fewer.
- **Every edit says what changed.** "My family" saves a `FamilyEdit` (children added and removed, and the fields
  changed on each), taken from what the editor showed when it opened, not the whole family as it stands; hero and
  entry edits do the same, and a row update sets only the columns whose value changes. Otherwise a family edited on one
  iPhone while the partner added or renamed a child would delete that child or undo the rename.
- **Entries rarely meet.** Only an entry's author edits it, so a conflict on one is between that parent's own iPhones,
  merged by field. A first captured by both parents before either synced keeps both entries, with both notes and both
  sets of photos; it counts once for the child, and each capturer's XP counts their own. No entry is merged away.
- **Deletions** travel as CloudKit deletions; the saga store keeps no tombstone rows. A deletion wins over an edit made
  at the same time: a save that fails with `unknownItem` is dropped and the row is deleted here. An entry is deleted by
  its author; a child by either parent, and its entries stay, hidden (ADR-0012).
- **Leaving:** a partner who leaves from "Manage sharing" is asked once, calmly: **Keep everything** (first) or **Keep
  only what I recorded** (the children and their own entries). The family zone keeps what they recorded, as Shared
  Photo Library keeps a leaver's photos. **Stopping:** when the owner stops sharing, every partner keeps everything,
  without a question, and the owner keeps the zone. Afterwards each iPhone's saga is its own; with iCloud on, a
  partner's goes to a new family zone of theirs.
- **A zone that goes:** `purged` (the parent deleted DadSaga's iCloud data in Settings) turns sync off on that iPhone,
  and nothing is uploaded again by itself; `encryptedDataReset` uploads the owner's family into a new zone, and the
  partner is invited again; `deleted` by another of the owner's iPhones turns sync off here. For a partner, the shared
  zone going is the owner stopping. A zone that goes never deletes the saga on the iPhone.
- **The account.** `signOut`: sync pauses, the saga stays, and `Sync.store`'s pending changes are given again when
  the same account returns (its user record id is kept). `switchAccounts`, or a sign-in to another account: sync stays
  off for this saga until the parent turns it on for that account. Nothing is uploaded into another person's iCloud by
  itself, and nothing is deleted (ADR-0026 §1), where Apple's sample deletes local data.
- **iCloud full** (`quotaExceeded`, which the engine doesn't retry): changes wait in `Sync.store`, the saga is
  untouched, and the sharing page says whose iCloud is full; the family's photos count in the owner's.
- **Start over** on a shared family first ends this parent's part: the owner stops sharing and deletes the Family and
  Personal zones; a partner leaves and deletes their Personal zone. Then it erases the iPhone, `Sync.store` included
  (ADR-0030 §8). Its confirmation says the partner keeps their saga.

### 5. The store: what goes in `SchemaV1` now, and what never goes in it
**Before the first App Store release,** in one PR before the release branch (devices running `develop` delete the app
first, ADR-0060 §2):

| Change | Why now, not in a `SchemaV2` |
|---|---|
| `ProfileRecord.profileID: UUID`, made at onboarding; Domain `PlayerProfile.id` | An author needs an identity. Later: a custom stage to make one, or an optional column whose nil means nothing |
| `ProgressEventRecord.authorID: UUID`, the profile's id on every entry; Domain `ProgressEvent.authorID`, set by `EventRecorder` | The same. Later: a stage that fills every row |
| `ProfileRecord.isBirthParent: Bool`, false; Domain `PlayerProfile.isBirthParent`. Nothing asks it until co-op (§3.8) | Later: an additive `SchemaV2` and a copy format 2 for one Bool. Now: a column every saga holds as false |
| `#Unique` on `ChildRecord.childID`, `ProgressEventRecord.eventID`, `OutfitRecord.skill`, `ProfileRecord.profileID` | The applier upserts by id. Later: a released store with one duplicate fails to open at the migration and shows a real dad the calm screen (ADR-0026 §1), unless a stage removes duplicates first |
| `@Attribute(.preserveValueOnDeletion)` on those four ids | The change feed names a deleted row by its id (§2). Later: one more change to a released model, with its version and fixture test (ADR-0026 §2), for one option |
| Format 1 of a copy: `hero.id`, `hero.isBirthParent` and each entry's `author`, all required | The format freezes with the same build (ADR-0060 §1). Later: a format 2, read forever (ADR-0057 §4) |

- **Subtracted with it:** the duplicate-child clean-up in `SwiftDataProfileRepository.save` (a duplicate can't exist
  any more); `SwiftDataOutfitRepository.setChoice`'s delete-then-insert becomes an update or a delete of the one row;
  `SchemaV1`'s comment "no `#Unique`". The single-profile rule stays: an iPhone holds one player, and the partner's hero
  is never stored there (§3.5).
- **A restore** sets the profile id to the copy's `hero.id` and keeps every entry's author. The `SagaCopyV1` fixture is
  recorded again (it has neither key), as ADR-0060 §5 does at the release anyway. `SagaCopyRules` gains nothing: an
  author is any id, since a partner's entries carry theirs.
- **Nothing on screen changes:** until co-op ships, every entry's author is the one profile.

**Sync's bookkeeping never goes in the saga's store: it is `Sync.store`,** a second SwiftData store beside
`DadSaga.store` in the App Group, with its own versioned schema (`SyncSchemaV1`), created when sync is first turned on,
never opened by the widget, never in a copy, erased by start over. It holds each record's system fields by name; the
pending changes and their fields; each engine's state; the history token; the family zone, whether this iPhone owns
it or joined it, and the account's user record id; the partners' names from the share; the photos known for each
entry; and a joining family's records until the join ends. Its shape follows the engine work, so it isn't guessed into
`SchemaV1` now; kept apart, the copy test (every stored property in format 1, ADR-0057 §4), start over and the widget
stay about the saga. It sits beside the saga so an iCloud Backup brings both back together.

**So co-op is expected to need no `SchemaV2`.** If it ever does, it is an additive, lightweight version from the
`StoreV1` fixture (ADR-0060 §5).

### 6. Copies of the saga, and backups
- **A copy** (ADR-0057) of a shared family is the saga as this iPhone has it: every child, every entry with its author
  (the partner's too, with notes and photos), and this parent's hero, title and wardrobe; never `Sync.store`. Either
  parent's copy holds the whole family (owner, 2026-11-22); the export text says it holds the partner's entries.
- **No import while the saga is shared:** the import part of the page says to stop sharing or leave first, since
  replacing the family would replace it for the partner too. After that, an import replaces this iPhone's saga and
  keeps its authors: the restorer becomes the copy's hero, and a partner's entries stay the partner's and count for no
  one here. With iCloud on, it goes to a new family zone.
- **iCloud Backup** is unchanged; `Sync.store` comes back with the store, and the engines carry on from the restored
  state (checked on a device). With sharing on, a new iPhone also gets the saga from iCloud without a backup (§2).

### 7. Entitlements, Info.plist and privacy
- **`project.yml`, the app only** (the widget never syncs):
  - entitlements: `com.apple.developer.icloud-services: [CloudKit]`; `com.apple.developer.icloud-container-identifiers:
    [iCloud.com.athinodoros.dadsaga]` (a container can never be deleted or renamed: chosen once); `aps-environment:
    development`, which the App Store export signs as `production` (checked in the archive);
  - Info.plist: `CKSharingSupported: true`; `UIBackgroundModes: [remote-notification]`; `NSCameraUsageDescription`
    stops saying "Photos stay on this device" (words by `content`).
  - `NotificationDelegate` returns a scene configuration naming the scene delegate (§2).
- **Every `ModelConfiguration` keeps `cloudKitDatabase: .none`** (ADR-0026 §3), `Sync.store`'s too.
- **The privacy manifests don't change.** CloudKit isn't a required-reason API, and nothing is collected: the developer
  can't read anyone's private or shared database, and Apple's page counts CloudKit as data Apple collects. The App Store
  label stays "Data Not Collected".
- **Both privacy pages** change in the PR where data can first leave (ADR-0051), with a section on iCloud and the
  partner: off until you share; what goes where (the family to the inviting parent's iCloud, in their storage; your
  hero, title and wardrobe to your own iCloud only); who sees it (the people in the share, and Apple under its terms);
  encrypted on the iPhone before it goes, and with Advanced Data Protection only the people in the share hold the keys;
  how to stop (stop sharing or leave, start over, or delete DadSaga's data in iCloud settings) and what stays after
  (§4). The storage, "Children" and "Deleting your data" paragraphs change. The About statement (ADR-0030 §7) adds
  iCloud; the support pages answer how to move to a new iPhone through iCloud.

### 8. Testing
- **Seams.** A `SyncEngine` protocol covers what the delegate uses of `CKSyncEngine` (add pending changes, fetch,
  send, events, state), over `SyncRecord`, a `Sendable` value (type, name, fields, asset file, system fields as data).
  Only `CloudKitSyncEngine` and the App's sharing views import CloudKit; a `CKRecord` never leaves that actor. In tests
  a `FakeCloud` keeps zones and change tags, answers `serverRecordChanged` with the server record and `unknownItem` for
  a deleted one, deletes zones with each reason, changes accounts and runs out of quota; two `FakeSyncEngine`s on one
  `FakeCloud` are two iPhones.
- **Suites:** `ChangeFeedTests` (history to pending changes on a store on disk: fields, ids kept on deletion, `sync`
  writes skipped), `FieldMergeTests`, `SyncRecordMappingTests` (real `CKRecord`s, offline), `AuthorshipTests` (§3, in
  the Domain), `FamilyEditTests`, `TwoParentsSyncTests` (both record offline; both edit a child; one removes it; a
  first captured twice; leave; stop; purge; account switch; quota), `JoinFamilyTests`, and the import refused while
  shared.
- **On devices:** two iPhones, two Apple Accounts with iCloud, Debug builds (CloudKit's development environment):
  invite through Messages; accept with DadSaga open and closed; both offline, then online; a child edited on both; 500
  photos sent and received; a push with the app in the background, and the widget after it; leave, stop and start over
  on each side; sign out and switch account; DadSaga's data deleted in iCloud settings; an iCloud Backup restored.
- **Schema:** the development schema comes from the first saves. Before the first TestFlight build with co-op
  (TestFlight and App Store builds use the production environment), it is deployed to production in CloudKit Console.
  From then on record types and fields can only be added, and which fields are encrypted is fixed (§1).

### 9. Where the code goes
Each PR goes Domain → Application → Data → Presentation → `AppContainer` (ADR-0007), is planned by `architect` and
reviewed with Fable (persistence and sync). Strings by `content`; every screen through `ui-check`.
1. **Ids and authors, before the first App Store release branch.** Domain: `PlayerProfile.id`,
   `PlayerProfile.isBirthParent` (false, asked by nothing yet), `ProgressEvent.authorID`. Application: `EventRecorder` and the three recording use cases take the author, read
   through `ProfileRepository`; onboarding makes the id. Data: §5's `SchemaV1`, the mappers, `SagaCopyV1DTO`, the
   fixture copy, the two subtractions. App: wiring. Nothing on screen.
2. **Two players** (co-op version, as are the rest). Domain: `DadProgress` from one author's entries, family firsts
   from all, `TimelineEntry.authorID`, `FamilyEdit`, the `KeptStanding` merge. Application: home, map, timeline, film,
   highlights and edits split into own and family; `ProfileRepository` saves a `FamilyEdit`. Data: updates set only
   changed columns. Nothing visible changes for one parent.
3. **Sync core, without CloudKit.** Application: a `FamilySync` port and `ShareStatus`. Data: `Sync.store`,
   `StoreChangeFeed`, `SwiftDataSyncApplier`, `SyncRecord` and its mappings, `FieldMerge`, `SyncCoordinator`, the
   `SyncEngine` port, `FakeCloud`. Nothing wired.
4. **CloudKit.** Data: `CloudKitSyncEngine` (the two engines and the delegate actor), zones, the share, accepting,
   `FilePhotoStore.place`. App: the scene delegate, `ShareInbox`, wiring with sync off, `project.yml` (§7). Web: both
   privacy pages, the About statement, the camera's words: the first PR in which data could leave.
5. **The sharing screens, and iCloud alone.** The iCloud switch for a dad alone; the birth-parent question;
   `content` marks the cards with `notBirthParent` (Domain `Audience` gains it, with its content rule). Application: `StartSharingUseCase`, `JoinFamilyUseCase` (with the matching),
   `EndSharingUseCase`, `KeepAfterLeavingUseCase`. Presentation: `FamilySharingViewModel`, `FamilySharingViewState`,
   `FamilySharingView`; `JoinFamilyViewModel` and its view; the leaving question; the partner's name on timeline rows
   and their entries opened to read; the import page's note. App: `FamilyShareLink` (`Transferable` with
   `CKShareTransferRepresentation`), `CloudSharingControllerView`.
Then §8 on devices, the schema to production, and TestFlight.

## Risks
- **Swift 6:** `CKSyncEngineDelegate` is `AnyObject, Sendable` with `async` methods: an actor. `CKRecord` and
  `CKAsset` stay inside it; only `SyncRecord` crosses. The scene delegate is on the main actor and only hands the
  invitation to `ShareInbox`. Remote writes go through the applier's `@ModelActor`, never a repository's context, which
  would echo them back.
- **The App Group lock:** a fetch woken by a push writes the shared SQLite file; the app must not be suspended
  mid-write (`0xdead10cc`, ADR-0057), so applying runs under `beginBackgroundTask`.
- **SwiftData:** history, tombstones and `#Unique` are documented by declaration; every behaviour this leans on is
  pinned by a package test (PR 1 and PR 3), and a row update setting an equal value must not count as a change.
- **CloudKit's production schema is permanent:** record types, field names and encryption are reviewed once more
  before it is deployed.
- **ADR-0006:** every Domain query that counts says whose entries it counts; `AuthorshipTests` pin that a partner's
  entry changes nothing of mine. Review looks for any screen that would show a partner's standing.

## Rejected
- **SwiftData's own CloudKit sync** (`cloudKitDatabase: .private`): the private database only, so no partner
  (ADR-0026 §6), with its own conflicts, encryption and schema.
- **`NSPersistentCloudKitContainer` with a shared store:** a Core Data stack over the same file beside SwiftData,
  mirroring every attribute: no field rules (the kept title) and no say in what stays when sharing ends.
- **A share per child, or a record hierarchy** (`CKShare(rootRecord:)`): a parent chain on every record for what one
  zone-wide share does.
- **Heroes and titles in the family zone:** a partner's iPhone would hold everything a comparison needs.
- **An outbox row written at every call site:** every write path would have to remember it; history comes with the
  write.
- **Whole-record last-writer-wins:** a rename lost to a skin-tone fix on the other phone.
- **Merging a first captured twice into one entry:** one parent's note or photos would go.
- **The iCloud user record id as the author:** there is none before sync, and a saga recorded offline needs an author
  from its first entry.
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

## The owner's answers (2026-11-22)
1. iCloud without a partner: yes, in the same version as co-op (§1).
2. A partner who leaves is asked "Keep everything" or "Keep only what I recorded" (§4).
3. A partner who isn't a dad plays the same game, heroes and cards (§3.7); a card about the parent who gave birth is
   hidden from that parent (§3.8, §5).
4. Two parents only (§2).
5. Either parent's copy holds the whole family, the partner's entries and photos included (§6).
6. The partner is shown by the first name from their Apple Account (§3.7).
7. Price: later, with the pricing ADR (Deferred).

## Open questions for the owner
1. **The words of the birth-parent question** (§2), and **the list of cards** `content` marks `notBirthParent`: both
   for the owner to read before PR 5.

## Verification status
Not built. The APIs above were checked against Apple's documentation on 2026-11-22. What the documentation doesn't
settle, to check:
- whether `CKSyncEngine` gets its pushes without the app calling `registerForRemoteNotifications()`; if not, the app
  calls it while sync is on;
- `aps-environment` as `production` in the App Store archive;
- that `preserveValueOnDeletion` keeps a `UUID` and a `String` in the tombstone, that a `SchemaV1` store has history,
  and that `#Unique` and the outfit's update agree (package tests in PR 1 and PR 3, on a store on disk);
- that the engines resume from a `Sync.store` an iCloud Backup brought back, or fetch again without bringing back
  anything deleted;
- `ShareLink` with `CKShareTransferRepresentation` on iOS 26 through Messages and Mail, and the invitation opening
  DadSaga, warm and cold.

## Consequences
- Two parents keep one family's story on two iPhones, each with their own game and nothing to compare, without an
  account or server of ours.
- One small PR before the first App Store release; the rest after it, in five PRs. Every entry has an author from the
  first saga, so co-op needs no migration of the saga's store.
- A second store, `Sync.store`, with its own versions.
- The privacy pages, the About statement, the camera's words and the support pages change when co-op ships; the
  manifests and the App Store label don't.
- The family's photos live in the inviting parent's iCloud storage, and a full iCloud becomes something the app says
  calmly.
- CloudKit's production schema, once deployed, can't be taken back.
