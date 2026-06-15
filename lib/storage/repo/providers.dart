import "dart:io";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:eve_fit_assistant/features/schema_guard/schema_guard.dart" show SchemaGuard;
import "package:eve_fit_assistant/storage/repo/active.dart";
import "package:eve_fit_assistant/storage/repo/announcement_sync.dart";
import "package:eve_fit_assistant/storage/repo/announcements.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/branch.dart";
import "package:eve_fit_assistant/storage/repo/checkout.dart";
import "package:eve_fit_assistant/storage/repo/checkout_resolution.dart";
import "package:eve_fit_assistant/storage/repo/compatibility.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/generation_nav.dart";
import "package:eve_fit_assistant/storage/repo/models/active.dart";
import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/models/branch.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_index.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
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
ActiveService activeService(Ref ref) => ActiveService();

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
AnnouncementService announcementService(Ref ref) => const AnnouncementService();

@riverpodSingleton
AnnouncementSyncService announcementSyncService(Ref ref) => AnnouncementSyncService(
  remoteCatalogService: ref.watch(remoteCatalogServiceProvider),
  localIndexPath: RepoPaths.runtimeAnnouncementsPath,
  supportedLocales: IList(const ["zh", "en"]),
);

@riverpodSingleton
RemoteCatalogService remoteCatalogService(Ref ref) => RemoteCatalogService(
  dio: ref.watch(remoteDioProvider),
  originUrl: ref.watch(remoteContentOriginUrlProvider),
);

@riverpodSingleton
ReleaseSyncService releaseSyncService(Ref ref) =>
    ReleaseSyncService(remoteCatalogService: ref.watch(remoteCatalogServiceProvider));

@riverpodSingleton
GenerationNavigationService generationNavService(Ref ref) =>
    GenerationNavigationService(remoteCatalogService: ref.watch(remoteCatalogServiceProvider));

@riverpodSingleton
CheckoutService checkoutService(Ref ref) => CheckoutService(
  assetStore: ref.watch(assetStoreProvider),
  remoteCatalogService: ref.watch(remoteCatalogServiceProvider),
  diffEngine: ref.watch(diffEngineProvider),
);

@riverpodSingleton
BranchService branchService(Ref ref) => BranchService(
  checkoutService: ref.watch(checkoutServiceProvider),
  diffEngine: ref.watch(diffEngineProvider),
  assetStore: ref.watch(assetStoreProvider),
  remoteCatalogService: ref.watch(remoteCatalogServiceProvider),
);

@riverpodSingleton
CompatibilityService compatibilityService(Ref ref) => const CompatibilityService();

@riverpodSingleton
CheckoutResolver checkoutResolver(Ref ref) => CheckoutResolver(
  checkoutService: ref.watch(checkoutServiceProvider),
  remoteCatalogService: ref.watch(remoteCatalogServiceProvider),
  activeService: ref.watch(activeServiceProvider),
  compatibilityService: ref.watch(compatibilityServiceProvider),
);

@riverpodSingleton
VerificationService verificationService(Ref ref) => VerificationService(
  checkoutService: ref.watch(checkoutServiceProvider),
  assetStore: ref.watch(assetStoreProvider),
  branchService: ref.watch(branchServiceProvider),
  remoteCatalogService: ref.watch(remoteCatalogServiceProvider),
);

// ── Top-level orchestrator ─────────────────────────────────────────────────────

@riverpodSingleton
RepoService repoService(Ref ref) => RepoService(
  activeService: ref.watch(activeServiceProvider),
  branchService: ref.watch(branchServiceProvider),
  checkoutService: ref.watch(checkoutServiceProvider),
  assetStore: ref.watch(assetStoreProvider),
  diffEngine: ref.watch(diffEngineProvider),
  checkoutResolver: ref.watch(checkoutResolverProvider),
  verificationService: ref.watch(verificationServiceProvider),
  remoteCatalogService: ref.watch(remoteCatalogServiceProvider),
  announcementService: ref.watch(announcementServiceProvider),
);

// ── Reactive stream providers ─────────────────────────────────────────────────

