# Application Storage and Management

The app uses [`riverpod`](https://riverpod.dev) to manage data.

## Concept, Choice and Suggestion

There're four layers of data storage:
- [Global state](#global-state), including [settings (`AppSettingService`)](../../apps/eve-fit-assistant/lib/storage/setting/setting.dart).
  The global state is used across the app, and should be loaded at the app start.
  Any error in global state is considered critical,
  and should be immediately available once the splash screen is dismissed.
- [Global data](#global-data), including [the repository system (`RepoService`)](../../apps/eve-fit-assistant/lib/storage/repo/service.dart).
  This layer is also error-critical, but can be loaded after the app start.
  The app should show a loading indicator when the user tries to access this data.
- [Service data](#service-data), loaded by managers, is offered as a global provider (in riverpod).
  Error is permitted and the source might change during the app lifetime.
  The app should show a loading indicator when the user tries to access this data,
  and should not let any error break the app.
- Web data, loaded through network requests.
  Error is permitted and the source might change during the app lifetime.
  The app should show a loading indicator when the user tries to access this data,
  and should not let any error break the app.

To properly handle and manage states, the application follows these principles:
1. States (except global states) must be provided through a `Provider` (or its variants).
   This ensures that the state is easily accessible and manageable throughout the app.
2. If the state contains complicated logic, use a `service` to handle the logic.
   This service class is responsible for fetching, updating, and managing the data.
   For example, type data are served through `RepoCollectionService`.
3. If the state will change, a `manager` class should be created to handle the state changes.
   This manager class is responsible for updating the state and notifying any listeners of changes.
   For example, `FitManager` manages the fit data state.
4. The `manager` class should be a singleton, ensuring that there is only one instance
   managing the state throughout the app. Use `@riverpodSingleton` to create a singleton provider.
5. The `manager` class do not need to expose data interfaces as the data should be forwarded to
   the state providers themselves.
6. The `manager` class should not depend on any UI components or contexts.
   This ensures that the business logic is separated from the UI logic,
   making the code more modular and easier to maintain.

## Dependencies and Code

### Global State

- `AppSettingService` > `AppSetting`: This contains global app-level settings.
  The settings document is the `settings.json` key in the `UserDataDomain.settings`
  `DocStore`: on native a `FileDocStore` rooted at `PathProvider.settingsPath`
  (`<settingsPath>/settings.json`), on web the `efa_settings` Hive box backed by IndexedDB.
  The global settings might be dependent on consumers that do not have a `Ref` environment,
  So the data is actually maintained in the global singleton.
  However, the `AppSettingService` is also a riverpod singleton for better consistence.
  - `locale (riverpod)`: This is a shortcut of `appSettingService.locale`.

### Global Data

- `RepoService`: The content-addressed repository service.
  It owns checkout lifecycle, channel discovery, and resource fetching.
  See [Storage Systems](#storage-systems) for the repository system.
- `CheckoutRegistryService`: The checkout registry manager.
  The registry is stored in `checkouts/checkouts.json` under the repository storage.
  This service offers the checkout registry data interface.
- `FitManager`: The overall fit data manager. This provider offers no direct data interface.
- `FitRegistryManager` > `FitRegistry`: The fit registry manager.
  The registry is stored as the `registry.json` key in the `UserDataDomain.fittings`
  `DocStore`: on native a `FileDocStore` rooted at `PathProvider.fittingsPath`
  (`<appSupport>/runtime/v2/fittings/registry.json`), on web the `efa_fittings` Hive
  box backed by IndexedDB.
  The registry is versioned through the fit persistence layer.
  This provider offers the fit registry data interface.
  Registry writes go through `FitRegistryManager.updateFit`, which is called by
  `FitManager` (fit creation and import) and by `Fit.update` (the fit editing path),
  so the `FitManager` is not the only writer.
  See [Fit Storage and Versioning](./fit-storage.md) for the on-disk format.

### Service Data

- `RepoCollectionService`: The structural type-data source.
  It pre-loads ships, skills, items, and icon metadata from the active checkout's
  `ResourceIndex`, returning logical icon paths; the image assets themselves are
  resolved separately and lazily by `ImageAssetService`.
- `LocalizationDbService`: Resolves localized strings from the active checkout's
  per-locale `localization/locales/<locale>.db` (falling back to the legacy combined
  `localization.db`, then placeholders); `localizedNameProvider` resolves `(id, locale)`
  on demand. Download decisions for checkout resources go through the Resource
  Resolution Schema (`resolveResource`), which resolves each index entry against the
  active locale instead of reading the server-stamped download policy.
- `FitService` > `FitServiceStatus`: The fit service.
  This provider offers the fit service status data interface.
  Fit files are decoded through the versioned fit persistence layer,
  and legacy alpha payloads are eagerly normalized when loaded.
  The value might be changed by the `FitManager`.
- `FitEmulatorService` > `FitEmulatorState`: The wrapper over backend engine service.
  See [this file](../../apps/eve-fit-assistant/lib/storage/fit/service.dart) for details.
- `NativeFitEngineService` > `NativeFitEngineState`: The backend(native) engine service.
  See [this dart port](../../apps/eve-fit-assistant/lib/storage/fit/service.dart)
  and [this rust source](../../apps/eve-fit-assistant/rust/src/api/server.rs) for more information.

## Storage Systems

The storage layer is centered on the content-addressed repository under
`apps/eve-fit-assistant/lib/storage/repo/`. It implements the EFA V2 unified storage schema:
generation-based, protobuf-driven, checkout-based data management with blob storage,
resource snapshots, channel discovery, checkout lifecycle handling, and Riverpod providers.

### Systems

| System | Path | Description |
| ------ | ---- | ----------- |
| Repo System | `lib/storage/repo/` | Content-addressed repository implementing the EFA V2 unified storage schema. |
| Schema Version | `lib/storage/repo/schema_version.dart` | `SchemaVersionService` reads/writes `schema_version.json` and determines the active storage system. |
| Channel Discovery | `lib/storage/repo/channel_service.dart` | `ChannelService` fetches the channel registry, head metadata, and server index; it also performs update detection. |
| Checkout Management | `lib/storage/repo/checkout_registry_service.dart` | `CheckoutRegistryService` manages `checkouts/checkouts.json`, the active checkout pointer, and the reactive stream. |
| Checkout Lifecycle | `lib/storage/repo/checkout_service.dart` | `CheckoutService` provides checkout CRUD, reflog management, and resource-fetch orchestration. |
| Release Sync | `lib/storage/repo/release_sync.dart` | `ReleaseSyncService` detects newer app versions against the remote release index via the `ReleaseIndex` protobuf; it only detects releases. |
| Generation Navigation | `lib/storage/repo/generation_nav.dart` | `GenerationNavigationService` backs the setup page's channel-to-server browser. |
| Repo Collection | `lib/storage/repo/collection.dart` | `RepoCollectionService` is the sole structural type-data source and pre-loads ships, skills, items, and icon metadata (returning logical icon paths) from the active checkout's `ResourceIndex`; image assets resolve separately via `ImageAssetService`. |
| Localization DB | `lib/storage/repo/localization_db.dart` | `LocalizationDbService` resolves lazy localized strings through the §4.3 lookup chain: the per-locale `localization/locales/<locale>.db` (schema "2") when its entry is in the index, else the legacy combined `localization.db` (schema "1"), else placeholders. At most one open handle per requested locale; SQL text is identical for both databases. Native opens the content-addressed blob read-only; web copies the blob once per content hash into sqlite3_web's OPFS path (per-locale prefix `locales_<locale>`, disjoint from the legacy `localization` prefix so stale-dir pruning cannot cross-delete) and opens it in a web worker. `localizedNameProvider` resolves `(id, locale)` on demand. `localizationDbAvailabilityProvider(locale)` exposes the tri-state availability (`available` / `downloadable(size)` / `updateRequired`) behind the locale-switch download flow in `lib/features/locale_switch/`. |
| Resource Resolution Schema | `lib/storage/repo/resource_resolution.dart` | `resolveResource(index, entry, context)` evaluates the app-shipped RRS (v3, `kResourceResolutionSchemaVersion`): the ordered rules (legacy localization db excluded when per-locale replacements exist; active locale's db eager; other locales, images, static 3D models, and static skyboxes lazy; default eager) decide every download — the server-stamped `download_policy` is no longer read by the client. `lib/storage/repo/resource_policy.dart` gates the index `format_version` at `kMaxSupportedResourceIndexFormatVersion = 4` (4 admits lazy `static/skyboxes/` entries; 3 admits lazy `static/models/` entries); beyond it, `UnsupportedResourceIndexError` routes to the app-update flow. The rule set, RRS version, context shape, and layout vocabulary are single-sourced in `data/schema/resource_resolution.toml`: codegen emits the evaluator and context (`lib/storage/repo/resource_resolution.g.dart`, fixed header `data/schema/resource_resolution.header.dart`) plus the vocabulary constants (`lib/constant/resource_vocabulary.g.dart`), and the pipeline derives the stamped `download_policy` for pre-RRS clients from the same spec. |
| Ship Models | `lib/storage/repo/model_asset.dart`, `lib/components/model/ship_model_viewer.dart` | `ModelAssetService` resolves baked per-ship GLBs from the blob store (`resource://static/models/ships/<typeId>.<variant>.glb`, variants `full`/`base`, lazy on-demand reads). `ShipModelViewer` renders them with flutter_scene (Flutter GPU): orbit controls, texture decode capped at 2048 px and view pixel ratio capped at 2. The default variant comes from the `shipModelVariant` setting; the viewer's overlay toggle switches per view only. |
| Skyboxes and scene lighting | `lib/storage/repo/skybox_asset.dart`, `lib/components/model/skybox_environment.dart` | `SkyboxAssetService` resolves baked environment skyboxes (`resource://static/skyboxes/<id>.hdr` Radiance equirects plus `<id>.pb2` `SkyboxMetadata` sidecars) and the lazy `lighting_profiles.pb2` catalog from the blob store; the resource index enumerates environments from `.hdr` entries only. `ShipModelViewer` selects a lighting profile from viewer mode + ship type independently of the environment setting, then renders the environment as IBL + visible background + one profile-driven sun key, loading it independently of the model. Item-preview keys follow the live camera; fitting uses its authored fixed direction. Background intensity, reflection intensity, and additive scene ambient are separated, with ambient composed into the sidecar's precomputed diffuse SH. Built `EnvironmentMap`s are cached app-wide (`SkyboxEnvironmentCache`, LRU of 4) by environment id + ambient RGB + reflection intensity. The skybox picker remains per-view page state, never persisted; `auto` follows the active profile, with race/faction environment fallbacks from `Type.race_id`/`faction_id` and `Collection.faction_races`. Web requires usable precomputed SH rather than running the SH quadrature. |
| Checkout DB Transport | `lib/storage/repo/checkout_db*.dart` | Shared transport for prebuilt checkout SQLite databases: `CheckoutDbSpec` (resource id, OPFS name prefix, schema version, label), native read-only open, web OPFS copy and worker open, and the `meta.schema_version` check. |
| Agent Resource DB | `lib/storage/repo/agent_resource_db.dart` | `AgentResourceDbService` opens `agent_resource.db`, a FORCE resource backing AI chat tools. Its schema-v2 `type_names(locale, id, value, group_id, category_id, slot_index, slot_kind)` table provides localized names plus group/category and implant/booster slot metadata for `search_items`. This is a hard dependency: opening/providers throw when absent or schema-mismatched. |
| Migration Layer | `lib/storage/repo/migration/` | `action/` contains `MigrateService` (fits → characters → finalize), `MigrateFits`, `MigrateCharacters`, the freezed `MigrateProgress` state machine and `MigrateProgressStore`, and the migration result types. Progress persists to `.migration_progress.json`. |
| Persistence | `lib/storage/fit/`, `lib/storage/character/` | Fit and character storage schemas; fits support storage version 4 with `systemBuffs` (v3 added `CheckoutRef`). |
| Settings | `lib/storage/setting/` | User settings, including remote content and platform account configuration. |
| Account/Auth | `lib/features/account/` | `PlatformSession` providers (from `packages/efa_platform_client`), the secure-storage `SecurePlatformSessionStore` adapter, and settings UI. |
| Platform | `lib/features/platform/` | Riverpod state for the platform community pages (`lib/pages/platform/`): the cursor-paginated post feed, post detail (record + `FitSnapshot` rendered by `packages/efa_fit_snapshot`), and comment listing/creation. Comment deletion/editing is deferred. |
| Storage FS | `lib/storage/fs/` | `DocStore`/`BlobStore` abstraction with File (native) and Hive/OPFS (web) backends; `createUserDocStore` and `createRepoBlobStore` route settings, fits, characters, announcements, feedback, and version state to the right backend. |

### Concurrency And Startup

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

### Data-Flow Orchestration

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

### Storage Tests

Repository-module tests run from the app directory with `dart test test/storage/repo/`.
Migration tests use `dart test test/storage/repo/migration/`. Data-flow
integration tests use `package:mocktail` for network and filesystem mocks; async tests require
`flutter test` or `dart test` with the Flutter SDK on `PATH`.

## Version Axes

The storage version numbers are independent axes, each single-sourced: fit-storage and
fit-registry envelopes and the native payload envelope live in
`lib/storage/fit/persistence.dart`, the `EFA<n>:` prefix version in
`packages/efa_fit/lib/src/efa_format.dart`, and the repo data schema version in
`efa.config.toml` (`[version].data_schema`, generated into `repo_version.dart`).
Do not bake version numbers into file or resource names. When bumping any axis, update
`docs/dev/fit-storage.md` examples in the same commit and run
`uv run pytest bootstrap/tests/test_version_alignment.py`, which enforces cross-file
alignment.
