# CI And Release Automation

App releases are driven by GitHub Actions workflows in `.github/workflows/`; see
`RELEASING.md` for the manual release procedure. `flake.nix` and the workflow files are the
sources of truth when this document disagrees with them.

## Pull Request CI

`ci.yml` runs a change-aware job matrix defined by the four-layer selection system in
`bootstrap/ci/`: the package graph (`registry.py`), the codegen step graph (`codegen.py`),
the task catalog (`catalog.py`), and the resolver (`resolve.py`). The workflow computes the
merge-base diff of the PR base against its head and feeds it to `uv run x.py ci matrix
--target <base> --head <head>` (pushes to `dev` use `--full`). Changed files map to packages
by longest-prefix match, blast-radius entries expand the set, the set is closed over
dependents, and every affected package instantiates its applicable task kinds
(`dart`, `dart-web`, `ts`, `rust`) plus triggered standalone kinds (`python`, `workflows`,
`l10n`). Each task instance renders as a fully self-describing job specification (dev shell,
setup needs, exact codegen/lint/test commands); the workflow's `test` job is a generic
parameterized runner with no package or task-kind names in it. Changes to the selection
system itself, `.github/**`, or `flake.nix`/`flake.lock` escalate to full instantiation as a
fail-safe. Workflow and composite-action definitions are the exception: only changes to
`ci.yml` itself (the parameterized runner) escalate; other changes under
`.github/workflows/` or `.github/actions/` select just the `workflows` standalone task
(zizmor scan). A terminal `aggregate` job (`CI / Required`) is the single stable check name that
branch protection references; per-task job names vary with the change set and must never be
protection requirements.

The registry in `bootstrap/ci/registry.py` is the single source of truth for package paths,
intra-repo dependency edges, test/codegen facts, and blast radii; it is validated against the
real `pubspec.yaml`/`package.json`/`Cargo.toml` manifests by
`bootstrap/tests/test_ci_registry.py`. Use `uv run x.py ci affected [--target REF [--head
REF] | --from-file F | --full]` to inspect the resolved packages/tasks for a change set as
JSON, and `uv run x.py ci web-gate` for the web-bundle rebuild decision.

Release preflight (`ci release verify --check-all`) intentionally stays full-scope: a release
must build and test everything regardless of what changed.

## Release Pull Requests

Release PRs target the `dev` branch and use three labels:

- `V-Release` marks the PR as a release and triggers fast preflight checks in
  `release-preflight.yml`.
- `V-Test` triggers the full release test suite in `release-test.yml`, which builds the app
  and data snapshots in test mode.
- `V-Tested Release` is added automatically by `release-test.yml` after both app and data
  tests pass.

Merging a `V-Release` PR that also has `V-Tested Release` triggers the real release through
`release.yml`. The release builds all platform artifacts, publishes the joined release to the
remote `testing` channel, and creates the Git tag.

The reusable app release workflow is `_release.yml`; the reusable data snapshot workflow is
`_release-data.yml`. Their PR/cron/dispatch entry points are merged into multi-trigger
workflows: `release-test.yml` (PR app/data release tests for both the `V-*` and the
`D-Full CI`/`D-CI-App Release` label sets), `release-data.yml` (`workflow_call` from
`update-raw-data.yml`, manual dispatch, and PR test via `D-CI-Data Release`), and
`update-raw-data.yml` (daily cron, dispatch, and PR test via `D-CI-Data Update`; cron runs
chain into `release-data.yml` when servers changed). All PR label gates — including
`web-preview.yml`'s `D-CI-Page Preview` — are evaluated by the shared composite action
`.github/actions/pr-gate`, which also applies the upstream-repository and non-fork-head
guards; fork PRs never run these jobs.

## Data Snapshot Workflow

`_release-data.yml` is organized as:

1. `build` — builds per-server snapshots and `snapshot-hashes.json`, uploaded as the
   `v2-snapshots` artifact.
2. `publish` — runs the session → commit → publish → sync/verify cycle against the remote
   `testing` channel.
3. `d1-sync` — registers snapshot engine data into the platform D1 through the data-sync
   worker; real releases only.
