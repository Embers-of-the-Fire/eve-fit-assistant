# AGENTS.md

Compact repo guidance for future OpenCode sessions. Prefer executable config and `./x --help` over stale prose if anything conflicts.

## Workspace Shape

- Flutter/Dart app code is under `lib/`; generated Dart outputs include `lib/native/`, `lib/data/l10n/`, protobuf outputs, `*.g.dart`, and `*.freezed.dart`.
- Rust has two layers: FRB bridge crate in `rust/` (`rust/src/api/*`) and the fitting engine git-submodule crate in `rust/lib/eve-fit-os`.
- Python in `data/` plus `x.py` owns workspace management, codegen orchestration, and static data bundle generation.
- `rust_builder/` is the Flutter plugin/cargokit wrapper used by `pubspec.yaml`; avoid treating it as the main Rust source.
- `site/` is a SvelteKit app deployed to Cloudflare Workers (pnpm workspace). `biome.json` governs JS/TS formatting/linting for this area.
- `rust/lib/eve-fit-os` is a Git submodule; run `git submodule update --init` after clone if not already initialized.

## Environment And Setup

- Use `nix develop`; `flake.nix` supplies Flutter, JDK 17, Android SDK/NDK, Rust/Cargo, `uv`, protobuf tools, and `flutter_rust_bridge_codegen`.
- Bootstrap with `./x dev env install` or, equivalently, `flutter pub get` and `uv sync` inside the dev shell.
- Do not hand-edit `android/local.properties` unless needed; the Nix shell hook regenerates it with only SDK/NDK/CMake paths derived from the Nix environment. Flutter build properties (version, build mode, etc.) are not touched and are read from `pubspec.yaml` directly.
- Python requires 3.13+ and is managed by `uv`; run `x.py` through `./x`, `./x.ps1`, or `uv run x.py`, not a global Python.
- Backend Rust builds/tests/codegen need `rust/lib/eve-fit-os/.env`; normally create `efa.dev.toml` with `./x dev init-cfg`, set `[native]`, then run `./x dev env write-backend`.

## Canonical Commands

- Full fix/lint/format pass (all languages): `./x lint`.
- Formatting only: `./x format` (`./x lint --no-check`).
- Generate all code and then format: `./x generate all -f`.
- Focused generators: `./x generate protobuf`, `./x generate rust`, `./x generate dart`, `./x generate l10n`, `./x generate values dogma-units`.
- Android build: `flutter build apk`.
- Bridge crate build/test: `cargo build -p rust_lib_eve_fit_assistant`, `cargo test -p rust_lib_eve_fit_assistant`.
- Engine build/test: `cargo build -p eve-fit-os`, `cargo test -p eve-fit-os`.
- Single Rust integration test file/function: `cargo test -p eve-fit-os --test test_basic_fit -- --nocapture`; `cargo test -p eve-fit-os test_basic_fit -- --exact --nocapture`.
- Python tests: `./x test python` or `uv run pytest`.
- Flutter/Dart tests: `./x test dart` or `flutter test`.
- All tests: `./x test all`.

## Data Workspaces And Bundles

- Workspaces are declared in `efa.config.toml`; changing that file is a project-level datasource/config change, not a local preference.
- Select data with `./x workspace list` and `./x workspace default <workspace>`; override per command with `./x --ws <workspace> ...`.
- Build selected workspace data with `./x build data`; use `./x build data --no-hash` only for faster local iteration because it does not create a usable baseline manifest.
- Incremental patch bundles are strict: build a fresh full snapshot first, then run `./x build increment <baseline_manifest>` using the last published `bundle_manifest.json`.
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

## Local Instruction Sources

- No `.github/workflows/` (no CI). No `.cursor/rules/`, `.cursorrules`, or `opencode.json`.
- `CLAUDE.md` is a symlink to this file.
