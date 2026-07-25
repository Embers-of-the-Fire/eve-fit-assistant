import "dart:async";
import "dart:io";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_notifier.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:eve_fit_assistant/features/schema_guard/schema_guard.dart" show SchemaGuard;
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/batch_data_update_status.dart";
import "package:eve_fit_assistant/storage/repo/channel_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_registry_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_service.dart";
import "package:eve_fit_assistant/storage/repo/data_update_service.dart";
import "package:eve_fit_assistant/storage/repo/data_update_status.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/generation_nav.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_app_release.dart";
import "package:eve_fit_assistant/storage/repo/native_dir.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/release_sync.dart";
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
ReleaseSyncService releaseSyncService(Ref ref) =>
    ReleaseSyncService(remoteCatalogService: ref.watch(remoteCatalogServiceProvider));

@riverpodSingleton
GenerationNavigationService generationNavigationService(Ref ref) =>
    GenerationNavigationService(remoteCatalogService: ref.watch(remoteCatalogServiceProvider));

/// Fetches the available channels for the setup/welcome channel browser.
///
/// Surfaces a [GenerationNavError] as an [AsyncError] so the UI can render a
/// retry affordance; invalidate this provider to retry.
@riverpod
Future<ChannelOverview> channelOverview(Ref ref) async =>
    (await ref.watch(generationNavigationServiceProvider).fetchChannels()).match(
      (e) => throw e,
      (o) => o,
    );

/// Fetches the server list for [channelName] for the setup/welcome server
/// browser. Surfaces a [GenerationNavError] as an [AsyncError] so the UI can
/// render a retry affordance; invalidate this provider to retry.
@riverpod
Future<IList<ServerSummary>> serverList(Ref ref, String channelName) async =>
    (await ref
            .watch(generationNavigationServiceProvider)
            .fetchServers(
              channel: Channel.tryParse(channelName) ?? Channel.defaultChannel,
              channelName: channelName,
            ))
        .match((e) => throw e, (o) => o);

/// Fetches the server list with per-server blob maps for [channelName].
///
/// Uses [GenerationNavigationService.fetchServerSelectionData] to include
/// per-server `{contentHash → size}` maps so the server step can compute the
/// deduplicated download footprint across selected servers.
@riverpod
Future<ServerSelectionData> serverSelectionData(Ref ref, String channelName) async =>
    (await ref
            .watch(generationNavigationServiceProvider)
            .fetchServerSelectionData(
              channel: Channel.tryParse(channelName) ?? Channel.defaultChannel,
              channelName: channelName,
            ))
        .match((e) => throw e, (o) => o);

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

@riverpodSingleton
DataUpdateService dataUpdateService(Ref ref) => DataUpdateService(
  repoService: ref.watch(repoServiceProvider),
  channelService: ref.watch(channelServiceProvider),
  checkoutService: ref.watch(checkoutServiceProvider),
  assetStore: ref.watch(assetStoreProvider),
  nativeDirResolver: ref.watch(nativeDirResolverProvider),
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
      // Clean up orphaned temp files/dirs from interrupted writes before
      // trusting the on-disk state.
      final repo = ref.read(repoServiceProvider)..recoverPartialDownloads();

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
      final originUrl = settings.remoteContent.originUrl;

      // Discover channels
      final discoverResult = await repo.discoverChannels();
      if (discoverResult.isLeft()) {
        final error = discoverResult.getLeft().toNullable()!;
        debug("Startup sync: channel discovery failed [$originUrl]: $error");
        return;
      }

      // Sync generation metadata for the configured channel (so release checks
      // work even without an active checkout) and for the active checkout's
      // channel (so data-update checks stay current).
      final configuredChannel = settings.remoteContent.channel;
      final activeEntry = repo.checkoutRegistry.activeCheckoutEntry();
      final channelsToSync = <String>{
        if (configuredChannel.isNotEmpty) configuredChannel,
        if (activeEntry.isSome()) activeEntry.toNullable()!.channel,
      };

      for (final channel in channelsToSync) {
        final syncResult = await repo.syncChannelGeneration(channel);
        if (syncResult.isLeft()) {
          final error = syncResult.getLeft().toNullable()!;
          debug("Startup sync: generation sync failed for $channel [$originUrl]: $error");
        }
      }

      // After generation metadata is synced, check whether a newer app release
      // is available. This is best-effort and must not block normal operation.
      // The base provider is invalidated (rather than the derived ones) so the
      // freshly cached release pointer is actually re-read.
      ref.invalidate(appReleaseCheckStatusProvider);
      unawaited(
        ref.read(availableAppReleaseProvider.future).then((_) => null).catchError((
          Object e,
          StackTrace st,
        ) {
          debug("Startup app-release check failed: $e", stackTrace: st);
        }),
      );
    } catch (e, stackTrace) {
      debug("Startup sync failed", stackTrace: stackTrace);
    }
  }
}

