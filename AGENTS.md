# AGENTS.md

Compact repo guidance for future OpenCode sessions. Prefer executable config and `./x --help` over stale prose if anything conflicts.

## Workspace Shape

- Flutter/Dart app code is under `lib/`; generated Dart outputs include `lib/native/`, `lib/data/l10n/`, protobuf outputs, `*.g.dart`, and `*.freezed.dart`.
  - `lib/storage/repo/` implements a content-addressed repository system for data versioning with checkout-based data management and diff chains.
- Rust has two layers: FRB bridge crate in `rust/` (`rust/src/api/*`) and the fitting engine git-submodule crate in `rust/lib/eve-fit-os`.
- Python in `bootstrap/` plus `x.py` owns workspace management, codegen orchestration, and static data packaging. The top-level `data/` directory holds only raw EVE resources (`data/resources/`) and protobuf `.proto` schema sources (`data/schema/`).
- `rust_builder/` is the Flutter plugin/cargokit wrapper used by `pubspec.yaml`; avoid treating it as the main Rust source.
- `site/` is a SvelteKit app deployed to Cloudflare Workers (pnpm workspace). `biome.json` governs JS/TS formatting/linting for this area.
- `rust/lib/eve-fit-os` is a Git submodule; run `git submodule update --init` after clone if not already initialized.

## Storage Layer

| System | Path | Description |
|--------|------|-------------|
| Repo System | `lib/storage/repo/` | Content-addressed repository implementing the EFA V2 unified storage schema (generation-based, protobuf-driven) with blob store, resource snapshots, channel discovery, checkout lifecycle, and Riverpod providers. |
| Schema Version | `lib/storage/repo/schema_version.dart` | `SchemaVersionService` — reads/writes `schema_version.json`, determines active storage system |
| Channel Discovery | `lib/storage/repo/channel_service.dart` | `ChannelService` — fetches channel registry, head metadata, server index; update detection |
| Checkout Management | `lib/storage/repo/checkout_registry_service.dart` | `CheckoutRegistryService` — manages `checkouts/checkouts.json`, active checkout pointer, reactive stream |
| Checkout Lifecycle | `lib/storage/repo/checkout_service.dart` | `CheckoutService` — checkout CRUD, reflog management, resource fetch orchestration |
| Release Sync | `lib/storage/repo/release_sync.dart` | `ReleaseSyncService` — detects newer app versions against the remote release index via `ReleaseIndex` protobuf (detection only) |
| Generation Navigation | `lib/storage/repo/generation_nav.dart` | `GenerationNavigationService` — channel → server browser for setup page |
| Repo Collection | `lib/storage/repo/collection.dart` | `RepoCollectionService` — sole type-data source; pre-loads type data (ships, skills, items, localization, icons) from active checkout's ResourceIndex. |
| Migration Layer | `lib/storage/repo/migration/` | `action/` — `MigrateService` (orchestrator: fits→characters→finalize), `MigrateFits` (v2→v3 upgrade with `CheckoutRef`), `MigrateCharacters` (v2→v3 upgrade with `CheckoutRef`), `MigrateProgress` (freezed checkpoint state machine + `MigrateProgressStore`, persisted to `.migration_progress.json`), `MigrateFitsResult`/`MigrateCharactersResult` (migration result types). |
| Persistence | `lib/storage/fit/`, `lib/storage/character/` | Fit/character storage schemas; fit supports storageVersion 3 with CheckoutRef |
| Settings | `lib/storage/setting/` | User settings including remote content configuration |

All writes to `checkouts.json` are mutex-guarded; reads are lock-free. The checkout registry provides a reactive stream for live UI updates.

The `RepoStateNotifier` initializes asynchronously at startup; `SchemaGuard` watches the state and renders appropriate screens. `MigrationGate` checks for v1 data remnants and offers a one-time migration prompt before the repo system activates.

### Data-Flow Orchestration

| Workflow | Entry Point | Service |
|----------|------------|---------|
| Channel discovery | `discoverChannels()` | `RepoService` → `ChannelService.discoverChannels()` |
| Resource fetch | `fetchResourcesForActiveCheckout()` | `RepoService` → `CheckoutService.fetchResourcesForCheckout()` |
| Create checkout | `createCheckout()` | `RepoService` → `CheckoutService.createCheckout()` |
| Revert | `revertActiveCheckoutTo()` | `RepoService` → `CheckoutService.revertCheckoutTo()` |
| Checkout resolution | `resolveCheckoutRefAsync()` | `RepoService` → `CheckoutResolver.resolveAsync()` |
| Update discovery | `checkForUpdates()` | `RepoService` → `ChannelService.hasUpdates()` |
| Verification repair | `verifyAndRepair()` | `RepoService` → `VerificationService.repairAll()` |
| Checkout lifecycle | `switchActiveCheckout()` / `deleteCheckout()` | `RepoService`
| Prune | `prune()` | `RepoService` → `VerificationService.prune()` |
| Startup recovery | `recoverPartialDownloads()` | `RepoService` (called from `ensureInitialized()`) |

