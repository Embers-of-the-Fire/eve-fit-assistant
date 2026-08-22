# Engineering Conventions

This file collects cross-language style, generated-code, and validation expectations. The
nearest scoped `AGENTS.md` may add local rules.

## Generated Code

Do not manually edit generated bridge, localization, protobuf, freezed, JSON, or build
outputs unless the task explicitly concerns generated artifacts. Change the source and rerun
the matching generator:

- all generators plus formatting: `./x generate -f all`;
- protobuf: `./x generate protobuf`;
- Rust bridge: `./x generate rust`;
- Dart: `./x generate dart` or `melos run app:gen`;
- localization: `./x generate l10n`;
- dogma units: `./x generate values dogma-units`.

## Language Rules

- Dart analysis is strict (`strict-casts`, `strict-inference`, `strict-raw-types`) and
  enforces package imports, double quotes, explicit public API types, and 100-column
  formatting.
- Python Ruff requires `from __future__ import annotations`, absolute imports, one import per
  line, double quotes, and 100-column formatting. `apps/eve-fit-assistant/rust/lib/` is
  excluded from root Ruff.
- The root `rustfmt.toml` uses 100 columns plus field-init and `?` shorthands. The bridge
  crate remains Rust 2021 because of `flutter_rust_bridge`.
- Localization changes require `./x generate l10n`. `l10n/app_zh.arb` is the template ARB
  with placeholder metadata; `l10n/app_en.arb` contains translations only.
- For JS/TS site packages, run the package's `check` script (for example
  `pnpm --filter efa-tech check` or `pnpm --filter efa-platform check`) and
  `pnpm dlx biome check --fix site` for formatting/linting.

## Flutter Rust Bridge Threading

Choose the FRB function flavor by threading intent:

- `#[frb(sync)]` runs on the caller's thread/event loop; use it only for cheap calls.
- `async` runs on the main browser event loop on web; never use it for CPU-heavy work.
- A plain ("normal") function runs on FRB's thread pool, backed by the Web Worker pool on web
  when the atomics build and COOP/COEP headers are present.

Heavy engine work must stay in normal functions. Keep FRB-facing APIs small and explicit in
`apps/eve-fit-assistant/rust/src/api/`; put core fitting behavior in `packages/eve-fit-os`
where practical.

## Validation Minimums

After edits, run the relevant formatter and linter. For mixed-language or uncertain changes,
run `./x lint`. Run relevant tests before committing.

| Change type | Minimum validation |
| ----------- | ------------------ |
| Dart-only | `melos run app:format` and `melos run app:analyze`; run `./x generate dart` when annotations, routes, Riverpod, freezed, or JSON models change. |
| Python-only | `uv run ruff format` and `uv run ruff check --fix`. |
| Rust bridge | `cargo fmt --package rust_lib_eve_fit_assistant` and `cargo clippy --fix --allow-dirty --package rust_lib_eve_fit_assistant`. |
| Rust fitting-engine logic | The bridge minimum as applicable plus targeted `cargo test -p eve-fit-os ...`. |
| Localization | `./x generate l10n`, then Dart format/analyze as applicable. |
| Site JS/TS | `pnpm run check` in the relevant site and `pnpm dlx biome check --fix site`. |

Broad test entry points are documented in @docs/agents/build-and-test.