@riverpodSingleton
class BatchDataUpdateController extends _$BatchDataUpdateController {
  @override
  BatchDataUpdateStatus build() {
    ref.watch(activeCheckoutWatchProvider);
    return const BatchDataUpdateStatus.unknown();
  }

  /// Triggers a check only when the current status is `unknown`.
  Future<void> ensureCheck() async {
    if (state is! BatchDataUpdateStatusUnknown) return;
    await check();
  }

  /// Checks all checkouts for available updates.
  Future<void> check() async {
    if (state is BatchDataUpdateStatusChecking || state is BatchDataUpdateStatusDownloading) return;

    state = const BatchDataUpdateStatus.checking();
    try {
      final results = await ref.read(dataUpdateServiceProvider).checkAllCheckouts();

      final available = <String, String>{};
      var hasFailed = false;
      String failureMessage = "";

      for (final entry in results.entries) {
        final result = entry.value;
        switch (result) {
          case DataUpdateCheckResultAvailable(:final newGenerationHash):
            available[entry.key] = newGenerationHash;
          case DataUpdateCheckResultFailed(:final message):
            hasFailed = true;
            failureMessage = message;
          case DataUpdateCheckResultUpToDate():
            break;
        }
      }

      if (available.isNotEmpty) {
        state = BatchDataUpdateStatus.available(available);
      } else if (hasFailed) {
        state = BatchDataUpdateStatus.failed(
          message: failureMessage.isEmpty ? "Failed to check for updates" : failureMessage,
          canRetry: true,
        );
      } else {
        state = const BatchDataUpdateStatus.upToDate();
      }
    } catch (e) {
      state = BatchDataUpdateStatus.failed(
        message: "Failed to check for updates: $e",
        canRetry: true,
      );
    }
  }

  /// Applies updates to all checkouts that have updates available.
  Future<void> apply() async {
    if (state is BatchDataUpdateStatusDownloading) return;

    state = const BatchDataUpdateStatus.downloading(
      BatchUpdateProgress(
        currentCheckoutId: "",
        completedCount: 0,
        totalCount: 0,
        downloadedCount: 0,
        totalDownloadCount: 0,
      ),
    );

    try {
      final result = await ref
          .read(dataUpdateServiceProvider)
          .applyAllCheckouts(
            onProgress: (progress) => state = BatchDataUpdateStatus.downloading(progress),
          );

      if (result.failures.isNotEmpty && result.successes.isEmpty) {
        state = const BatchDataUpdateStatus.failed(
          message: "No checkouts could be updated",
          canRetry: true,
        );
      } else {
        state = BatchDataUpdateStatus.applied(result);
      }

      // Re-initialize the repo lifecycle so the Rust engine and collection
      // providers observe any new snapshot hashes and native directories.
      await ref.read(repoStateProvider.notifier).initialize();
    } catch (e) {
      state = BatchDataUpdateStatus.failed(message: "Failed to apply update: $e", canRetry: true);
    }
  }

  /// Moves the transient `applied` state back to `upToDate`.
  void acknowledgeApplied() => state = const BatchDataUpdateStatus.upToDate();
}

@riverpod
class CheckoutUpdateController extends _$CheckoutUpdateController {
  @override
  DataUpdateStatus build(String checkoutId) => const DataUpdateStatus.unknown();

  String? get _channelName {
    final registry = ref.read(repoServiceProvider).checkoutRegistry.readRegistry();
    return registry
        .flatMap((r) => Option.fromNullable(r.checkouts[checkoutId]))
        .toNullable()
        ?.channel;
  }

  /// Checks for an update for this checkout.
  Future<void> check() async {
    if (state is DataUpdateStatusChecking || state is DataUpdateStatusDownloading) return;

    state = const DataUpdateStatus.checking();
    try {
      final result = await ref.read(dataUpdateServiceProvider).checkForCheckout(checkoutId);

      state = result.when(
        upToDate: (current) => DataUpdateStatus.upToDate(currentGenerationHash: current),
        available: (current, next) =>
            DataUpdateStatus.available(currentGenerationHash: current, newGenerationHash: next),
        failed: (message, canRetry) =>
            DataUpdateStatus.failed(message: message, canRetry: canRetry),
      );
    } catch (e) {
      state = DataUpdateStatus.failed(message: "Failed to check for updates: $e", canRetry: true);
    }
  }

