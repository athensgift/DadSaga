# Releasing DadSaga

The checklist for a TestFlight build and an App Store release. The decisions behind it are in
[ADR-0009](adr/0009-gitflow.md) (Gitflow) and [ADR-0051](adr/0051-signing-versioning-and-privacy-manifest.md)
(signing, versioning, privacy manifest). What counts as shipped is in
[ADR-0060](adr/0060-nothing-ships-before-the-first-app-store-release.md): only an App Store release.

## Once, before the first upload
- [ ] The app record in App Store Connect, with bundle id `com.athinodoros.dadsaga` (and the widget's
      `com.athinodoros.dadsaga.widget`) under the organization's team.
- [ ] `DEVELOPMENT_TEAM` in `project.yml` (ADR-0051 §4).
- [ ] The App Group `group.com.athinodoros.dadsaga` registered for both ids.
- [ ] Trader details for the EU (Digital Services Act): name, address, phone and email, entered and verified in App
      Store Connect. Verification can take weeks: start early.
- [ ] Privacy label: "Data Not Collected". It must match `web/privacy` and the privacy manifests.
- [ ] Age rating: "Medical/Treatment Information" is **Infrequent**.
- [ ] Accessibility Nutrition Labels: claim only what has been checked on every screen, in light and dark (the
      accessibility audit, ADR-0033); "Sufficient Contrast" only once dark mode has been checked too.
- [ ] App Store listing from `docs/appstore/` (text, screenshots, settings): the price is Free (ADR-0071), and the
      text claims only what the build does (no iCloud, no co-op, no restore from an iCloud backup).
- [ ] The App Store id in `DadSagaAppStoreID` (`project.yml`), so "Rate" and "Tell a friend" show.
- [ ] The website, in both languages, once the app is live (ADR-0031): the App Store badge instead of "coming to the
      App Store", and the Smart App Banner (`apple-itunes-app`).
- [ ] The website's accessibility line (`web/index.html` and `web/el/index.html`: large text, VoiceOver, Reduce Motion)
      holds after the accessibility audit; otherwise soften it with the description's.
- [ ] The website's video and screens drawn again (`docs/demo/README.md`) if what they show has changed. Known: the boss
      sheet's title is in the column since PR 109, and `worlds-en.jpg` shows the top of "9–24 months" (now 9–23).
- [ ] Privacy policy and support URLs per language, as `docs/appstore/README.md` lists them.
- [ ] The description's accessibility line (large text, VoiceOver, Reduce Motion) holds after the accessibility audit;
      otherwise soften it in `docs/appstore/` before submitting.

## Once, at the first App Store release
On the first release branch, for the build submitted for review (ADR-0060 §5). If review asks for another build, the
record follows that build; it is fixed once the build is released, and reaches `develop` when `main` is merged back.
- [x] ADR-0065's PR 1 is on `develop` (merged before the release branch): the profile id, the entries' authors, a child's
      `isRemoved`, `#Unique` ids and ids kept in history in `SchemaV1`; `hero.id`, `author` and each child's `removed`
      in format 1, whose reader takes any number of children from one. Both freeze with this build.
- [ ] What 1.0 ships of ADR-0065 (ADR-0067): PRs 1, 2a, 2b and 3, and PR 4, the sync core, all on
      `develop`. PR 4 is wired to nothing: no `import CloudKit` in any target, no iCloud entitlement, no `CKSharingSupported` or
      `remote-notification`, and no build creates `Sync.store`. `SyncSchemaV1` doesn't freeze with this build; it
      freezes with the co-op version (PR 5 and PR 6), whose release adds its own checks here: CloudKit's schema to
      production before its first TestFlight build, `aps-environment` as `production` in the archive.
- [ ] The Data tests run once on an iOS 26 simulator (the saga store's one queue, ADR-0068, and the `hasChanges` gate
      run in 1.0). The history pins (`ChangeFeedHistoryTests`: token expiry, another store's token, tombstones) run
      there again before the co-op version.
- [ ] Known and accepted: 1.0 keeps the store's history untrimmed (`StoreChangeFeed.trim()` runs only once PR 5 wires
      sync); the first co-op launch trims it.
- [ ] `Tests/DataTests/Fixtures/ShippedContentIDs.json`, from the bundled content: every world, hero, quest, boss,
      first, gear item and title id; each quest's and boss's skill and XP, and each first's XP; each gear item's skill;
      each title's order, cards, XP and gear; each skill's `halfGrownXP`. From then on it only grows.
