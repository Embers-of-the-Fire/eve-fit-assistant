# EVE Fit Assistant App

Scope: the Flutter application, its Rust FRB bridge (`rust/`), the `efa-chat` Rust crate
(`rust/lib/efa-chat/`), and the cargokit wrapper (`rust_builder/`).

## Local Rules

- Paths in repository docs written as `lib/...`, `test/...`, `rust/...`, `l10n/...`, or
  `web/...` are relative to this directory unless stated otherwise.
- Treat `rust_builder/` as Flutter plugin/cargokit glue, not as the main Rust source tree.
- Do not hand-edit generated outputs: `lib/native/`, `lib/data/l10n/`, `*.g.dart`, and
  `*.freezed.dart`.
- Route, Riverpod, freezed, JSON-model, and annotation changes require the matching Dart
  generator; localization changes require `./x generate l10n`.
- Keep FRB APIs in `rust/src/api/` small and explicit; choose `#[frb(sync)]`, `async`, or a
  normal function according to @docs/agents/engineering-conventions.
- UI work must follow @docs/agents/style and @docs/agents/color.
- Developer-mode-only UI uses hardcoded English as described in
  @docs/agents/developer-mode.

## Subsystem Docs

- Storage and data flow: @docs/agents/storage
- Fit deep links and sharing: @docs/agents/app-links
- AI chat: @docs/agents/efa-chat
- Developer mode: @docs/agents/developer-mode
- Environment: @docs/agents/environment
- Builds and tests: @docs/agents/build-and-test

## Common Commands

Run from the repository root unless noted:

This guide covers both Dart and Rust, so mixed-language changes must also pass the
repository-wide `./x lint` check in addition to the per-language commands below.

```sh
melos run app:format
melos run app:analyze
melos run app:test
melos run app:gen
./x generate dart
./x generate l10n
./x generate rust
./x lint
cargo test -p rust_lib_eve_fit_assistant
cargo test -p efa-chat
```