/// Stream of [Active] changes from the `active.json` file watcher.
@Riverpod(keepAlive: true)
Stream<Active> activeWatch(Ref ref) => ref.watch(activeServiceProvider).watch;

/// Stream of branch list changes from the `branches/` directory watcher.
@Riverpod(keepAlive: true)
Stream<IList<Branch>> branchesWatch(Ref ref) => ref.watch(branchServiceProvider).watchBranches();

// ── Derived convenience providers ──────────────────────────────────────────────

@riverpodSingleton
Option<Active> activeCheckout(Ref ref) {
  ref.watch(activeWatchProvider);
  return ref.watch(repoServiceProvider).activeBranch();
}

@riverpodSingleton
IList<Branch> branches(Ref ref) {
  ref.watch(branchesWatchProvider);
  return ref.watch(repoServiceProvider).branches();
}

@riverpodSingleton
Option<AssetManifest> activeCheckoutManifest(Ref ref) {
  final active = ref.watch(activeCheckoutProvider);
  if (active.isNone()) return const None();
  final checkoutId = active.toNullable()!.checkoutId;
  return ref.watch(checkoutServiceProvider).readManifest(checkoutId);
}

/// Returns a map of branch IDs to their latest available remote checkout ID
/// (or `null` if no update is available for that branch).
///
/// Fetches the manifest index to resolve the activated generation, then delegates
/// to [BranchService.checkForUpdates] for per-branch remote timestamp comparison.
@Riverpod(keepAlive: true)
Future<IMap<String, String?>> branchesWithUpdates(Ref ref, Channel channel) async =>
    ref.watch(repoServiceProvider).checkForUpdates(channel: channel);

// ── Dedicated providers (06-02) ─────────────────────────────────────────────────

/// The current active state from `active.json`, or `null` if no activation exists.
///
/// This is a convenience wrapper around [activeCheckoutProvider] that unwraps the
/// `Option<Active>` into a nullable `Active?`. It is the primary provider
/// that UI should observe for active-state decisions.
@riverpodSingleton
Active? currentActive(Ref ref) => ref.watch(activeCheckoutProvider).toNullable();

/// The active branch record from `branches/<uuid>.json`, or `null` if the
/// active state is detached (`branchId: null`) or unset.
///
/// Re-evaluates when either the active state or the branch directory changes.
@riverpodSingleton
Branch? currentBranch(Ref ref) {
  final active = ref.watch(currentActiveProvider);
  if (active == null || active.branchId == null) return null;
  final branches = ref.watch(branchesProvider);
  return branches.where((b) => b.id == active.branchId).firstOrNull;
}

/// Convenience alias for [activeCheckoutProvider].
/// Returns `None` when no checkout is active, `Some(active)` otherwise.
@riverpodSingleton
Option<Active> currentCheckout(Ref ref) => ref.watch(activeCheckoutProvider);

/// All installed checkout hashes from `checkouts/index.json`.
///
/// Scans the index and returns the IDs of every checkout with
/// state == [CheckoutState.installed]. Useful for verification,
/// pruning, and storage management pages.
@riverpodSingleton
IList<String> installedCheckoutIds(Ref ref) {
  final index = ref.watch(checkoutServiceProvider).readIndex();
  return index.match(
    () => const IList.empty(),
    (i) => i.entries.entries
        .where((e) => e.value.state == CheckoutState.installed)
        .map((e) => e.key)
        .toIList(),
  );
}

/// All known (discovered but not yet installed) checkout hashes from
/// `checkouts/index.json`.
///
/// Scans the index and returns the IDs of every checkout with
/// state == [CheckoutState.known]. Useful for checkout selection filters.
@riverpodSingleton
IList<String> knownCheckoutIds(Ref ref) {
  final index = ref.watch(checkoutServiceProvider).readIndex();
  return index.match(
    () => const IList.empty(),
    (i) => i.entries.entries
        .where((e) => e.value.state == CheckoutState.known)
        .map((e) => e.key)
        .toIList(),
  );
}

