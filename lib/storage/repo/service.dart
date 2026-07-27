import "dart:io";

import "package:eve_fit_assistant/features/remote_content/cache_manager.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/channel_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_registry_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_service.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_registry.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/models/server_meta.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/verification.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";
import "package:path/path.dart" as p;

/// Top-level orchestrator for all storage operations.
///
/// Holds and coordinates all sub-services. Delegation methods provide a typed
/// facade so callers interact with a single entry point.
class RepoService {
  const RepoService({
    required this.checkoutRegistry,
    required this.checkoutService,
    required this.channelService,
    required this.assetStore,
    required this.diffEngine,
    required this.verificationService,
    required this.remoteCatalogService,
  });

  final CheckoutRegistryService checkoutRegistry;
  final CheckoutService checkoutService;
  final ChannelService channelService;
  final AssetStore assetStore;
  final DiffEngine diffEngine;
  final VerificationService verificationService;
  final RemoteCatalogService remoteCatalogService;

  // ── Channel discovery ──────────────────────────────────────────────────────

  /// Fetches available channels from remote and persists locally.
  /// Returns the channel registry with available channels.
  Future<Either<String, Unit>> discoverChannels() async {
    final result = await channelService.discoverChannels();
    return result.map((_) => unit);
  }

  /// Fetches channel head metadata and server index for [channelName].
  Future<Either<String, Unit>> fetchChannelInfo(String channelName) =>
      channelService.fetchChannelInfo(channelName);

  /// Fetches and persists all generation-level files for [channelName].
  ///
  /// Best-effort: individual file failures are logged but do not abort the sync.
  Future<Either<String, Unit>> syncChannelGeneration(
    String channelName, {
    void Function(int current, int total)? onProgress,
  }) => channelService.syncChannelGeneration(channelName, onProgress: onProgress);

  // ── Checkout lifecycle ─────────────────────────────────────────────────────

  /// The active checkout ID, or [None].
  Option<String> activeCheckoutId() => checkoutRegistry.activeCheckoutId();

  /// The active checkout entry, or [None].
  Option<CheckoutRegistryEntry> activeCheckout() => checkoutRegistry.activeCheckoutEntry();

  /// Returns `true` when no checkout is active (detached mode).
  bool get isDetached => checkoutRegistry.isDetached;

  /// Returns `true` when no setup exists (first launch, no checkouts).
  bool get hasNoSetup => checkoutRegistry.hasNoSetup;

  /// Creates a new checkout and triggers resource fetch.
  ///
  /// Steps per spec §2.3.1:
  /// 1. Resolve the resource snapshot hash from the generation
  /// 2. Create checkout entry and metadata
  /// 3. Trigger resource fetch
  Future<Option<String>> createCheckout({
    required Channel channel,
    required String channelName,
    required String serverId,
    required IMap<String, String> name,
    required String generationHash,
    required String resourceSnapshotHash,
  }) async {
    final result = await checkoutService.createCheckout(
      channel: channel,
      serverId: serverId,
      name: name,
      generationHash: generationHash,
      resourceSnapshotHash: resourceSnapshotHash,
    );
    if (result.isNone()) return const None();

    final checkoutId = result.toNullable()!;

    // Trigger resource fetch
    await checkoutService.fetchResourcesForCheckout(
      checkoutId: checkoutId,
      channel: channel,
      channelName: channelName,
    );

    return result;
  }

  /// Switches the active checkout.
  Future<void> switchActiveCheckout(String checkoutId) =>
      checkoutRegistry.setActiveCheckout(checkoutId);

  /// Deletes a checkout.
  Future<void> deleteCheckout(String checkoutId) => checkoutService.deleteCheckout(checkoutId);

  /// Returns the resource snapshot hash for the active checkout, or [None].
  Option<String> activeSnapshotHash() =>
      checkoutRegistry.activeCheckoutEntry().map((e) => e.resourceSnapshotHash);

  // ── Update detection ───────────────────────────────────────────────────────

  /// Checks for remote updates.
  ///
  /// Compares the local generation hash with the remote head.
  /// Returns Some(generationHash) if an update is available, or None.
  Future<Option<String>> checkForUpdates(String channelName) async {
    final hasUpdates = await channelService.hasUpdates(channelName);
    if (!hasUpdates) return const None();

    final headResult = await remoteCatalogService.fetchHeadMeta(channelName);
    if (headResult.isLeft()) return const None();
    return Some(headResult.getRight().toNullable()!.generationHash);
  }

