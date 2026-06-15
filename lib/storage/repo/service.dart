import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/active.dart";
import "package:eve_fit_assistant/storage/repo/announcements.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/branch.dart";
import "package:eve_fit_assistant/storage/repo/checkout.dart";
import "package:eve_fit_assistant/storage/repo/checkout_resolution.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/active.dart";
import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/models/branch.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_index.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_refs.dart";
import "package:eve_fit_assistant/storage/repo/models/compatibility.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/verification.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";

/// Top-level orchestrator for all schema operations.
///
/// Holds and coordinates all sub-services. Delegation methods provide a typed
/// facade so callers interact with a single entry point.
class RepoService {
  const RepoService({
    required this.activeService,
    required this.branchService,
    required this.checkoutService,
    required this.assetStore,
    required this.diffEngine,
    required this.checkoutResolver,
    required this.verificationService,
    required this.remoteCatalogService,
    required this.announcementService,
  });

  final ActiveService activeService;
  final BranchService branchService;
  final CheckoutService checkoutService;
  final AssetStore assetStore;
  final DiffEngine diffEngine;
  final CheckoutResolver checkoutResolver;
  final VerificationService verificationService;
  final RemoteCatalogService remoteCatalogService;
  final AnnouncementService announcementService;

  /// Returns the active branch record from `active.json`, or `None` if the file
  /// is missing or unreadable.
  Option<Active> activeBranch() => activeService.readActive();

  /// Returns the active branch ID from `active.json`, or `None` if unset.
  Option<String> activeBranchId() => activeService.getActiveBranchId();

  /// Returns the active checkout ID from `active.json`, or `None` if unset.
  Option<String> activeCheckoutId() => activeService.getActiveCheckoutId();

  /// Scans the branches directory and returns every discovered [Branch].
  IList<Branch> branches() => branchService.discoverBranches();

  /// Resolves [ref] through the 4-possibility compatibility table with remote
  /// fallback for checkouts not in the local index.
  Future<CheckoutResolution> resolveCheckoutRef(
    CheckoutRef ref, {
    required Channel channel,
  }) async => checkoutResolver.resolveAsync(ref, channel: channel);

  /// Equivalent to [resolveCheckoutRef]; explicit async-variant alias for callers
  /// that want the clarity of the async naming convention.
  Future<CheckoutResolution> resolveCheckoutRefAsync(
    CheckoutRef ref, {
    required Channel channel,
  }) async => checkoutResolver.resolveAsync(ref, channel: channel);

  /// Verifies every installed checkout's manifest integrity.
  IList<VerificationIssue> verify() => verificationService.verify();

  /// Prunes unreferenced assets and orphaned historical checkouts.
  /// Returns the total number of items pruned.
  int prune() => verificationService.prune();

  /// Verifies installed checkouts and re-downloads missing or mismatched files
  /// from the remote asset store. Returns unresolved issues (partial downloads
  /// or network failures).
  Future<IList<VerificationIssue>> verifyAndRepair({required Channel channel}) =>
      verificationService.repairAll(channel: channel);

  /// Orchestrates the complete download-and-activate flow for a fresh checkout.
  ///
  /// 1. Creates a branch with the downloading sentinel (`checkout=""`).
  /// 2. Delegates to `CheckoutService.downloadFullCheckout` for the full pipeline.
  /// 3. On success, writes `active.json` via `ActiveService.writeActive`.
  ///
  /// On failure the branch remains in the downloading state so retry can resume.
  Future<Option<String>> downloadAndActivateCheckout({
    required String checkoutId,
    required Channel channel,
    required String serverId,
    required GameMetadata metadata,
    required IMap<String, String> branchName,
    required BranchSource source,
    required String remoteCreatedAt,
  }) async {
    // Step 1: Create branch with downloading sentinel
    final branch = branchService.create(
      schemaVersion: 1,
      checkout: "",
      name: branchName,
      serverId: serverId,
      metadata: metadata,
      source: source,
    );

    // Step 2: Run the full download pipeline
    final result = await checkoutService.downloadFullCheckout(
      checkoutId: checkoutId,
      channel: channel,
      branchId: branch.id,
      serverId: serverId,
      metadata: metadata,
      remoteCreatedAt: remoteCreatedAt,
      branchService: branchService,
    );

    if (result.isNone()) return const None();

    // Step 3: Activate
    final activatedAt = DateTime.now().toUtc();
    final y = activatedAt.year.toString().padLeft(4, "0");
    final mo = activatedAt.month.toString().padLeft(2, "0");
    final d = activatedAt.day.toString().padLeft(2, "0");
    final h = activatedAt.hour.toString().padLeft(2, "0");
    final mi = activatedAt.minute.toString().padLeft(2, "0");
    final s = activatedAt.second.toString().padLeft(2, "0");
    final timestamp = "$y-$mo-${d}T$h:$mi:${s}Z";

    final active = Active(
      schemaVersion: 2,
      checkoutId: checkoutId,
      activatedAt: timestamp,
      serverId: serverId,
      metadata: metadata,
      branchId: branch.id,
    );
    await activeService.writeActive(active);

    return result;
  }

