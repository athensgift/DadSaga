# ADR-0074: CI runs the package tests and the simulator builds side by side

**Status:** Accepted (2026-11-25, by the owner). The owner asked for a faster pull request check with nothing else changed: the same
checks, the same runner, no cache and no skipped paths. The third job on Ubuntu is this ADR's answer to the required
check's name, accepted with the rest. Changes ADR-0034 §5 (one job of CI runs on Ubuntu; it runs no
toolchain) and how ADR-0062's pull request check is laid out (two jobs, not one).

## Context
- A pull request into `develop` ran one job, `build-and-test`: the lint, the package tests, then the simulator builds
  (the app with its UI tests, and the snapshots), as ADR-0062 left it.
- The last 35 green runs (22 to 25 November 2026): the package tests took 122 to 302 seconds and the builds 126 to 286,
  one after the other, typically 7 to 9 minutes a run. The same code takes up to twice as long from run to run: that
  is the runner.
  Every run builds from nothing.
- Neither half needs the other: the package tests never open the Xcode project, and the builds never run a test.
- The ruleset on `main` and `develop` requires a status check named `build-and-test` before a merge.

## Decision
- **Two jobs, side by side**, each on `xcode-27` with the pinned `DEVELOPER_DIR` (ADR-0034) and the 45-minute limit:
  - `package-tests`: the lint and `swift test`;
  - `app-build`: `xcodegen generate` and the two `build-for-testing` builds.
- **`build-and-test` stays as the required check.** It is now a third job that waits for the two and passes only when
  both did. It runs on `ubuntu-latest` for a few seconds and runs no tool of ours. It runs `always()`: a job skipped
  because one it needs failed, or because the run was cancelled (`!cancelled()`), counts as passed for a required
  check.
- Nothing else changes: what is checked, when `release-build` runs (ADR-0062), the concurrency rule.

## Rejected
- **Renaming the required check**, or requiring the two new jobs by name: a change to the ruleset that has to land
  at the same moment as the workflow, and every open pull request would wait for a check its branch never reports.
- **Keeping the name for one of the two jobs** and adding the other to the ruleset later: until then a merge would
  not wait for the other half.
- **A build cache, or skipping CI for paths that can't break it:** faster still, but each can pass a change that a
  build from nothing would fail. The owner asked for the change with no such risk.

## Consequences
- A pull request waits for the slower of the two jobs, not for their sum.
- The same runner minutes, plus a second checkout and tool install, and a few seconds of an Ubuntu runner.
- A push to `develop` starts three macOS jobs at once (these two and `release-build`). When runs overlap, GitHub's
  limit on macOS jobs at a time can make one wait, which takes back some of the gain.
- A pull request shows three checks. Only `build-and-test` is required; it is red whenever either of the others is.
- A new job that a merge must wait for is added to `needs` of `build-and-test`, and to its step.