  // ── Resource fetch ─────────────────────────────────────────────────────────

  /// Fetches the latest resource snapshot for the active checkout.
  ///
  /// Follows spec §13.2. Downloads only changed blobs.
  Future<Option<String>> fetchResourcesForActiveCheckout({
    required Channel channel,
    required String channelName,
  }) async {
    final checkoutId = checkoutRegistry.activeCheckoutId();
    if (checkoutId.isNone()) return const None();
    return checkoutService.fetchResourcesForCheckout(
      checkoutId: checkoutId.toNullable()!,
      channel: channel,
      channelName: channelName,
    );
  }

  // ── Revert ─────────────────────────────────────────────────────────────────

  /// Reverts the active checkout to a previous resource snapshot.
  Future<Option<String>> revertActiveCheckoutTo(String snapshotHash) async {
    final checkoutId = checkoutRegistry.activeCheckoutId();
    if (checkoutId.isNone()) return const None();
    return checkoutService.revertCheckoutTo(checkoutId.toNullable()!, snapshotHash);
  }

  // ── Verification & GC ──────────────────────────────────────────────────────

  /// Whether a verification or prune operation is currently in flight.
  ///
  /// UI code can watch this to disable actions instead of catching [StateError].
  bool get isVerificationRunning => verificationService.isRunning;

  /// Verifies all checkouts' integrity.
  ///
  /// Throws [StateError] if another storage operation is already in flight.
  IList<VerificationIssue> verify() => verificationService.verify();

  /// Verifies all checkouts' integrity in a background isolate.
  ///
  /// Throws [StateError] if another storage operation is already in flight.
  Future<IList<VerificationIssue>> verifyAsync({
    void Function(int current, int total)? onProgress,
  }) => verificationService.verifyAsync(onProgress: onProgress);

  /// Prunes unreferenced data.
  ///
  /// Throws [StateError] if another storage operation is already in flight.
  int prune() => verificationService.prune();

  /// Prunes unreferenced data in a background isolate.
  ///
  /// Throws [StateError] if another storage operation is already in flight.
  Future<int> pruneAsync({void Function(int current, int total)? onProgress}) =>
      verificationService.pruneAsync(onProgress: onProgress);

  /// Recovers from interrupted writes by deleting orphaned temp files and
  /// directories left behind by atomic-write patterns that crashed mid-rename.
  ///
  /// Best-effort and idempotent; intended to run once at startup before the
  /// registry is read.
  void recoverPartialDownloads() => assetStore.recoverSync();

  /// Verifies and repairs by re-downloading missing files.
  ///
  /// Throws [StateError] if another storage operation is already in flight.
  Future<IList<VerificationIssue>> verifyAndRepair({
    required Channel channel,
    void Function(int current, int total)? onProgress,
  }) => verificationService.repairAll(channel: channel, onProgress: onProgress);

  /// Wipes all downloaded storage: the content-addressed asset store (blobs and
  /// resource snapshots), channel metadata, and the checkout registry.
  ///
  /// The `schema_version.json` marker is intentionally preserved so the active
  /// storage system is unchanged. After this completes the repo is in a
  /// no-setup state; callers must re-initialize the repo lifecycle.
  Future<Either<String, Unit>> clearAllStorage() async {
    final failures = <String>[];
    for (final path in [RepoPaths.assetsPath, RepoPaths.channelsPath, RepoPaths.checkoutsPath]) {
      final dir = Directory(path);
      try {
        // ignore: avoid_slow_async_io
        if (await dir.exists()) await dir.delete(recursive: true);
      } on FileSystemException {
        failures.add(p.basename(path));
      }
    }
    if (failures.isNotEmpty) {
      return Left("Failed to delete: ${failures.join(", ")}");
    }
    // Clear the shared HTTP cache so that the next sync re-fetches metadata
    // instead of relying on ETags that referenced now-deleted assets.
    try {
      await RemoteCache.clear();
    } catch (e) {
      return Left("Failed to clear HTTP cache: $e");
    }
    return const Right(unit);
  }

  // ── Server catalog ─────────────────────────────────────────────────────────

  /// Returns the list of servers for [channelName] from the local cache.
  IList<ServerMeta> listServers(String channelName) => channelService.listServers(channelName);

  /// Reads the local channel registry.
  Option<ChannelRegistry> localChannelRegistry() => channelService.readLocalChannelRegistry();
}