/// The absolute path to the resolved `native/` directory for the Rust engine,
/// or `null` if no active checkout is installed.
///
/// When the active checkout changes, this provider invalidates so that the
/// engine can re-initialize against the new resolved directory.
@riverpodSingleton
String? assetStaticRoot(Ref ref) {
  final manifest = ref.watch(activeCheckoutManifestProvider);
  if (manifest.isNone()) return null;
  return ref.read(nativeDirResolverProvider).resolvePathFromManifest(manifest.toNullable()!);
}

// ── Lifecycle notifier ─────────────────────────────────────────────────────────

/// Lifecycle notifier for the repo system.
///
/// Watched by [SchemaGuard] to gate the app: uninitialized triggers auto-init,
/// initializing shows a spinner, active renders content (or redirects to setup
/// when checkoutId is empty), error shows a retry screen.
@riverpodSingleton
class RepoStateNotifier extends _$RepoStateNotifier {
  @override
  RepoState build() => const RepoState.uninitialized();

  bool get isInitialized => switch (state) {
    RepoStateActive() => true,
    _ => false,
  };
  Active? get active => switch (state) {
    RepoStateActive(:final active) => active,
    _ => null,
  };

  /// Checkout IDs that were recovered from partial downloads during initialization.
  /// Available after [initialize()] completes, for UI notification.
  IList<String> recoveredCheckoutIds = const IList.empty();

  /// Reads active.json, loads the active checkout manifest, prepares the
  /// native directory for the Rust engine. Transitions through
  /// [RepoState.initializing] -> [RepoState.active] or [RepoState.error].
  Future<void> initialize() async {
    state = const RepoState.initializing();
    try {
      final repo = ref.read(repoServiceProvider);

      // Recover partial downloads from a previous interrupted session.
      recoveredCheckoutIds = repo.recoverPartialDownloads();

      final activeOpt = repo.activeBranch();
      if (activeOpt.isSome()) {
        final a = activeOpt.toNullable()!;
        final manifest = ref.read(checkoutServiceProvider).readManifest(a.checkoutId);
        if (manifest.isSome()) {
          await ref.read(nativeDirResolverProvider).prepareNativeDir(manifest.toNullable()!);
          state = RepoState.active(active: a);
        } else {
          state = RepoState.error(
            error: RepoError.corrupt(
              message: "Active checkout manifest is missing",
              filePath: RepoPaths.checkoutManifestPath(a.checkoutId),
            ),
          );
        }
      } else {
        // Check if active.json exists but was unreadable (corrupt)
        final activeFile = File(RepoPaths.activePath);
        if (activeFile.existsSync()) {
          state = RepoState.error(
            error: RepoError.corrupt(
              message: "active.json is corrupt",
              filePath: RepoPaths.activePath,
            ),
          );
          return;
        }
        // No active checkout -- caller routes to branch setup.
        final now = DateTime.now().toUtc().toIso8601String();
        state = RepoState.active(
          active: Active(
            schemaVersion: 2,
            checkoutId: "",
            activatedAt: now,
            serverId: "",
            metadata: const GameMetadata(gameServer: "", gameBuild: "", gameVersion: ""),
          ),
        );
      }
    } on RepoError catch (e) {
      state = RepoState.error(error: e);
    } catch (e) {
      state = RepoState.error(error: RepoError.storage(message: e.toString()));
    }
  }
}

// ── Generation navigation providers ──────────────────────────────────────────────

/// Fetches the generation tree (generations + servers) for [channel].
@Riverpod(keepAlive: true)
Future<GenerationTree> generationTree(Ref ref, Channel channel) async {
  final result = await ref.read(generationNavServiceProvider).fetchTree(channel);
  return result.fold((error) => throw error, (tree) => tree);
}

/// Fetches server detail (with checkout list) for a specific server.
@Riverpod(keepAlive: true)
Future<GenerationServerDetail> serverDetail(
  Ref ref,
  String genId,
  String serverId,
  Channel channel,
) async {
  final result = await ref
      .read(generationNavServiceProvider)
      .fetchServerDetail(channel, genId, serverId);
  return result.fold((error) => throw error, (detail) => detail);
}