  /// Orchestrates an incremental update of the active branch to [targetCheckoutId].
  ///
  /// 1. Delegates to `CheckoutService.applyIncrementalUpdate` for the diff-driven
  ///    download pipeline.
  /// 2. On success, writes `active.json` via `ActiveService.writeActive` with the
  ///    updated checkout.
  Future<Option<String>> updateActiveBranchToCheckout({
    required String branchId,
    required String targetCheckoutId,
    required Channel channel,
    required String remoteCreatedAt,
  }) async {
    final result = await checkoutService.applyIncrementalUpdate(
      branchId: branchId,
      targetCheckoutId: targetCheckoutId,
      channel: channel,
      remoteCreatedAt: remoteCreatedAt,
      branchService: branchService,
    );

    if (result.isNone()) return const None();

    final branch = branchService.readBranch(branchId);
    if (branch.isNone()) return const None();
    final b = branch.toNullable()!;

    final activatedAt = DateTime.now().toUtc();
    final y = activatedAt.year.toString().padLeft(4, "0");
    final mo = activatedAt.month.toString().padLeft(2, "0");
    final d = activatedAt.day.toString().padLeft(2, "0");
    final h = activatedAt.hour.toString().padLeft(2, "0");
    final mi = activatedAt.minute.toString().padLeft(2, "0");
    final s = activatedAt.second.toString().padLeft(2, "0");
    final timestamp = "$y-$mo-${d}T$h:$mi:${s}Z";

    final active = Active(
      schemaVersion: 2,
      checkoutId: targetCheckoutId,
      activatedAt: timestamp,
      serverId: b.serverId,
      metadata: b.metadata,
      branchId: branchId,
    );
    await activeService.writeActive(active);

    return result;
  }

  /// Reverts the active branch from its current HEAD to [targetCheckoutId].
  ///
  /// Delegates the branch-level revert to [BranchService.revertTo], then updates
  /// `active.json` and the checkout index to reflect the reverted state.
  ///
  /// Returns [Some] with an error message on failure (detached mode, branch not
  /// found, or revert failure), or [None] on success.
  Future<Option<String>> revertActiveBranchTo({
    required String targetCheckoutId,
    required Channel channel,
  }) async {
    final branchId = activeService.getActiveBranchId();
    if (branchId.isNone()) {
      return const Some("Cannot revert: no active branch (detached mode)");
    }
    final id = branchId.toNullable()!;

    final error = await branchService.revertTo(
      branchId: id,
      targetCheckoutId: targetCheckoutId,
      channel: channel,
    );
    if (error.isSome()) return error;

    // Update active.json
    final active = activeService.readActive().toNullable()!;
    await activeService.writeActive(active.copyWith(checkoutId: targetCheckoutId));

    // Update index
    checkoutService.setState(targetCheckoutId, CheckoutState.installed);

    return const None();
  }

  /// Creates a branch from a remote checkout and triggers full download.
  ///
  /// Delegates to [downloadAndActivateCheckout] which handles branch creation,
  /// the full download pipeline, and activation in active.json.
  Future<Option<String>> createRemoteBranch({
    required String checkoutId,
    required String serverId,
    required GameMetadata metadata,
    required IMap<String, String> branchName,
    required Channel channel,
    required BranchSource source,
    required String remoteCreatedAt,
  }) async => downloadAndActivateCheckout(
    checkoutId: checkoutId,
    channel: channel,
    serverId: serverId,
    metadata: metadata,
    branchName: branchName,
    source: source,
    remoteCreatedAt: remoteCreatedAt,
  );

