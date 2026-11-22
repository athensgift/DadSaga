# ADR-0062: CI builds the Release app after a merge and on the way to a release, not on every pull request

**Status:** Accepted (2026-11-22). The owner asked that a pull request no longer wait for the Release build: with
gitflow (ADR-0009) it belongs to the release branch. He chose to keep it after every merge into `develop` too. Changes
ADR-0051 §5 (the Release build no longer runs on a pull request into `develop`). Numbered 0062 because another branch
takes 0061.

## Context
- Since ADR-0051 §5, every CI run builds the app three times: Release for the device, Debug for the simulator with the
  UI tests, and the snapshots. A run takes 7 to 9 minutes (the runs of 2026-11-22).
- The Release build only finds what the others can't: code in the `#else` of `#if DEBUG`, and what only the optimised
  build trips on. Both are rare, and small to fix on a release branch.
- Gitflow (ADR-0009): `feature/*` into `develop` by pull request, `release/*` cut from `develop`, merged into `main`.

## Decision
- **A pull request into `develop`** runs the lint, the package tests and the simulator builds (the app with its UI
  tests, and the snapshots), not the Release build.
- **The Release build is its own job** (`release-build` in `.github/workflows/ci.yml`). It runs:
  - after every push to `develop`, so a merge that breaks it is known the same day, while the pull request is fresh;
  - on every push to a `release/**` branch;
  - on a pull request into `main`, and after the merge into `main`.
- Nothing else changes: the snapshots and the audit still run on the Mac (ADR-0034), and archives are still made
  there (ADR-0051 §4).

## Rejected
- **The Release build on every pull request** (ADR-0051 §5): a few minutes on each, for a rare failure.
- **The Release build only on the release branch:** a break would show up weeks after the pull request that made it.
- **A nightly Release build:** a schedule for what a merge already triggers.

## Consequences
- A pull request into `develop` is checked faster.
- A merge into `develop` can break the Release build without the pull request seeing it. That run fails on `develop`,
  and the fix is the next pull request.
- A release branch always starts from a `develop` whose Release build has been checked.
