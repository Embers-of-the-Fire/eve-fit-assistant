# AGENTS.md

Compact repo guidance for future OpenCode sessions. Prefer executable config and `./x --help` over stale prose if anything conflicts.

## Workspace Shape

- Flutter/Dart app code is under `lib/`; generated Dart outputs include `lib/native/`, `lib/data/l10n/`, protobuf outputs, `*.g.dart`, and `*.freezed.dart`.
  - `lib/storage/repo/` implements a content-addressed repository system for data versioning with branch-based checkouts and diff chains.
- Rust has two layers: FRB bridge crate in `rust/` (`rust/src/api/*`) and the fitting engine git-submodule crate in `rust/lib/eve-fit-os`.
- Python in `data/` plus `x.py` owns workspace management, codegen orchestration, and static data bundle generation.
- `rust_builder/` is the Flutter plugin/cargokit wrapper used by `pubspec.yaml`; avoid treating it as the main Rust source.
- `site/` is a SvelteKit app deployed to Cloudflare Workers (pnpm workspace). `biome.json` governs JS/TS formatting/linting for this area.
- `rust/lib/eve-fit-os` is a Git submodule; run `git submodule update --init` after clone if not already initialized.

## Storage Layer

| System | Path | Description |
|--------|------|-------------|
| Repo System | `lib/storage/repo/` | Content-addressed repository with branch/checkout model, diff chains, Riverpod providers, and async orchestration for full download, incremental update, revert, update discovery, verification recovery, and branch lifecycle. |
| Schema Version | `lib/storage/repo/schema_version.dart` | `SchemaVersionService` — reads/writes `schema_version.json`, determines active storage system |
| Announcements | `lib/storage/repo/announcements.dart` | `AnnouncementService` — manages `runtime/v2/data/announcements/` (index, records, markdown content, content hash, isRead tracking) |
| Announcement Sync | `lib/storage/repo/announcement_sync.dart` | Syncs remote announcement catalog with local index; fetches records + content on change |
| Release Sync | `lib/storage/repo/release_sync.dart` | Checks remote release catalog for newer APK versions; downloads APK binary |
| Generation Navigation | `lib/storage/repo/generation_nav.dart` | Drill-down data source: generation → servers → checkouts for branch management page |
| Repo Collection | `lib/storage/repo/collection.dart` | `RepoCollectionService` — sole type-data source; pre-loads type data (ships, skills, items, localization, icons) from active checkout's asset store. |
| Migration Layer | `lib/storage/repo/migration/` | `action/` — `MigrateService` (orchestrator: fits→characters→finalize), `MigrateFits` (v2→v3 upgrade with `CheckoutRef`), `MigrateCharacters` (v2→v3 upgrade with `CheckoutRef`), `MigrateProgress` (freezed checkpoint state machine + `MigrateProgressStore`, persisted to `.migration_progress.json`), `MigrateFitsResult`/`MigrateCharactersResult` (migration result types). |
| Persistence | `lib/storage/fit/`, `lib/storage/character/` | Fit/character storage schemas; fit supports storageVersion 3 with CheckoutRef |
| Data Source Pages | `lib/pages/branch/` | Branch list, detail (reflog/diffs), setup (server selection + checkout picker) |
| Storage Settings | `lib/pages/setting/data/` | Storage management (prune/verify) and branch settings (rename/pin/delete) |
| Schema Guard | `lib/features/schema_guard/` | Startup gate: `SchemaGuard` manages initialization; `MigrationGate` offers a one-time v1→v2 migration prompt |
| Repo State | `lib/storage/repo/repo_state.dart` | `RepoState` union (uninitialized/initializing/active/error) and `RepoStateNotifier` |
| Repo Errors | `lib/storage/repo/repo_error.dart` | `RepoError` sealed class (network/storage/corrupt/remoteData) for typed error propagation |
| Branch Widgets | `lib/features/branch_management/` | Reusable branch tile, reflog timeline, diff summary, server/checkout selection tiles |
| Settings | `lib/storage/setting/` | User settings including remote content configuration |

All writes to `active.json` are mutex-guarded; reads are lock-free. File watchers provide reactive streams for `active.json` and branch directory changes.

