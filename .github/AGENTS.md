# GitHub Automation

Scope: GitHub Actions workflows, reusable composite actions, issue templates, and pull-request
templates.

## Local Rules

- Workflow files in `.github/workflows/` are the CI/CD source of truth; consult them before
  changing release behavior.
- Keep reusable workflow boundaries intact: `_release.yml` for app releases and
  `_release-data.yml` for data snapshots.
- Keep shared setup in `.github/actions/` parameterized rather than duplicating environment
  logic in callers.
- Do not add secrets to workflow files. Publishing credentials belong in GitHub
  Environments as described by `RELEASING.md` and @docs/agents/ci-release.
- Preserve the release-label contract: `V-Release`, `V-Test`, and `V-Tested Release`.
- Web preview behavior depends on the monorepo dependency graph in `bootstrap/monorepo/`
  (web-relevant package closure and meta entries) and the `x.py ci web-affected` check;
  update both sides together when changing the trigger model.

## Validation

For workflow changes, inspect the affected workflow graph and run the narrowest available CI
validation. Broader release checks use:

```sh
./x ci release verify --check-all
```
