# Releasing DadSaga

The checklist for a TestFlight build and an App Store release. The decisions behind it are in
[ADR-0009](adr/0009-gitflow.md) (Gitflow) and [ADR-0051](adr/0051-signing-versioning-and-privacy-manifest.md)
(signing, versioning, privacy manifest).

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
- [ ] App Store text says "from birth" until the world before birth exists.
- [ ] Privacy policy URL `https://dadsaga.app/privacy/`, support URL `https://dadsaga.app/support/`.

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
6. **TestFlight.** Install it, and repeat the device checks on the build Apple processed.
7. **Submit** for review with release notes in Greek and English.
8. **Merge** once Apple approves: `release/<version>` into `main` through a PR, tag `v<version>` on `main`, then merge
   `main` back into `develop`.

A TestFlight build that is never released still takes its build number, and the next upload takes the next one. It
gets no tag, and the release branch stays open until a build is released.

## A hotfix
`hotfix/<name>` from `main`. Raise the patch number and the build number, then follow steps 3–8 as above, merging into
`main` (tagged) and into `develop`.