The `RepoStateNotifier` initializes asynchronously at startup; `SchemaGuard` watches the state and renders appropriate screens. `MigrationGate` checks for v1 data remnants and offers a one-time migration prompt before the repo system activates.

### Data-Flow Orchestration

| Workflow | Entry Point | Service |
|----------|------------|---------|
| Full checkout download | `downloadAndActivateCheckout()` | `RepoService` → `CheckoutService.downloadFullCheckout()` |
| Incremental update | `updateActiveBranchToCheckout()` | `RepoService` → `CheckoutService.applyIncrementalUpdate()` |
| Revert | `revertActiveBranchTo()` | `RepoService` → `BranchService.revertTo()` |
| Remote resolution | `resolveCheckoutRefAsync()` | `RepoService` → `CheckoutResolver.resolveAsync()` |
| Update discovery | `checkForUpdates()` | `RepoService` → `BranchService.checkForUpdates()` |
| Verification repair | `verifyAndRepair()` | `RepoService` → `VerificationService.repairAll()` |
| Branch lifecycle | `createRemoteBranch()` / `createLocalBranch()` / `deleteBranchWithDetach()` | `RepoService` |
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
- Android build: `flutter build apk`.
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

## Version And Release

- The canonical version lives in `efa.config.toml` under `[version]`. All other targets (`pubspec.yaml`, `rust/Cargo.toml`, `pyproject.toml`) are derived from it. The engine submodule `rust/lib/eve-fit-os` has independent versioning.
- `./x release version show` — display current version.
- `./x release version bump <major|minor|patch> [--pre-label ...] [--clear-pre]` — bump and auto-sync.
- `./x release check` — runs 10 pre-release gates (version-sync, git-clean, schema-bump, persistence-check, submodule, generate, lint, changelog, etc.). Fatal gates block release unless `--force`.
- `./x release commit` — creates a signed `chore: release v<version>` commit and annotated tag.
- All releases happen from the `dev` branch; `main` is deprecated.

## Validation Expectations

- After edits, run the relevant formatter and linter; for mixed-language or uncertain changes, run `./x lint`.
- Run relevant tests before committing: `./x test python` or `./x test dart` depending on what changed.
- Dart-only minimum: `dart format lib/` plus `dart analyze`; run `./x generate dart` when annotations/routes/Riverpod/freezed/json models change.
- Python-only minimum: `uv run ruff format` plus `uv run ruff check --fix`.
- Rust bridge minimum: `cargo fmt --package rust_lib_eve_fit_assistant` plus `cargo clippy --fix --allow-dirty --package rust_lib_eve_fit_assistant`.
- Rust fitting-engine logic changes should also run targeted `cargo test -p eve-fit-os ...`.
- Localization changes require `./x generate l10n`; `l10n/app_zh.arb` is the template ARB with placeholder metadata, while `l10n/app_en.arb` should contain translations only.
- JS/TS (site/ dir): run `pnpm run check` in `site/` for SvelteKit type checks; `npx biome check --fix` for formatting/linting.

## Style And Generated-Code Gotchas

- Dart analyzer is strict (`strict-casts`, `strict-inference`, `strict-raw-types`) and enforces package imports, double quotes, explicit public API types, and 100-column formatting.
- Python Ruff requires `from __future__ import annotations`, absolute imports, one import per line, double quotes, and 100-column formatting; `rust/lib/` is excluded from root Ruff.
- Root `rustfmt.toml` uses 100 columns plus field-init and `?` shorthands; the bridge crate stays Rust 2021 because of `flutter_rust_bridge`.
- Keep FRB-facing APIs small and explicit in `rust/src/api/`; put core fitting behavior in `rust/lib/eve-fit-os` when possible.
- Do not manually edit generated bridge/localization/protobuf/build outputs unless the task is explicitly about generated artifacts; change sources and run the matching generator.

## Python Pipeline

- `data/lib/remote/session.py` — Session manager for the `efa/v2/` layout
  (`SessionManager`), inheriting from `_BaseSessionManager`. Manages
  generation lifecycle, resource registration, announcement/release
  management, and S3/R2 publishing.

## Local Instruction Sources

- No `.github/workflows/` (no CI). No `.cursor/rules/`, `.cursorrules`, or `opencode.json`.
- `CLAUDE.md` is a symlink to this file.
