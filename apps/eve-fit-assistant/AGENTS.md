# EVE Fit Assistant App

Scope: the Flutter application, its Rust FRB bridge (`rust/`), the `efa-chat` Rust crate
(`rust/lib/efa-chat/`), and the cargokit wrapper (`rust_builder/`).

## Hard Constraints

- Paths in repository docs written as `lib/...`, `test/...`, `rust/...`, `l10n/...`, or
  `web/...` are relative to this directory unless stated otherwise.
- Treat `rust_builder/` as Flutter plugin/cargokit glue, not as the main Rust source tree.
- Do not hand-edit generated outputs: `lib/native/`, `lib/data/l10n/`, `*.g.dart`, and
  `*.freezed.dart`.
- Route, Riverpod, freezed, JSON-model, and annotation changes require the matching Dart
  generator; localization changes require `./x generate l10n`.
- Mixed Dart+Rust changes must also pass the repository-wide `./x lint`.

## Docs

- Storage and data flow: [docs/dev/app-storage.md](../../docs/dev/app-storage.md)
- Style and color: [docs/dev/style.md](../../docs/dev/style.md), [docs/dev/color.md](../../docs/dev/color.md)
- Engineering conventions (FRB API shape): [docs/dev/engineering-conventions.md](../../docs/dev/engineering-conventions.md)
- Fit deep links and sharing: [docs/dev/app-links.md](../../docs/dev/app-links.md)
- AI chat: [docs/dev/efa-chat.md](../../docs/dev/efa-chat.md)
- Developer mode: [docs/dev/developer-mode.md](../../docs/dev/developer-mode.md)
- Environment: [docs/dev/setup-and-config.md](../../docs/dev/setup-and-config.md)
- Builds and tests: [docs/dev/build-and-test.md](../../docs/dev/build-and-test.md)
- Validation: per-language format/analyze/test via melos, `./x generate ...`, `./x lint`.