  /// Applies the available update for this checkout.
  Future<void> apply() async {
    if (state is DataUpdateStatusDownloading) return;

    state = const DataUpdateStatus.downloading(downloadedCount: 0, totalCount: 0);

    try {
      final result = await ref
          .read(dataUpdateServiceProvider)
          .applyCheckoutUpdate(
            checkoutId,
            onProgress: (downloaded, total) {
              state = DataUpdateStatus.downloading(downloadedCount: downloaded, totalCount: total);
            },
          );

      state = result.match(
        (err) => DataUpdateStatus.failed(message: err, canRetry: true),
        (snapshotHash) => DataUpdateStatus.applied(newSnapshotHash: snapshotHash),
      );

      if (result.isRight()) {
        await ref.read(repoStateProvider.notifier).initialize();
      }
    } catch (e) {
      state = DataUpdateStatus.failed(message: "Failed to apply update: $e", canRetry: true);
    }
  }

  /// Moves the transient `applied` state back to `upToDate`.
  void acknowledgeApplied() {
    final channelName = _channelName;
    final currentHash = channelName != null
        ? ref.read(channelServiceProvider).localGenerationHash(channelName) ?? ""
        : "";
    state = DataUpdateStatus.upToDate(currentGenerationHash: currentHash);
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

// ── App release update provider ───────────────────────────────────────────────

/// Compares the installed app version against the remote release index for
/// the configured channel, reporting the full tri-state outcome (update
/// available, up to date, or ahead of the remote release).
///
/// Returns [ReleaseCheckUnavailable] when the check cannot run locally
/// (remote content disabled, no configured channel, or no cached release
/// pointer). Failures are surfaced as [AsyncError] so callers can decide how
/// to handle them, but startup code should swallow them to avoid interfering
/// with normal operations.
///
/// This provider is intentionally decoupled from the active checkout: a
/// release is global to the origin/channel, so it can be advertised even
/// before the user has created a checkout. It is the base provider for app
/// release checks — invalidate it (after syncing the channel generation) to
/// force a fresh check.
@riverpod
Future<ReleaseCheckStatus> appReleaseCheckStatus(Ref ref) async {
  final settings = ref.watch(appSettingServiceProvider);
  if (!settings.remoteContent.enabled) return const ReleaseCheckUnavailable();

  final channelName = settings.remoteContent.channel;
  if (channelName.isEmpty) return const ReleaseCheckUnavailable();

  final pointer = ref.read(channelServiceProvider).readReleasePointer(channelName);
  if (pointer.isNone()) return const ReleaseCheckUnavailable();

  // A pointer without a snapshot hash means the channel has no app release
  // published at all — there is nothing newer, so report up to date.
  final snapshotHash = pointer.toNullable()!.snapshotHash;
  if (snapshotHash.isEmpty) return const ReleaseCheckUpToDate();

  final result = await ref
      .read(releaseSyncServiceProvider)
      .checkStatusFromSnapshotHash(
        snapshotHash: snapshotHash,
        ignoreBugfix: settings.ignoreBugfixUpdates,
      );

  return result.fold(
    (error) => Future<ReleaseCheckStatus>.error(error, StackTrace.current),
    Future<ReleaseCheckStatus>.value,
  );
}

/// Detects whether a newer app release is available from the remote release
/// index for the configured channel.
///
/// Returns [Some] with the newer [RemoteAppRelease] when the remote version is
/// greater than the installed version. Failures are surfaced as [AsyncError] so
/// callers can decide how to handle them, but startup code should swallow them
/// to avoid interfering with normal operations.
///
/// This provider is intentionally decoupled from the active checkout: a release
/// is global to the origin/channel, so it can be advertised even before the
/// user has created a checkout.
@riverpod
Future<Option<RemoteAppRelease>> remoteAppRelease(Ref ref) async {
  final status = await ref.watch(appReleaseCheckStatusProvider.future);
  return switch (status) {
    ReleaseCheckUpdateAvailable(:final release) => Some(release),
    _ => const None(),
  };
}

/// Detects whether a newer app release is available and has not been dismissed.
///
/// Returns [Some] with the newer [RemoteAppRelease] when the remote version is
/// greater than the installed version and the release has not been acknowledged.
/// Failures are surfaced as [AsyncError] so callers can decide how to handle
/// them, but startup code should swallow them to avoid interfering with normal
/// operations.
///
/// This provider is intentionally decoupled from the active checkout: a release
/// is global to the origin/channel, so it can be advertised even before the
/// user has created a checkout.
@riverpod
Future<Option<RemoteAppRelease>> availableAppRelease(Ref ref) async {
  final release = await ref.watch(remoteAppReleaseProvider.future);
  final releaseValue = release.toNullable();
  if (releaseValue == null) return const None();

  final acknowledgedId = ref.read(appVersionStateStoreProvider).lastAcknowledgedReleaseId;
  if (releaseValue.releaseId == acknowledgedId) return const None();

  return release;
}
