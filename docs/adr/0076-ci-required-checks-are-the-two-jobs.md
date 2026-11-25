# ADR-0076: The checks a merge requires are the two CI jobs themselves

**Status:** Accepted (2026-11-25, by the owner). He found the third job of ADR-0074 unnecessary and asked for the
ruleset to change instead; it was changed the same day. Changes ADR-0074 (the `build-and-test` job is removed, and
"Renaming the required check" is no longer rejected), and with it what ADR-0074 changed in ADR-0034 §5 (no CI job
runs on Ubuntu any more) and in ADR-0062 (the pull request check is two required jobs).

## Context
- ADR-0074 split the pull request check into `package-tests` and `app-build`, and kept a third job named
  `build-and-test` on `ubuntu-latest`. It ran nothing of ours: it existed only because the ruleset "Gitflow: protect
  main and develop" required a status check with that name.
- ADR-0074 rejected changing the ruleset because the change had to land at the same moment as the workflow, and open
  pull requests would wait for a check their branch never reports. Once ADR-0074 was merged, neither held: every
  branch cut from `develop` since reports `package-tests` and `app-build`.
- On 2026-11-25 the ruleset was changed with `gh api`: it requires `package-tests` and `app-build` (both from GitHub
  Actions, integration 15368) and no longer `build-and-test`. Its other rules are as they were.

## Decision
- **The required checks are `package-tests` and `app-build`**, by job name, on `main` and `develop`.
- **The `build-and-test` job is removed** from `.github/workflows/ci.yml`. `package-tests`, `app-build` and
  `release-build` are unchanged, and so is when each runs (ADR-0062).
- **The ruleset follows the workflow.** Renaming a required job, splitting one, or adding a job a merge must wait for
  is a change to the ruleset too, made at the same moment as the workflow change is merged.
- **A required job is never skipped:** no `if:` on the job and no path filter on the workflow. GitHub counts a skipped
  required check as passed.

## Rejected
- **Keeping the third job** (ADR-0074): a job, a runner and a check on every pull request, only to carry a name.
- **Requiring `release-build` too:** it does not run on a pull request into `develop` (ADR-0062), and a required
  check that never reports blocks the merge.

## Consequences
- A pull request shows two checks, both required. No CI job runs outside the pinned `xcode-27` image (ADR-0034).
- The ruleset lives in GitHub's settings, not in the repository: a workflow change that renames a required job passes
  review and then blocks every merge, waiting for a check that never reports, until the ruleset is changed.
- A branch cut from `develop` before ADR-0074 was merged reports neither required check until `develop` is merged
  into it.
- A cancelled or failed required job blocks the merge as it is: it reports its own result, with no job in between
  to get wrong.
