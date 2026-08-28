# Storage Layer

The storage layer is centered on the content-addressed repository under
`apps/eve-fit-assistant/lib/storage/repo/`. It implements the EFA V2 unified storage schema:
generation-based, protobuf-driven, checkout-based data management with blob storage,
resource snapshots, channel discovery, checkout lifecycle handling, and Riverpod providers.

## Systems

| System | Path | Description |
| ------ | ---- | ----------- |
| Repo System | `lib/storage/repo/` | Content-addressed repository implementing the EFA V2 unified storage schema. |
| Schema Version | `lib/storage/repo/schema_version.dart` | `SchemaVersionService` reads/writes `schema_version.json` and determines the active storage system. |
| Channel Discovery | `lib/storage/repo/channel_service.dart` | `ChannelService` fetches the channel registry, head metadata, and server index; it also performs update detection. |
| Checkout Management | `lib/storage/repo/checkout_registry_service.dart` | `CheckoutRegistryService` manages `checkouts/checkouts.json`, the active checkout pointer, and the reactive stream. |
| Checkout Lifecycle | `lib/storage/repo/checkout_service.dart` | `CheckoutService` provides checkout CRUD, reflog management, and resource-fetch orchestration. |
| Release Sync | `lib/storage/repo/release_sync.dart` | `ReleaseSyncService` detects newer app versions against the remote release index via the `ReleaseIndex` protobuf; it only detects releases. |
| Generation Navigation | `lib/storage/repo/generation_nav.dart` | `GenerationNavigationService` backs the setup page's channel-to-server browser. |
| Repo Collection | `lib/storage/repo/collection.dart` | `RepoCollectionService` is the sole structural type-data source and pre-loads ships, skills, items, and icons from the active checkout's `ResourceIndex`. |
| Localization DB | `lib/storage/repo/localization_db.dart` | `LocalizationDbService` resolves lazy localized strings from the checkout's prebuilt SQLite `localization.db` through sqlite_async. Native opens the content-addressed blob read-only; web copies the blob once per content hash into sqlite3_web's OPFS path and opens it in a web worker. `localizedNameProvider` resolves `(id, locale)` on demand. |
| Checkout DB Transport | `lib/storage/repo/checkout_db*.dart` | Shared transport for prebuilt checkout SQLite databases: `CheckoutDbSpec` (resource id, OPFS name prefix, schema version, label), native read-only open, web OPFS copy and worker open, and the `meta.schema_version` check. |
| Agent Resource DB | `lib/storage/repo/agent_resource_db.dart` | `AgentResourceDbService` opens `agent_resource.db`, a FORCE resource backing AI chat tools. Its schema-v2 `type_names(locale, id, value, group_id, category_id, slot_index, slot_kind)` table provides localized names plus group/category and implant/booster slot metadata for `search_items`. This is a hard dependency: opening/providers throw when absent or schema-mismatched. |
| Migration Layer | `lib/storage/repo/migration/` | `action/` contains `MigrateService` (fits → characters → finalize), `MigrateFits`, `MigrateCharacters`, the freezed `MigrateProgress` state machine and `MigrateProgressStore`, and the migration result types. Progress persists to `.migration_progress.json`. |
| Persistence | `lib/storage/fit/`, `lib/storage/character/` | Fit and character storage schemas; fits support storage version 3 with `CheckoutRef`. |
| Settings | `lib/storage/setting/` | User settings, including remote content and platform account configuration. |
| Account/Auth | `lib/features/account/` | `PlatformSession` providers (from `packages/efa_platform_client`), the secure-storage `SecurePlatformSessionStore` adapter, and settings UI. |
| Platform | `lib/features/platform/` | Riverpod state for the platform community pages (`lib/pages/platform/`): the cursor-paginated post feed, post detail (record + `FitSnapshot` rendered by `packages/efa_fit_snapshot`), and comment listing/creation. Comment deletion/editing is deferred. |
| Storage FS | `lib/storage/fs/` | `DocStore`/`BlobStore` abstraction with File (native) and Hive/OPFS (web) backends; `createUserDocStore` and `createRepoBlobStore` route settings, fits, characters, announcements, feedback, and version state to the right backend. |

## Concurrency And Startup

All writes to `checkouts.json` are mutex-guarded; reads are lock-free. The checkout registry
provides a reactive stream for live UI updates.

`RepoStateNotifier` initializes asynchronously at startup. `SchemaGuard` watches the state and
renders the appropriate screens. `MigrationGate` checks for v1 data remnants and offers a
one-time migration prompt before the repository system activates.

`SecurePlatformSessionStore` stores the account session as one JSON document under a single
key for atomic rotation writes, with legacy read fallbacks (a pre-identity blob without
email/user id, and a per-field triple); it also stores the developer Cloudflare Access
service token (Client ID/Client Secret) as one JSON document. The session lifecycle itself
(cold-start rotation through eager
instantiation in `initWithRef`, expiry tracking, and the session mutex that re-reads the
stored session inside the critical section) is owned by `PlatformSession` in
`packages/efa_platform_client`.

## Data-Flow Orchestration

| Workflow | Entry point | Service path |
| -------- | ----------- | ------------ |
| Channel discovery | `discoverChannels()` | `RepoService` → `ChannelService.discoverChannels()` |
| Resource fetch | `fetchResourcesForActiveCheckout()` | `RepoService` → `CheckoutService.fetchResourcesForCheckout()` |
| Create checkout | `createCheckout()` | `RepoService` → `CheckoutService.createCheckout()` |
| Revert | `revertActiveCheckoutTo()` | `RepoService` → `CheckoutService.revertCheckoutTo()` |
| Checkout resolution | `resolveCheckoutRefAsync()` | `RepoService` → `CheckoutResolver.resolveAsync()` |
| Update discovery | `checkForUpdates()` | `RepoService` → `ChannelService.hasUpdates()` |
| Verification repair | `verifyAndRepair()` | `RepoService` → `VerificationService.repairAll()` |
| Checkout lifecycle | `switchActiveCheckout()` / `deleteCheckout()` | `RepoService` |
| Prune | `prune()` | `RepoService` → `VerificationService.prune()` |
| Startup recovery | `recoverPartialDownloads()` | `RepoService`, called from `ensureInitialized()` |

## Tests

Repository-module tests run from the app directory with `dart test test/storage/repo/`.
Migration tests use `dart test test/storage/repo/migration/`. Data-flow
integration tests use `package:mocktail` for network and filesystem mocks; async tests require
`flutter test` or `dart test` with the Flutter SDK on `PATH`.
