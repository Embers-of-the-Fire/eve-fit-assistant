import "dart:async";
import "dart:io";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:eve_fit_assistant/features/schema_guard/schema_guard.dart" show SchemaGuard;
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/channel_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_registry_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_service.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/native_dir.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/repo_error.dart";
import "package:eve_fit_assistant/storage/repo/repo_state.dart";
import "package:eve_fit_assistant/storage/repo/schema_version.dart";
import "package:eve_fit_assistant/storage/repo/service.dart";
import "package:eve_fit_assistant/storage/repo/verification.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "providers.g.dart";

// ── Infrastructure providers ───────────────────────────────────────────────────

@riverpodSingleton
String remoteContentOriginUrl(Ref ref) =>
    ref.watch(appSettingServiceProvider).remoteContent.originUrl;

@riverpodSingleton
Dio remoteDio(Ref ref) => createRemoteDio();

// ── Sub-service providers ──────────────────────────────────────────────────────

@riverpodSingleton
SchemaVersionService schemaVersionService(Ref ref) => const SchemaVersionService();

@riverpodSingleton
AssetStore assetStore(Ref ref) => const AssetStore();

@riverpodSingleton
NativeDirResolver nativeDirResolver(Ref ref) =>
    NativeDirResolver(assetStore: ref.watch(assetStoreProvider));

@riverpodSingleton
DiffEngine diffEngine(Ref ref) => const DiffEngine();

@riverpodSingleton
RemoteCatalogService remoteCatalogService(Ref ref) => RemoteCatalogService(
  dio: ref.watch(remoteDioProvider),
  originUrl: ref.watch(remoteContentOriginUrlProvider),
);

@riverpodSingleton
CheckoutRegistryService checkoutRegistryService(Ref ref) => CheckoutRegistryService();

@riverpodSingleton
ChannelService channelService(Ref ref) => ChannelService(
  remoteCatalogService: ref.watch(remoteCatalogServiceProvider),
  assetStore: ref.watch(assetStoreProvider),
);

@riverpodSingleton
CheckoutService checkoutService(Ref ref) => CheckoutService(
  assetStore: ref.watch(assetStoreProvider),
  remoteCatalogService: ref.watch(remoteCatalogServiceProvider),
  diffEngine: ref.watch(diffEngineProvider),
  checkoutRegistry: ref.watch(checkoutRegistryServiceProvider),
);

@riverpodSingleton
VerificationService verificationService(Ref ref) => VerificationService(
  checkoutService: ref.watch(checkoutServiceProvider),
  assetStore: ref.watch(assetStoreProvider),
  checkoutRegistry: ref.watch(checkoutRegistryServiceProvider),
  remoteCatalogService: ref.watch(remoteCatalogServiceProvider),
);

// ── Top-level orchestrator ─────────────────────────────────────────────────────

@riverpodSingleton
RepoService repoService(Ref ref) => RepoService(
  checkoutRegistry: ref.watch(checkoutRegistryServiceProvider),
  checkoutService: ref.watch(checkoutServiceProvider),
  channelService: ref.watch(channelServiceProvider),
  assetStore: ref.watch(assetStoreProvider),
  diffEngine: ref.watch(diffEngineProvider),
  verificationService: ref.watch(verificationServiceProvider),
  remoteCatalogService: ref.watch(remoteCatalogServiceProvider),
);

// ── Reactive stream providers ─────────────────────────────────────────────────

/// Stream of [CheckoutRegistry] changes from the checkout registry file watcher.
@Riverpod(keepAlive: true)
Stream<CheckoutRegistry> activeCheckoutWatch(Ref ref) =>
    ref.watch(checkoutRegistryServiceProvider).watch;

// ── Derived convenience providers ──────────────────────────────────────────────

@riverpodSingleton
Option<CheckoutRegistryEntry> activeCheckout(Ref ref) {
  ref.watch(activeCheckoutWatchProvider);
  return ref.watch(repoServiceProvider).activeCheckout();
}

@riverpodSingleton
Option<String> activeCheckoutId(Ref ref) {
  ref.watch(activeCheckoutWatchProvider);
  return ref.watch(repoServiceProvider).activeCheckoutId();
}

/// Returns the active checkout's resource snapshot hash, or [None].
@riverpodSingleton
Option<String> activeSnapshotHash(Ref ref) {
  ref.watch(activeCheckoutWatchProvider);
  return ref.watch(repoServiceProvider).activeSnapshotHash();
}

/// The current active checkout entry, or `null` if none.
///
/// Primary provider that UI should observe for active-state decisions.
@riverpodSingleton
CheckoutRegistryEntry? currentActive(Ref ref) => ref.watch(activeCheckoutProvider).toNullable();

/// Convenience alias for [activeCheckoutProvider].
@riverpodSingleton
Option<CheckoutRegistryEntry> currentCheckout(Ref ref) => ref.watch(activeCheckoutProvider);

// ── Lifecycle notifier ─────────────────────────────────────────────────────────

/// Lifecycle notifier for the repo system.
///
/// Watched by [SchemaGuard] to gate the app: uninitialized triggers auto-init,
/// initializing shows a spinner, active renders content (or redirects to setup
/// when no checkout is active), error shows a retry screen.
@riverpodSingleton
class RepoStateNotifier extends _$RepoStateNotifier {
  @override
  RepoState build() => const RepoState.uninitialized();

