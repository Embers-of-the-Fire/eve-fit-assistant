# efa_compat

Scope: platform compatibility shims for `dart:io`, Dart isolates, and web WASM
preconditions.

- Keep APIs small and platform-neutral.
- Do not move application feature logic into this package.
- The web cross-origin-isolation probe used by the WASM engine bootstrap lives here.

## Docs

- Builds and tests: [docs/dev/build-and-test.md](../../docs/dev/build-and-test.md)
- Validation: narrowest relevant melos Dart test/analyze command, or `./x lint` for
  cross-package changes.