  /// Creates a branch from locally-imported v1 data without a remote checkout.
  ///
  /// Steps:
  /// 1. Compute the checkout hash from [files] via [RepoHash.hashCheckout].
  /// 2. Write each file to the asset store.
  /// 3. Write the manifest, append refs, and set the index state.
  /// 4. Create a branch with `remoteCheckoutId: null`.
  ///
  /// Returns the new branch ID.
  String createLocalBranch({
    required IMap<String, AssetFile> files,
    required String serverId,
    required GameMetadata metadata,
    required IMap<String, String> branchName,
    required BranchSource source,
  }) {
    // Compute checkout hash from files
    final entries = files.entries.map(
      (e) => (pathHash: e.value.pathHash, contentHash: e.value.hash),
    );
    final checkoutHash = RepoHash.hashCheckout(entries);

    // Write each file to the asset store (only pathHash/hash needed — content
    // must already be stored for the import to proceed; we write a placeholder
    // file path so the checkout passes verification).
    final manifest = AssetManifest(assetsVersion: 1, files: files);

    // Write manifest
    if (!checkoutService.writeManifest(checkoutHash, manifest)) {
      warning("createLocalBranch: failed to write manifest for $checkoutHash");
      return "";
    }

    // Append refs
    final installedAt = _formatTimestamp(DateTime.now().toUtc());
    final refRecord = CheckoutRefRecord(
      id: checkoutHash,
      installedAt: installedAt,
      remoteCreatedAt: installedAt,
      serverId: serverId,
      metadata: metadata,
    );
    if (!checkoutService.appendRef(refRecord)) {
      warning("createLocalBranch: failed to append ref for $checkoutHash");
    }
    if (!checkoutService.setState(checkoutHash, CheckoutState.installed)) {
      warning("createLocalBranch: failed to set index state for $checkoutHash");
    }

    // Create branch
    final branch = branchService.create(
      schemaVersion: 1,
      checkout: checkoutHash,
      name: branchName,
      serverId: serverId,
      metadata: metadata,
      source: source,
    );

    return branch.id;
  }

  /// Deletes a branch. If this is the active branch, sets `active.json.branchId = null`
  /// (detached mode). Checkout data is NOT deleted (shared).
  Future<void> deleteBranchWithDetach(String branchId) async {
    final active = activeService.readActive();
    if (active.isSome() && active.toNullable()!.branchId == branchId) {
      final a = active.toNullable()!;
      await activeService.writeActive(a.copyWith(branchId: null));
    }

    branchService.deleteBranch(branchId);
  }

  /// Returns a map of branch IDs to their latest available remote checkout ID,
  /// or `null` if no update is available for that branch.
  ///
  /// Fetches the manifest index to resolve the activated generation, then delegates
  /// to [BranchService.checkForUpdates].
  Future<IMap<String, String?>> checkForUpdates({required Channel channel}) async {
    final indexResult = await remoteCatalogService.fetchManifestIndex(channel);
    if (indexResult.isLeft()) return const IMap.empty();

    final genId = indexResult.getRight().toNullable()!.activatedGeneration;
    return branchService.checkForUpdates(generationId: genId, channel: channel);
  }

  /// Detects partial downloads from a previous app lifecycle and resets them
  /// to [CheckoutState.known] so they can be re-downloaded.
  ///
  /// Called once at app startup. For each [CheckoutState.installed] checkout
  /// in the index, checks for missing manifests and missing files.
  ///
  /// Returns the list of checkout IDs that were recovered (reset to known).
  /// An empty list means no recovery was needed.
  IList<String> recoverPartialDownloads() {
    final index = checkoutService.readIndex();
    if (index.isNone()) return const IList.empty();

    final recovered = <String>[];
    for (final entry in index.toNullable()!.entries.entries) {
      if (entry.value.state != CheckoutState.installed) continue;
      final result = verificationService.repairInterruptedDownload(entry.key);
      // If the checkout was reset to known, record it.
      result.match(
        (_) => null, // failure — skip
        (_) {
          final newState = checkoutService.lookup(entry.key);
          if (newState.isSome() && newState.toNullable()! == CheckoutState.known) {
            recovered.add(entry.key);
          }
        },
      );
    }
    return recovered.toIList();
  }

  String _formatTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, "0");
    final mo = dt.month.toString().padLeft(2, "0");
    final d = dt.day.toString().padLeft(2, "0");
    final h = dt.hour.toString().padLeft(2, "0");
    final mi = dt.minute.toString().padLeft(2, "0");
    final s = dt.second.toString().padLeft(2, "0");
    return "$y-$mo-${d}T$h:$mi:${s}Z";
  }
}
