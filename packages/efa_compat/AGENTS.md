# efa_compat

Scope: platform compatibility shims for `dart:io`, Dart isolates, and web WASM
preconditions.

- Keep APIs small and platform-neutral.
- The web cross-origin-isolation probe used by the WASM engine bootstrap lives here.
- Do not move application feature logic into this package.

Validation: use the narrowest relevant melos Dart test/analyze command, or `./x lint` for
cross-package changes.
