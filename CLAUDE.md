# DadSaga

An iOS app for new dads, heading for the App Store (FAFOUTIS BROTHERS E.E.), and a portfolio piece.
Replies to the owner are in Greek.

## Commands (Done = green)
```bash
swiftlint --strict
(cd Packages/DadSagaKit && mkdir -p .build && log=.build/tests.log; swift test --build-system swiftbuild > $log 2>&1; code=$?
  grep -E "^/.*error:|^error:|✘|Test run with" $log; exit $code)
xcodegen generate && xcodebuild build -quiet -project DadSaga.xcodeproj -scheme DadSaga \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```
- Green tests: exit status 0 and eight "Test run with" lines, one per test target, all passed.
- Keep command output out of the context: `xcodebuild` always with `-quiet`, tests filtered to failures and the summary
  as above. Read the full log only when the filtered one doesn't explain a failure.
- One suite: `swift test --build-system swiftbuild --filter DeepLinkTests` (from `Packages/DadSagaKit`).
- **Paused until the big features are done** (owner, 2026-11-20): screen snapshots and the accessibility audit are not
  run during development. Once the work is close to final, run both, re-record the snapshots and look at every image,
  and offer to put the snapshots in CI (that needs a new ADR: ADR-0034 runs them on the Mac). Until then, `ui-check`
  drawing a UI change in the simulator is its only check.
  - Screen snapshots: `xcodebuild test -project DadSaga.xcodeproj -scheme DadSagaSnapshots -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.2'`.
    A deliberate change: delete its images in `SnapshotTests/__Snapshots__`, run twice (record, then check).
  - Accessibility audit of the main screens (UI test, about five minutes):
    `xcodebuild test -project DadSaga.xcodeproj -scheme DadSaga -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.2' -only-testing:DadSagaUITests`
- While iterating, run only the suite you're changing (`--filter`); run the whole package once before the PR.
- `DadSaga.xcodeproj`, `Info.plist` and the entitlements are generated: change `project.yml`, then `xcodegen generate`.

## Rules that aren't in the code
- The product rules in [ADR-0006](docs/adr/0006-no-pressure-game-design.md) are non-negotiable: XP for the dad's actions
  only, no penalties, no streaks, no milestone deadlines.
- Game content is JSON in `Packages/DadSagaKit/Sources/Data/Resources`, in `el` and `en`. Never hardcode it in Swift.
- A new feature goes Domain → Application (use case protocol + `Default…`) → Data → Presentation (ViewModel + ViewState +
  View) → `App/DI/AppContainer.swift` ([ADR-0007](docs/adr/0007-clean-architecture.md)).
- Before a feature or a design question, check the [ADR index](docs/adr/README.md) for the ADRs on that topic.
- Record a significant decision as a new ADR in `docs/adr/`. Accepted ADRs aren't rewritten; a new one supersedes them.
  Add its row to the index, and note it under "Changed by" on any ADR it changes.
- A change in what the app handles (a stored field, a framework or SDK, an Info.plist key, a required-reason API)
  changes the privacy manifests and both privacy pages (`web/privacy`, `web/el/privacy`) in the same PR (ADR-0051).
  Releases follow `docs/RELEASE.md`.

## Engineering habits
- Subtract before you add: when new code covers an old path, delete the old path in the same change.
- Fix root causes: reproduce the bug in a test first, then fix the cause. A guard that hides the symptom is not a fix.
- Redesign, don't bolt on: for a new requirement, ask what you would have built had it been there from the start.

## Subagents
- A change across layers, or one touching persistence, sync, media or the film: `architect` plans first. A change in
  one layer only (a UI tweak, copy) skips the plan.
- `reviewer` checks every PR before it is opened, small ones too: it finds the most. It runs on Opus; for a PR touching
  persistence, migrations, sync or the film, call it with `model: fable`.
- One full review per PR. After fixing its findings, a re-review gets only the fixes: give it the last reviewed commit
  so it reads `git diff <that commit>..HEAD`, not the whole branch. Stop when only nits are left; nits don't start
  another round.
- `ui-check` draws every UI change in the simulator before it is called done (the iPhone Duo for the fold), and reports
  only what it saw, so the screenshots stay out of the main session. Its brief names only the states the change
  touches (the fold only for layout, dark only for colour, English only when text length matters). A re-check after a
  fix names only the screen and state the fix changed, not the whole first brief again.
- A subagent's brief names the ADRs that apply; it doesn't read the others.
- If a fix fails twice, stop and hand it to `fable-hard`. Fable is used normally (Max plan).
- `content` writes the cards; `fact-check` checks every card with health or safety information before the PR.

## Git
Gitflow ([ADR-0009](docs/adr/0009-gitflow.md)): `feature/<name>` from `develop`, PR back into `develop`.
- Work that touches the same files goes in one PR rather than several (e.g. the data model in one, all its UI in the next).
  Past that, keep PRs small: a feature can land in several PRs, each with its own review.
- One session per PR: start a new session for the next one rather than carrying a long history into it. Every message
  re-sends the whole history, so a session that keeps going after its PR is the most expensive way to work. Once a
  session's PR is opened, work for a different PR (a new feature, a cleanup, a CI change) is offered as a new session,
  not done here; only that PR's own review fixes and failing checks stay.
- Alone in the repository: a `feature/<name>` branch in the main checkout, no worktree.
- Several sessions at once: each works in its own git worktree, never in another session's checkout, which may switch
  branch under it.
- PR descriptions have no "Generated with Claude Code" line, and commits no "Co-Authored-By: Claude" trailer.
- Turn on Auto-fix for every PR as soon as it is opened, without asking.
