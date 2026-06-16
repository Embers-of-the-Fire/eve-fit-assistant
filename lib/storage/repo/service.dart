import "package:eve_fit_assistant/data/proto/announcement_index.pb.dart";
import "package:eve_fit_assistant/data/proto/generation_pointer.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/channel_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_registry_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_service.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_registry.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/models/server_meta.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/verification.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";

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
  Future<Either<String, Unit>> syncChannelGeneration(String channelName) =>
      channelService.syncChannelGeneration(channelName);

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

  // ── Announcements ──────────────────────────────────────────────────────────

  /// Fetches the announcement snapshot for [generationHash].
  ///
  /// Returns [None] if not available or fetch fails.
  Future<Option<AnnouncementIndex>> fetchAnnouncements({
    required Channel channel,
    required String generationHash,
  }) async {
    final pointerBytes = await remoteCatalogService.fetchAnnouncementPointer(generationHash);
    if (pointerBytes.isLeft()) return const None();
    final pointer = GenerationPointer.fromBuffer(pointerBytes.getRight().toNullable()!);
    final snapshotHash = pointer.snapshotHash;
    if (snapshotHash.isEmpty) return const None();

    final indexBytes = await remoteCatalogService.fetchAnnouncementIndex(snapshotHash);
    if (indexBytes.isLeft()) return const None();
    return Some(AnnouncementIndex.fromBuffer(indexBytes.getRight().toNullable()!));
  }

  // ── Verification & GC ──────────────────────────────────────────────────────

  /// Verifies all checkouts' integrity.
  IList<VerificationIssue> verify() => verificationService.verify();

  /// Prunes unreferenced data.
  int prune() => verificationService.prune();

  /// Verifies and repairs by re-downloading missing files.
  Future<IList<VerificationIssue>> verifyAndRepair({required Channel channel}) =>
      verificationService.repairAll(channel: channel);

  // ── Server catalog ─────────────────────────────────────────────────────────

  /// Returns the list of servers for [channelName] from the local cache.
  IList<ServerMeta> listServers(String channelName) => channelService.listServers(channelName);

  /// Reads the local channel registry.
  Option<ChannelRegistry> localChannelRegistry() => channelService.readLocalChannelRegistry();
}
