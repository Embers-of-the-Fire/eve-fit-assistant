# GitHub Automation

Scope: GitHub Actions workflows, reusable composite actions, issue templates, and pull-request
templates.

## Local Rules

- Workflow files in `.github/workflows/` are the CI/CD source of truth; consult them before
  changing release behavior.
- Keep reusable workflow boundaries intact: `_release.yml` for app releases and
  `_release-data.yml` for data snapshots.
- The `D-*`/`V-*` PR label contract (gates for the raw-data update, data/app release tests,
  and web preview) lives in `.github/actions/pr-gate`; extend it there instead of copying
  `contains(labels, ...)` expressions into workflows.
- Keep shared setup in `.github/actions/` parameterized rather than duplicating environment
  logic in callers.
- Do not add secrets to workflow files. Publishing credentials belong in GitHub
  Environments as described by `RELEASING.md` and @docs/agents/ci-release.
- Preserve the release-label contract: `V-Release`, `V-Test`, and `V-Tested Release`.
- Web preview behavior is a query over the change-aware resolver in `bootstrap/ci/`
  (`uv run x.py ci web-gate`: whether the Flutter app's task set is instantiated for the change
  set); update both sides together when changing the trigger model.
- `ci.yml` is a generic parameterized runner: it must never contain package names, task-kind
  names, or per-kind conditional logic. CI workload changes belong in the task catalog
  (`bootstrap/ci/catalog.py`), not in the workflow. Branch protection references only the
  terminal aggregation check (`CI / Required`).

## Validation

For workflow changes, inspect the affected workflow graph and run the narrowest available CI
validation. Broader release checks use:

```sh
./x ci release verify --check-all
```
