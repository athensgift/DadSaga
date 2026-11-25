# ADR-0051: Signing, versioning and the privacy manifest

**Status:** Accepted (proposed 2026-11-21, accepted by the owner 2026-11-25). From the review of 2026-11-21 (§0.6, §0.7 point 4 and "CI και κυκλοφορία"); the
owner asked for the release preparation. Adds to ADR-0009 (how a release is numbered and built) and ADR-0004 (how the
app tells Apple what it touches), and changes ADR-0034 §5 (CI compiles the snapshots). The steps themselves are in [`docs/RELEASE.md`](../RELEASE.md).

## Context
- Nothing has been released yet: `main` has never had a release or a tag, and how builds are numbered was never decided.
- App Store Connect rejects an upload without a privacy manifest when the app calls an API Apple lists as needing a
  reason. The app and the widget call two: `UserDefaults` (settings, reminders, film choices) and a file's
  modification date (`contentModificationDateKey`, when the orphan photo sweep of ADR-0048 lists its photos).
- Without `ITSAppUsesNonExemptEncryption`, App Store Connect asks the export compliance question for every build.
- Settings' privacy row was hidden (ADR-0030) because `DadSagaPrivacyPolicyURL` was empty.
- CI only built the Debug configuration for the simulator, so the `#else` side of `#if DEBUG` (what only a release
  build runs, such as `SharedContainer` finding no fallback folder), any use of a debug-only symbol outside it, and the
  optimised compile were never checked there. The UI tests and the screen snapshots were never compiled at all.
- The repository is public. The Apple Developer account is an organization account, FAFOUTIS BROTHERS E.E.

## Decision
1. **Privacy manifest.** `App/Resources/PrivacyInfo.xcprivacy` and `Widget/PrivacyInfo.xcprivacy`:
   - `NSPrivacyTracking` is false, with no tracking domains and no collected data types (ADR-0004).
   - `UserDefaults` with reason `CA92.1`: the app's own defaults, read only by the app. The App Group is used for files,
     not for defaults, so `1C8F.1` is not claimed.
   - File timestamps with reason `C617.1`: dates of files inside the app's own containers, the App Group included.
   - The widget declares the same: it links the same `Data` module, whose code calls both.
   - A new required-reason API, an SDK, or data the app starts handling changes the manifest, both privacy pages
     (`web/privacy`, `web/el/privacy`) and the App Store privacy label, in the same PR.
2. **Info.plist**, via `project.yml`: `ITSAppUsesNonExemptEncryption` is false (the app has no encryption of its own),
   and `DadSagaPrivacyPolicyURL` is `https://dadsaga.app/privacy/`, which shows Settings' privacy row.
3. **Versioning.**
   - `MARKETING_VERSION` is `major.minor.patch`. The first build sent to TestFlight is `1.0.0`.
   - `CURRENT_PROJECT_VERSION` is a whole number that only goes up, across all versions: every upload to App Store
     Connect takes the next one, even a TestFlight build that is never released.
   - Both live in `project.yml` only, and change on the `release/<version>` branch (ADR-0009), never on `develop`.
   - Every release merged into `main` is tagged `v<version>`. A TestFlight build that is not released gets no tag.
4. **Signing.** Automatic signing in Xcode, with the organization's team. The Team ID is not a secret: once it is
   known it goes into `project.yml` as `DEVELOPMENT_TEAM`. Builds are archived and uploaded from the Mac with Xcode,
   not from CI: a public repository keeps no signing certificates or App Store Connect keys.
5. **CI** compiles what it can't run: a Release build for the device, and `build-for-testing` for `DadSagaUITests` and
   `DadSagaSnapshotTests`, which also builds the Debug app. This changes ADR-0034 §5, which kept the snapshot build out
   of CI for its time; it is only compiled, never run. On a PR, a newer push cancels the run it replaces; on `develop`
   and `main` every merge is checked. The snapshots and the audit still run on the Mac (ADR-0034).

## Consequences
- An upload no longer waits on the manifest, the encryption question or a missing privacy URL.
- The privacy page names the company and its address; App Store Connect shows the same as trader details (EU Digital
  Services Act), which the owner enters there.
- Release-only code and a test target that falls behind the app now fail CI rather than an archive.
- A CI run takes longer: ADR-0034 measured a second build taking a run from about 4 to about 15 minutes. The first
  runs are measured and the job's time limit set from them.
- Releasing needs the Mac and the owner's Apple account; CI can be given upload rights later, with its own ADR.