## Environment And Setup

- Use `nix develop`; `flake.nix` supplies Flutter, JDK 17, Android SDK/NDK, Rust/Cargo, `uv`, protobuf tools, and `flutter_rust_bridge_codegen`.
- Bootstrap with `./x dev env install` or, equivalently, `flutter pub get` and `uv sync` inside the dev shell.
- Do not hand-edit `android/local.properties` unless needed; the Nix shell hook regenerates it with only SDK/NDK/CMake paths derived from the Nix environment. Flutter build properties (version, build mode, etc.) are not touched and are read from `pubspec.yaml` directly.
- Python requires 3.13+ and is managed by `uv`; run `x.py` through `./x`, `./x.ps1`, or `uv run x.py`, not a global Python.
- Backend Rust builds/tests/codegen need `rust/lib/eve-fit-os/.env`; normally create `efa.dev.toml` with `./x dev init-cfg`, set `[native]`, then run `./x dev env write-backend`.

## Canonical Commands

- Full fix/lint/format pass (all languages): `./x lint`.
- Formatting only: `./x format` (`./x lint --no-check`).
- Generate all code and then format: `./x generate -f all`.
- Focused generators: `./x generate protobuf`, `./x generate rust`, `./x generate dart`, `./x generate l10n`, `./x generate values dogma-units`.
- Android build: `flutter build apk` (or `./x build apk` from the workspace CLI).
- Linux AppImage build: `./x build appimage` (requires `appimage-builder` from the Nix dev shell; output in `cache/releases/appimage/<ver>/`).
- Release preflight checks: `./x ci release verify --check-all`.
- Create raw release note: `./x release relnote` (emits `spec.yaml` and `changelog.md`; author `content.zh.md` and `content.en.md` separately).
- Sync canonical version to manifests: `./x release version sync`.
- Bridge crate build/test: `cargo build -p rust_lib_eve_fit_assistant`, `cargo test -p rust_lib_eve_fit_assistant`.
- Engine build/test: `cargo build -p eve-fit-os`, `cargo test -p eve-fit-os`.
- Single Rust integration test file/function: `cargo test -p eve-fit-os --test test_basic_fit -- --nocapture`; `cargo test -p eve-fit-os test_basic_fit -- --exact --nocapture`.
- Python tests: `./x test python` or `uv run pytest`.
- Flutter/Dart tests: `./x test dart` or `flutter test`.
- Repo module tests: `dart test test/storage/repo/`.
- Data-flow integration tests (e.g., `test/storage/repo/`) use `package:mocktail`
  for network and filesystem mocks; run with `dart test test/storage/repo/`.
  Async tests require `flutter test` or `dart test` with the Flutter SDK on PATH.
- Regenerate freezed code for models: `dart run build_runner build --delete-conflicting-outputs`.
- Migration tests: `dart test test/storage/repo/migration/action/from_v1/`.
- All tests: `./x test all`.

## Data Workspaces And Bundles

- Workspaces are declared in `efa.config.toml`; changing that file is a project-level datasource/config change, not a local preference.
- Select data with `./x workspace list` and `./x workspace default <workspace>`; override per command with `./x --ws <workspace> ...`.
- Build selected workspace data with `./x build data`.
- Generated data depends on external EVE FSD/resource files described by `data/resources/*/descriptor.toml`; missing local resources can block data builds.

## Version

- The canonical version lives in `efa.config.toml` under `[version]`. All other targets (`pubspec.yaml`, `rust/Cargo.toml`, `pyproject.toml`) are derived from it. The engine submodule `rust/lib/eve-fit-os` has independent versioning.

## CI / Release Automation

- App releases are driven by GitHub Actions workflows in `.github/workflows/` (see `RELEASING.md` for the manual procedure).
- Release PRs target the `dev` branch and use three labels:
  - `V-Release` — marks the PR as a release and triggers fast preflight checks (`release-preflight.yml`).
  - `V-Test` — triggers the full release test suite (`release-full.yml`), which builds the app and data snapshots in test mode.
  - `V-Tested Release` — added automatically by `release-full.yml` after both app and data tests pass.