4. `notify-qqbot` — posts a `data_update` event with one entry per rebuilt server (Chinese
   name, game build/version, and snapshot creation time from each snapshot's `metadata.json`)
   to the bofa-qqbot event endpoint using `QQBOT_EVENT_SECRET` from `production-data`; real
   releases only. Depends only on `publish`, never on `d1-sync`, so a platform D1 sync
   failure does not suppress the announcement.

Real-release paths are never canceled mid-flight: `release-data.yml` (cron chain and manual
dispatch) and `update-raw-data.yml`'s non-PR runs use `cancel-in-progress: false`, so
same-group runs queue sequentially at concurrency 1 (one running, one pending; a newer arrival
replaces the pending one). Interrupting the session → commit → publish cycle could leave the
remote channel in an unrecoverable state. PR test runs target the local MinIO mock and remain
cancelable. `release-data.yml` also uses a literal `release-data-` group prefix because a
workflow called via `workflow_call` resolves `github.workflow` to the caller's name, which
would collide with the caller's own group.

## App Release Workflow

`_release.yml` is a symmetric multi-platform pipeline:

1. `verify` — version check; exports `tag` and `version`.
2. Platform build jobs — `android` and `linux` both need `verify`, are blocking, and share
   `.github/actions/setup-build-env` parameterized by dev shell. `windows` runs on
   `windows-latest` with the non-Nix `.github/actions/setup-build-env-windows` composite
   action.
3. `publish` — needs `verify`, `android`, `linux`, and `windows`; downloads all platform
   artifacts (binaries plus release-fragment JSONs), merges fragments into one release
   registry through `x build release --fragments ...`, then runs the session → commit →
   publish → sync/verify cycle against the remote channel.
4. `tag` — creates the GitHub Release with all platforms' assets.
5. `notify-qqbot` — posts a `release-created` event with the Chinese release note to the
   bofa-qqbot event endpoint using `QQBOT_EVENT_SECRET` from `production-app`; real releases
   only.

Platform integrity differs only where the toolchain requires it: APKs are signed and carry
Flutter-emitted `.sha1` sidecars; Linux artifacts ship as-is; Windows artifacts (zip and
per-user MSI) ship unsigned, so installing the MSI shows a SmartScreen warning.

Adding another release platform means extending `release_index.proto`, `make_release_index`,
`_RELEASE_PLATFORM_VARIANTS` in `publish.py`, `_PLATFORM_DIR` in `build.py`, and the variant
extraction in `bootstrap/cli/remote/session.py`; then add a platform job that uploads its
artifacts plus fragment and add that fragment to the `publish` job's merge.

## Test-Mode Publishing

In test mode, both release workflows exercise the full commit → publish → sync → verify cycle
against a local MinIO mock instead of touching the real remote:

```sh
./x remote mock launch --daemon
./x remote mock stop
```

## CI Configuration And Secrets

CI workflows share the tracked developer config `ci/config/efa.dev.toml`. It contains
non-secret values, with `.invalid` placeholders for secret fields. The composite action
`.github/actions/init-dev-env` copies it to `./efa.dev.toml` after checkout; jobs inject real
secrets through `--dev-env` overrides.

Publishing credentials live in GitHub Environments, not repository secrets:

- `production-app` — reviewer-gated; app releases;
- `production-data` — `dev`-only; data publishes;
- `ci-write` — `dev`-only; raw-data uploads.

Endpoints and keys are environment secrets, while bucket names are variables. PR-triggered
builds use a read-only repository-level `CI_STORAGE_*` token. See `RELEASING.md` → "Secrets
and environments" for the full map.

## Flutter Web Delivery

The `apps/eve-fit-assistant/build/web` bundle from `x build web` deploys to two Cloudflare
Pages projects:

- `efa-app` — production at <https://app.efa-tech.dev>; release-only;
- `efa-app-nightly` — nightly preview at <https://app-preview.efa-tech.dev>; branch previews
  and nightly builds.

All jobs build through `.github/actions/build-web` and deploy through
`.github/actions/deploy-web-pages`. The deploy action copies the tracked
`ci/config/wrangler.{prod,nightly}.toml` to `./wrangler.toml` because wrangler requires a
config file, then runs `wrangler pages deploy` with `--commit-hash`.

Entry points:

- `web-preview.yml` — PRs to `dev` whose change set instantiates the Flutter app's tasks
  (the web-bundle gate: a query over the same resolver output as test selection, checked
  through `uv run x.py ci web-gate` with the same merge-base diff) get a branch preview on
  `efa-app-nightly` plus a pinned PR comment. This is gated on the `D-CI-Page Preview` label,
  which `D-Full CI` also enables. Release PRs labeled `V-Release` skip this build because
  `release-test.yml`'s `site`/`site-deploy` jobs build and deploy the web bundle instead.
  Fork PRs get no preview.
- `site-nightly.yml` — daily cron on `dev`; fetches the last nightly production deployment's
  commit hash from the Pages API and only rebuilds/deploys to
  `efa-app-nightly` when `uv run x.py ci web-gate --target <sha> --head HEAD` says the bundle
  changed. It does not comment on a PR.
- `_release.yml` — `site` build job plus `site-deploy`; test mode deploys to
  `efa-app-nightly` with a pinned comment on the release PR, while real releases deploy to
  `efa-app`.

Deploy jobs run in GitHub deployment environments:

- `ci-testing-web` — PR branch previews and release test-mode deploys on `efa-app-nightly`;
  release test-mode runs from the PR head branch, so it cannot use the dev-restricted
  `nightly-web` environment.
- `nightly-web` — dev-branch-only nightly builds on `efa-app-nightly`.
- `production-app` — `efa-app` only.

These environments hold `CLOUDFLARE_API_TOKEN` (Pages:Edit) and `CLOUDFLARE_ACCOUNT_ID`.
Each Pages project's production branch must be set to `dev` as a one-time dashboard setup.