  bool get isInitialized => switch (state) {
    RepoStateActive() => true,
    _ => false,
  };

  CheckoutRegistryEntry? get activeEntry => switch (state) {
    RepoStateActive(:final entry) => entry,
    _ => null,
  };

  /// Reads checkouts.json, loads the active checkout manifest, prepares the
  /// native directory for the Rust engine. Transitions through
  /// [RepoState.initializing] -> [RepoState.active] or [RepoState.error].
  ///
  /// After a successful transition to [RepoState.active], a non-blocking
  /// background startup sync is launched to discover channels and sync
  /// generation metadata for the active channel (spec §9).
  Future<void> initialize() async {
    state = const RepoState.initializing();
    try {
      final repo = ref.read(repoServiceProvider);

      final registryOpt = repo.checkoutRegistry.readRegistry();
      if (registryOpt.isSome()) {
        final registry = registryOpt.toNullable()!;
        repo.checkoutRegistry.seedStream();

        final activeId = registry.activeCheckoutId;

        if (activeId != null) {
          final entry = registry.checkouts[activeId];
          if (entry != null) {
            // Prepare native dir if resource index is available
            final snapshotHash = entry.resourceSnapshotHash;
            final ri = ref.read(assetStoreProvider).readResourceIndexSync(snapshotHash);
            if (ri.isSome()) {
              await ref
                  .read(nativeDirResolverProvider)
                  .prepareNativeDir(snapshotHash, ri.toNullable()!);
            }
            state = RepoState.active(entry: entry);
          } else {
            state = RepoState.error(
              error: RepoError.corrupt(
                message: "Active checkout not found in registry",
                filePath: RepoPaths.checkoutRegistryPath,
              ),
            );
          }
        } else {
          // Registry exists but no active checkout — need setup
          state = const RepoState.active();
        }
      } else {
        // Check whether the file exists but couldn't be parsed (corruption),
        // vs truly missing (first launch).  This prevents inadvertently
        // overwriting a corrupted-but-present file with an empty registry.
        final registryFile = File(RepoPaths.checkoutRegistryPath);
        if (registryFile.existsSync()) {
          state = RepoState.error(
            error: RepoError.corrupt(
              message: "Checkout registry exists but could not be read",
              filePath: RepoPaths.checkoutRegistryPath,
            ),
          );
        } else {
          // No registry — first launch
          await repo.checkoutRegistry.ensureRegistry();
          state = const RepoState.active();
        }
      }
    } on RepoError catch (e) {
      state = RepoState.error(error: e);
    } catch (e) {
      state = RepoState.error(error: RepoError.storage(message: e.toString()));
    }

    // Launch background startup sync after successful initialization
    if (state is RepoStateActive) {
      unawaited(_startBackgroundSync());
    }
  }

  /// Non-blocking background sync: discovers channels and syncs generation
  /// metadata for the active channel (spec §9).
  ///
  /// Runs only when remote content is enabled. Failures are logged and never
  /// surfaced to the UI — this is purely additive cache warming.
  Future<void> _startBackgroundSync() async {
    try {
      final settings = ref.read(appSettingServiceProvider);
      if (!settings.remoteContent.enabled) return;

      final repo = ref.read(repoServiceProvider);

      // Discover channels
      final discoverResult = await repo.discoverChannels();
      if (discoverResult.isLeft()) {
        debug("Startup sync: channel discovery failed: ${discoverResult.getLeft().toNullable()}");
        return;
      }

      // Sync active channel generation metadata
      final activeEntry = repo.checkoutRegistry.activeCheckoutEntry();
      if (activeEntry.isNone()) return;
      final activeChannel = activeEntry.toNullable()!.channel;

      final syncResult = await repo.syncChannelGeneration(activeChannel);
      if (syncResult.isLeft()) {
        debug(
          "Startup sync: generation sync failed for $activeChannel: "
          "${syncResult.getLeft().toNullable()}",
        );
      }
    } catch (e, stackTrace) {
      debug("Startup sync failed", stackTrace: stackTrace);
    }
  }
}

// ── Checkout-derived providers ─────────────────────────────────────────────────

/// The absolute path to the resolved `native/` directory for the Rust engine,
/// or `null` if no active checkout is installed.
///
/// When the active checkout changes, this provider invalidates so that the
/// engine can re-initialize against the new resolved directory.
@riverpodSingleton
String? assetStaticRoot(Ref ref) {
  final activeOpt = ref.watch(activeCheckoutProvider);
  if (activeOpt.isNone()) return null;
  final active = activeOpt.toNullable()!;
  if (active.resourceSnapshotHash.isEmpty) return null;
  return ref.read(nativeDirResolverProvider).resolvePathFromSnapshot(active.resourceSnapshotHash);
}

/// All installed (active) checkout IDs from the checkout registry.
///
/// Returns all checkout UUIDs in the registry (since all checkouts in the
/// new schema are considered installed once resource data is fetched).
@riverpodSingleton
IList<String> installedCheckoutIds(Ref ref) {
  ref.watch(activeCheckoutWatchProvider);
  final registry = ref.watch(checkoutRegistryServiceProvider).readRegistry();
  return registry.match(() => const IList.empty(), (r) => r.checkouts.keys.toIList());
}