- Merging a `V-Release` PR that also has `V-Tested Release` triggers the real release (`release.yml`), which builds the APK, publishes the release to the remote `testing` channel, and creates the Git tag.
- The reusable app release workflow is `_release.yml`; the reusable data snapshot workflow is `_release-data.yml`.
- `_release.yml` also builds the Linux AppImage in a dedicated `appimage` job (`.#linux` dev shell). The job is `continue-on-error: true`: it is exercised by the `D-CI-App Release` / `D-Full CI` / `V-Test` flows but never blocks the APK build, remote publish, tagging, or the surrounding check run. The AppImage is GitHub-Releases-only: it is attached as a release asset by the `tag` job when the artifact exists and is intentionally excluded from the release-registry merge and remote channel publish.
- In test mode both workflows exercise the full commit → publish → sync → verify cycle against a local MinIO mock (`./x remote mock launch --daemon`, stop with `./x remote mock stop`) instead of touching the real remote.
- CI workflows share the tracked developer config `ci/config/efa.dev.toml` (non-secret values; secret fields are `.invalid` placeholders). The composite action `.github/actions/init-dev-env` copies it to `./efa.dev.toml` after checkout; jobs inject real secrets via `--dev-env` overrides on top.
- Publishing credentials live in GitHub Environments, not repository secrets: `production-app` (reviewer-gated; app releases), `production-data` (`dev`-only; data publishes), and `ci-write` (`dev`-only; raw-data uploads). Endpoints/keys are environment secrets, bucket names are variables. PR-triggered builds use a read-only repo-level `CI_STORAGE_*` token. See `RELEASING.md` → "Secrets and environments" for the full map.

## Validation Expectations

- After edits, run the relevant formatter and linter; for mixed-language or uncertain changes, run `./x lint`.
- Run relevant tests before committing: `./x test python` or `./x test dart` depending on what changed.
- Dart-only minimum: `dart format lib/` plus `dart analyze`; run `./x generate dart` when annotations/routes/Riverpod/freezed/json models change.
- Python-only minimum: `uv run ruff format` plus `uv run ruff check --fix`.
- Rust bridge minimum: `cargo fmt --package rust_lib_eve_fit_assistant` plus `cargo clippy --fix --allow-dirty --package rust_lib_eve_fit_assistant`.
- Rust fitting-engine logic changes should also run targeted `cargo test -p eve-fit-os ...`.
- Localization changes require `./x generate l10n`; `l10n/app_zh.arb` is the template ARB with placeholder metadata, while `l10n/app_en.arb` should contain translations only.
- JS/TS (site/ dir): run `pnpm run check` in `site/` for SvelteKit type checks; `npx biome check --fix` for formatting/linting.

## Developer Mode

The `AppSetting` model (`lib/storage/setting/setting.dart`) includes a `developerMode` boolean field (default `false`). It is not exposed as a normal settings toggle.

**Access:** On **Settings → Version**, tap the **App Version** value in the version info table 5 times within 2 seconds. A confirmation dialog (`developerModeEnableConfirmTitle` / `developerModeEnableConfirmDescription`) is shown; confirming sets `developerMode` to `true` via `appSettingServiceProvider`. Once enabled, a **Developer Settings** card appears on the Version page.

**Entry points after enabled:**
- Version page → Developer Settings (`/setting/developer-settings`): debug log toggle, remote-content settings visibility, open remote content settings, collect logs, clear cache, and a shortcut to Developer Tools.
- Developer Settings → Developer Tools (`/setting/developer-tools`): channel overview, restart init, trigger feedback, reset all storage.

**Providers:**
- `developerModeProvider` — reactive read via `ref.watch(developerModeProvider)` (always up-to-date).
- `appSettingServiceProvider.select((s) => s.developerMode)` — fine-grained reactive read.
- `ref.read(appSettingServiceProvider).developerMode` — imperative read within callbacks.

**Localization rule for developer-only widgets:** UI widgets gated behind `developerMode` (i.e., only visible when dev mode is on) **must use hardcoded English**. No ARB entries or `context.l10n` calls for dev-only UI. Only the enable-confirmation dialog and the always-visible Version page elements use localization.

## Style And Generated-Code Gotchas

- Dart analyzer is strict (`strict-casts`, `strict-inference`, `strict-raw-types`) and enforces package imports, double quotes, explicit public API types, and 100-column formatting.
- Python Ruff requires `from __future__ import annotations`, absolute imports, one import per line, double quotes, and 100-column formatting; `rust/lib/` is excluded from root Ruff.
- Root `rustfmt.toml` uses 100 columns plus field-init and `?` shorthands; the bridge crate stays Rust 2021 because of `flutter_rust_bridge`.
- Keep FRB-facing APIs small and explicit in `rust/src/api/`; put core fitting behavior in `rust/lib/eve-fit-os` when possible.
- Do not manually edit generated bridge/localization/protobuf/build outputs unless the task is explicitly about generated artifacts; change sources and run the matching generator.

## Python Pipeline

- `bootstrap/remote/session_model.py` — Session manager for the `efa/v2/` layout
  (`SessionManager`), inheriting from `_BaseSessionManager`. Manages
  generation lifecycle, resource registration, release
  management, and S3/R2 publishing.

## Local Instruction Sources

- `flake.nix` and `.github/workflows/` are the sources of truth for CI/CD; release procedures are documented in `RELEASING.md`.
- No `.cursor/rules/`, `.cursorrules`, or `opencode.json`.
- `CLAUDE.md` is a symlink to this file.
