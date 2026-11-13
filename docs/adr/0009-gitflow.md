# ADR-0009: Gitflow branching

**Status:** Accepted

## Context
Phase 1 went straight to `main`, and the first feature used a short-lived branch merged by PR (GitHub Flow). The project
is heading towards versioned App Store releases, and it doubles as a portfolio piece that should show a release workflow.

## Decision
Use Gitflow:
- `main` holds released code only. Every commit on it is a release and carries a `v<version>` tag.
- `develop` is the integration branch and the default target for PRs.
- `feature/<name>` branches from `develop` and merges back through a PR once CI is green.
- `release/<version>` branches from `develop` for stabilisation, then merges into `main` (tagged) and back into `develop`.
- `hotfix/<name>` branches from `main`, then merges into `main` (tagged) and into `develop`.
- CI runs on every PR and on pushes to `main` and `develop`.

## Consequences
- `main` always matches what was shipped, which makes hotfixes and release notes straightforward.
- More ceremony than GitHub Flow for a solo project: an extra merge per release, and `develop` must be kept in sync after
  every release and hotfix.
- Until the first release, `main` stays at the Phase 1 commit while work accumulates on `develop`.
