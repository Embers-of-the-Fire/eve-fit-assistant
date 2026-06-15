/// Barrel export for the repo module.
///
/// The repo system is a content-addressed data versioning layer implementing the
/// EFA V2 unified storage schema (agent/schemav2/).
///
/// ## Component Map
///
/// - **RepoService** (`service.dart`) — Riverpod singleton orchestrator. Provides
///   channel discovery, checkout lifecycle, resource fetch, update detection,
///   revert, announcement fetch, and verification.
/// - **CheckoutRegistryService** (`checkout_registry_service.dart`) — manages
///   `checkouts/checkouts.json`, the active checkout pointer, and emits a
///   reactive stream for UI observation.
/// - **CheckoutService** (`checkout_service.dart`) — checkout CRUD, reflog
///   management, and resource fetch orchestration.
/// - **ChannelService** (`channel_service.dart`) — channel discovery, head
///   metadata, server index management, update detection.
/// - **SchemaVersionService** (`schema_version.dart`) — reads and writes
///   `schema_version.json`; determines the active storage schema.
/// - **AssetStore** (`assets.dart`) — content-addressed blob I/O under
///   `<schema root>/assets/blobs/` with atomic writes.
/// - **DiffEngine** (`diff.dart`) — on-demand diff between ResourceIndex
///   protobufs.
/// - **RemoteCatalogService** (`remote_catalog.dart`) — HTTP-based remote
///   catalog syncing under `efa/v2/`.
/// - **VerificationService** (`verification.dart`) — verifies local integrity
///   and prunes unreferenced data.
/// - **RepoCollectionService** (`collection.dart`) — pre-loads type data
///   (ships, skills, items, localization, icon paths) from the active
///   checkout's resource snapshot via the ResourceIndex protobuf.
/// - **NativeDirResolver** (`native_dir.dart`) — resolves a virtual native
///   directory for the Rust fitting engine based on the active checkout's
///   resource index.
/// - **AnnouncementService** (`announcements.dart`) — manages announcement
///   snapshot caching and content retrieval.
/// - **AnnouncementSyncService** (`announcement_sync.dart`) — fetches
///   announcement snapshots from the generation chain.
/// - **ReleaseSyncService** (`release_sync.dart`) — checks for newer APK
///   releases via the release index.
/// - **CheckoutResolver** (`checkout_resolution.dart`) — resolves fit/character
///   CheckoutRef against the local checkout registry.
/// - **CompatibilityService** (`compatibility.dart`) — pure-function
///   compatibility check between checkout refs.
/// - **GenerationNavigationService** (`generation_nav.dart`) — navigates the
///   channel → server tree for the setup page.
/// - **RepoPaths** (`paths.dart`) — path resolution for the
///   `<schema root>/resources/v2/` layout.
/// - **RepoHash** (`hash.dart`) — SHA-256 primitives and structured hash
///   formulas (resource snapshot, release snapshot, announcement snapshot,
///   generation).
/// - **RepoState** (`repo_state.dart`) — lifecycle state union (uninitialized /
///   initializing / active / error).
/// - **RepoError** (`repo_error.dart`) — sealed class with `network`, `storage`,
///   `corrupt`, `remoteData` variants.
/// - **Riverpod providers** (`providers.dart`) — all Riverpod singletons,
///   reactive stream providers, and the RepoStateNotifier lifecycle manager.
/// - **models/** — freezed data models (channel registry, checkout registry,
///   head metadata, checkout metadata, snapshot metadata, generation metadata,
///   diff, compatibility, shared types).
/// - **Migration subsystem** (`migration/`) — `MigrateService`, `MigrateFits`,
///   `MigrateCharacters`, `MigrateProgress`, and v1→v2 fit/character upgrade.
library;

export "announcement_sync.dart";
export "announcements.dart";
export "assets.dart";
export "channel_service.dart";
export "checkout_registry_service.dart";
export "checkout_resolution.dart";
export "checkout_service.dart";
export "collection.dart";
export "compatibility.dart";
export "diff.dart";
export "generation_nav.dart";
export "hash.dart";
export "models/models.dart";
export "native_dir.dart";
export "paths.dart";
export "providers.dart";
export "release_sync.dart";
export "remote_catalog.dart";
export "repo_error.dart";
export "repo_state.dart";
export "schema_version.dart";
export "service.dart";
export "verification.dart";
