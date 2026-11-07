# efa_platform_client

Scope: the platform API client facade exposed as
`package:efa_platform_client/efa_platform_client.dart` (`PlatformSession` auth flows and
token lifecycle, public platform reads, authenticated writes).

## Hard Constraints

- Keep this package pure Dart (no Flutter imports) and free of app-storage dependencies;
  persistence is injected via `PlatformSessionStore`, Dio instances via `dioFactory`.
- Only the entrypoint is public API; `src/` clients (`AccountApiClient`,
  `PlatformApiClient`) and token types are package-internal (imported directly only by
  tests).

## Docs

- ACL roles/tokens: [../efa_acl/AGENTS.md](../efa_acl/AGENTS.md)
- Platform API behavior: `worker/efa-platform-api/`
- Validation: `melos run pkg:test`.
