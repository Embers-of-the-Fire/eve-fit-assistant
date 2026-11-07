# GitHub Automation

Scope: GitHub Actions workflows, reusable composite actions, issue templates, and pull-request
templates.

## Hard Constraints

- Do not add secrets to workflow files. Publishing credentials belong in GitHub
  Environments as described by `RELEASING.md` and
  [docs/dev/ci-release.md](../docs/dev/ci-release.md).
- Preserve the release-label contract: `V-Release`, `V-Test`, and `V-Tested Release`.
- Keep reusable workflow boundaries intact: `_release.yml` for app releases and
  `_release-data.yml` for data snapshots. Entry-point workflows call them directly;
  `release-data.yml` is the manual-dispatch entry for humans and must not be reintroduced
  as a `workflow_call` hop.
- The `D-*`/`V-*` PR label contract lives in `.github/actions/pr-gate`; extend it there
  instead of copying `contains(labels, ...)` expressions into workflows.
- `ci.yml` is a generic parameterized runner: it must never contain package names, task-kind
  names, or per-kind conditional logic. CI workload changes belong in the task catalog
  (`bootstrap/ci/catalog.py`), not in the workflow. Branch protection references only the
  terminal aggregation check (`CI / Required`).
- Dependency-bump behavior lives in `renovate.json5`; `renovate.yml` is only its runner.
  Labels used there must already exist in the repository. The bot never automerges.

## Docs

- CI/release workflows and environments: [docs/dev/ci-release.md](../docs/dev/ci-release.md)
- Validation: `./x ci release verify --track stable --check-all` for broader release
  checks. `--track` defaults to `testing`, so always name the track
  (`--track stable` for stable ships and stable patch backports — backports release
  on stable too, and the testing track verifies the wrong version for them, failing
  the I3 check before the broader checks run; `--track testing` otherwise). Sync
  manifests before stable verification: committed manifests use the testing
  version, so this command fails the version check on a stable ship before it runs
  the broader checks. Run `./x release version sync --track stable` first, as the
  release workflow does, and restore the testing rendering before committing.
  Post-ship test-mode waiver: after a stable ship, non-release test runs use
  testing with `num = 0`, so the documented command fails the I3 gate before
  running the tests; add `--allow-unpublishable` for test-only runs in this state,
  as the release workflow does.