- [ ] `ShippedContentIDsTests` (as ADR-0060 deleted it, without the `skillXPBeforeTitles` checks): every shipped id
      stays, as an id or a former id; every current id is listed; every former id and retired card shipped; nothing
      earned goes down or moves skill; no title asks for more or moves; no curve grows slower.
- [ ] `Tests/DataTests/Fixtures/StoreV1`, written by that build and never regenerated: a dad with a look and a partner
      answer; a child born and one not born yet; a quest, a boss and a first, with photos and a note; a wardrobe
      choice; a kept title and a closed title card. Its tests: the app opens a copy read-write and finds everything;
      the widget opens a copy read-only and reads it.
- [ ] `Tests/DataTests/Fixtures/SagaCopyV1`: recorded again with that build (a format-1 copy of the saga, ADR-0057 §4),
      then fixed: never recorded again.
- [ ] `.claude/rules/domain-and-data.md`: drop the "until the first App Store release" rules.

## Open device checks
What the ADRs say is still to be checked on a real phone or a real iPhone Duo; each ADR's own list has the details.
Tick them on the first TestFlight build.
- [ ] ADR-0055, titles: a title then Undo, the first quest after onboarding, deleting an old entry, no XP on screen, a
      Greek film on an English phone. Not its "installing over a version 6 build" (ADR-0060).
- [ ] ADR-0056 and ADR-0058, home: what is left of them (ADR-0061, ADR-0066) on a real iPhone Duo, with VoiceOver and at
      the accessibility text sizes.
- [ ] ADR-0057, the copy of the saga, with 500 photos or more: making, sharing, restoring, refusing a damaged or newer
      one; with VoiceOver, at the accessibility text sizes and on the iPhone Duo folded.
- [ ] ADR-0059, the skills' marks: under a celebration, after an Undo, light and dark, VoiceOver.
- [ ] ADR-0060, the calm screen with a store that can't be opened, in Greek and English; a fresh install's first quest,
      first with photos, widget, film and start over.
- [ ] ADR-0061, the four tabs, the map and Settings half-open, "My family" holding changes while a widget link waits, a
      link while a question is up.
- [ ] ADR-0066, home in one column, on a real iPhone Duo.

## Every TestFlight build before the first App Store release
- [ ] Compare with the last uploaded build: the release branch's commit that set its build number (ADR-0060 §6). The
      build "changes the store or the ids" if `SchemaV1` changed, or a content id was renamed or removed, since then.
- [ ] If it does, its notes for testers ("What to Test") say, in Greek and English, to delete DadSaga before installing
      it, and that what was recorded in earlier builds isn't kept.
- [ ] If it changes format 1 of a copy so that copies from earlier builds no longer import (ADR-0065's PR 1 does), its
      notes say that too.

## Every release
1. **Branch.** `git switch develop && git pull`, then `git switch -c release/<version>`.
2. **Number it** in `project.yml`: `MARKETING_VERSION` to `<version>`, `CURRENT_PROJECT_VERSION` to the last uploaded
   build plus one. `xcodegen generate`. Commit.
3. **Checks**, all green:
   - the three commands in `CLAUDE.md`
   - the screen snapshots and the accessibility audit (`CLAUDE.md`), every image looked at
   - a Release build on a device: onboarding, a quest, a first with photos, the film, the widget, start over
4. **Privacy.** If anything the app touches changed since the last release: the manifests, both privacy pages and the
   App Store label agree (ADR-0051 §1).
5. **Archive** in Xcode: scheme `DadSaga`, destination "Any iOS Device", Product → Archive, then Distribute App →
   App Store Connect.
6. **TestFlight.** Install it, and repeat the device checks on the build Apple processed. Before the first App Store
   release, install it on a phone without a `develop` build, so it starts from onboarding as a dad's would.
7. **Submit** for review with release notes in Greek and English.
8. **Merge** once Apple approves: `release/<version>` into `main` through a PR, tag `v<version>` on `main`, then merge
   `main` back into `develop`.

A TestFlight build that is never released still takes its build number, and the next upload takes the next one. It
gets no tag, and the release branch stays open until a build is released.

## A hotfix
`hotfix/<name>` from `main`. Raise the patch number and the build number, then follow steps 3–8 as above, merging into
`main` (tagged) and into `develop`.
