# efa_platform_client

Scope: the platform API client facade exposed as
`package:efa_platform_client/efa_platform_client.dart`.

The package provides:

- `PlatformSession`, the single facade app code talks to: account auth flows
  (signup, verification, login, password reset, logout, deregistration), the
  whole token lifecycle (storage via the app-implemented
  `PlatformSessionStore`, expiry tracking, mutex-serialized refresh,
  cold-start rotation, 401 retry, session clearing), the public
  `/platform/internal` read endpoints, and authenticated writes built on the
  `authed` escape hatch (currently `createComment`);
- `PlatformIdentity`/`identity`/`me` for the signed-in profile (derived
  locally: JWT subject + cached email), and
  `PlatformAccountInfo`/`accountInfo()` for the server-side account record
  (`POST /platform/auth/account`: identity plus the placeholder ACL roles and
  their resolved permission tokens — see `packages/efa_acl`);
- `PlatformAuthRequiredException` plus the `onAuthRequired` hook for the
  "interactive login required" signal (throttled to once per signed-out
  stretch);
- the public read models (`PostSummary`, `PostListPage`, `PostRecord`,
  `ThreadSummary`), the comment models (`Comment`, `CommentListPage`), the
  ship directory models (`ShipSummary`, `ShipListPage`, `ShipDetail`), the
  stats models (`PlatformStats`, `TopShip`), the shared `PlatformTimeWindow`
  listing filter, plus the API exceptions (`AccountApiException`,
  `PlatformApiException`);
- `platformApiProductionOrigin`, the single production-origin constant.

Only the entrypoint is public API; `src/` clients (`AccountApiClient`,
`PlatformApiClient`) and token types are package-internal and imported
directly only by tests.

Keep this package pure Dart (no Flutter imports) and free of app-storage
dependencies; persistence is injected via `PlatformSessionStore`, Dio
instances via `dioFactory`.

Validation:

```sh
melos run pkg:test
```
