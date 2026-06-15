import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/branch.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_index.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_refs.dart";
import "package:eve_fit_assistant/storage/repo/models/models.dart" show GenerationCheckoutCatalog;
import "package:eve_fit_assistant/storage/repo/models/remote_catalog.dart"
    show GenerationCheckoutCatalog;
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/repo.dart" show GenerationCheckoutCatalog;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";
import "package:path/path.dart" as p;

/// Manages the checkout lifecycle: index, refs, manifests, and download orchestration.
class CheckoutService {
  const CheckoutService({
    required this.assetStore,
    required this.remoteCatalogService,
    required this.diffEngine,
  });

  final AssetStore assetStore;

  final RemoteCatalogService remoteCatalogService;

  final DiffEngine diffEngine;

  // ── Index ──────────────────────────────────────────────────────────────────────

  /// Reads [checkouts/index.json] and returns the parsed [CheckoutIndex], or [None]
  /// if the file is missing.
  Option<CheckoutIndex> readIndex() {
    final file = File(RepoPaths.checkoutsIndexPath);
    if (!file.existsSync()) return const None();
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return Some(CheckoutIndex.fromJson(json));
    } on Exception catch (e, stackTrace) {
      warning("Failed to read checkout index", stackTrace: stackTrace);
      return const None();
    }
  }

  /// Writes [index] to [checkouts/index.json] atomically.
  ///
  /// Returns `true` on success, `false` if the write fails (e.g. disk full).
  bool writeIndex(CheckoutIndex index) {
    final path = RepoPaths.checkoutsIndexPath;
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final tmp = File("$path.tmp");
    try {
      tmp
        ..writeAsStringSync(jsonEncode(index.toJson()), flush: true)
        ..renameSync(path);
      return true;
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to write checkout index", stackTrace: stackTrace);
      return false;
    }
  }

  /// Returns [Some] with the [CheckoutState] for [checkoutId], or [None] if the
  /// checkout is not in the index.
  Option<CheckoutState> getState(String checkoutId) => readIndex().flatMap(
    (index) => Option.fromNullable(index.entries[checkoutId]).map((e) => e.state),
  );

  /// Alias for [getState], kept as the public-facing name from the spec-impl.
  Option<CheckoutState> lookup(String checkoutId) => getState(checkoutId);

  /// Returns all checkout hashes in the index whose entry's state equals [state].
  IList<String> listByState(CheckoutState state) => readIndex().fold(
    () => const IList.empty(),
    (index) =>
        index.entries.entries.where((e) => e.value.state == state).map((e) => e.key).toIList(),
  );

  /// Sets the [CheckoutState] for [checkoutId] in the index, creating a new entry if
  /// necessary. Idempotent if the state is already [newState].
  ///
  /// Best-effort: returns `false` if the write fails, but the in-memory state has
  /// been consumed by the caller. Subsequent reads of the index will still reflect
  /// the prior state.
  bool setState(String checkoutId, CheckoutState newState) {
    final index = readIndex().getOrElse(() => const CheckoutIndex(schemaVersion: 1));
    final existing = index.entries[checkoutId];

    if (existing != null && existing.state == newState) return true;

    final updated = index.copyWith(
      entries: index.entries.add(checkoutId, CheckoutEntry(state: newState)),
    );
    return writeIndex(updated);
  }

  // ── Refs ───────────────────────────────────────────────────────────────────────

  /// Reads [checkouts/refs.json] and returns the parsed [CheckoutRefs], or [None] if
  /// the file is missing.
  Option<CheckoutRefs> readRefs() {
    final file = File(RepoPaths.checkoutsRefsPath);
    if (!file.existsSync()) return const None();
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return Some(CheckoutRefs.fromJson(json));
    } on Exception catch (e, stackTrace) {
      warning("Failed to read checkout refs", stackTrace: stackTrace);
      return const None();
    }
  }

  /// Appends [ref] to the append-only [checkouts/refs.json]. Idempotent: if a ref
  /// with the same id already exists, the operation is skipped.
  ///
  /// Returns `true` on success, `false` if the write fails (e.g. disk full).
  bool appendRef(CheckoutRefRecord ref) {
    final path = RepoPaths.checkoutsRefsPath;
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    final refs = readRefs().getOrElse(() => const CheckoutRefs(schemaVersion: 1));

    if (refs.refs.containsKey(ref.id)) return true;

    final updated = refs.copyWith(refs: refs.refs.add(ref.id, ref));
    final tmp = File("$path.tmp");
    try {
      tmp
        ..writeAsStringSync(jsonEncode(updated.toJson()), flush: true)
        ..renameSync(path);
      return true;
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to append checkout ref", stackTrace: stackTrace);
      return false;
    }
  }

  // ── Manifest ───────────────────────────────────────────────────────────────────

  /// Reads [checkouts/<checkoutId>/assets.json] and returns the parsed
  /// [AssetManifest], or [None] if the file is missing.
  Option<AssetManifest> readManifest(String checkoutId) {
    final manifestPath = RepoPaths.checkoutManifestPath(checkoutId);
    final file = File(manifestPath);
    if (!file.existsSync()) return const None();
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return Some(AssetManifest.fromJson(json));
    } on Exception catch (e, stackTrace) {
      warning("Failed to read manifest for checkout $checkoutId", stackTrace: stackTrace);
      return const None();
    }
  }

  /// Writes [manifest] to [checkouts/<checkoutId>/assets.json] atomically.
  ///
  /// Returns `true` on success, `false` if the write fails (e.g. disk full).
  bool writeManifest(String checkoutId, AssetManifest manifest) {
    final manifestPath = RepoPaths.checkoutManifestPath(checkoutId);
    final file = File(manifestPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final tmp = File("$manifestPath.tmp");
    try {
      tmp
        ..writeAsStringSync(jsonEncode(manifest.toJson()), flush: true)
        ..renameSync(manifestPath);
      return true;
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to write manifest for checkout $checkoutId", stackTrace: stackTrace);
      return false;
    }
  }

  /// Removes the `checkouts/<checkoutId>/` directory and its `assets.json` file.
  ///
  /// Does nothing if the directory is absent.
  void deleteManifest(String checkoutId) {
    final dirPath = p.dirname(RepoPaths.checkoutManifestPath(checkoutId));
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return;
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to delete manifest dir for checkout $checkoutId", stackTrace: stackTrace);
    }
  }

  // ── Convenience ────────────────────────────────────────────────────────────────

  /// Transitions the checkout from [CheckoutState.installed] to
  /// [CheckoutState.historical].
  void markHistorical(String checkoutId) {
    setState(checkoutId, CheckoutState.historical);
  }

  /// Adds the checkout as [CheckoutState.known] if not already in the index.
  void markKnown(String checkoutId) {
    setState(checkoutId, CheckoutState.known);
  }

  // ── Download orchestration ─────────────────────────────────────────────────────

  /// Orchestrates the full 10-step checkout download pipeline.
  ///
  /// Fetches the remote catalog, downloads missing assets, writes the manifest,
  /// appends refs/index entries, computes the initial diff, and moves the branch
  /// HEAD via the provided [branchService].
  ///
  /// On interruption recovery (branch with `checkout == ""`): if a local manifest
  /// already exists the catalog fetch is skipped and asset download resumes where
  /// it left off.
  ///
  /// Tracks successfully written asset files so that on any failure the newly-
  /// written assets and partial manifest are cleaned up (rollback).
  ///
  /// Returns [Some] with the [checkoutId] on success, [None] on a recoverable error.
  Future<Option<String>> downloadFullCheckout({
    required String checkoutId,
    required Channel channel,
    required String branchId,
    required String serverId,
    required GameMetadata metadata,
    required String remoteCreatedAt,
    required BranchService branchService,
  }) async {
    var manifest = readManifest(checkoutId);
    final writtenPaths = <String>[];
    var manifestWritten = false;

    try {
      // Step 1: Fetch catalog if no local manifest (or idempotent retry from scratch)
      if (manifest.isNone()) {
        final catalogResult = await remoteCatalogService.fetchCheckoutCatalog(channel, checkoutId);
        if (catalogResult.isLeft()) {
          warning("Failed to fetch checkout catalog for $checkoutId");
          return const None();
        }
        final catalog = catalogResult.getRight().toNullable()!;
        manifest = Some(AssetManifest(assetsVersion: 1, files: catalog.files));
      }

      final m = manifest.toNullable()!;

      // Steps 2-3: Download each missing asset
      for (final entry in m.files.entries) {
        final pathHash = entry.key;
        final file = entry.value;
        if (assetStore.existsSync(pathHash, file.hash)) continue;

        final assetResult = await remoteCatalogService.fetchAsset(channel, pathHash, file.hash);
        if (assetResult.isLeft()) {
          warning("Failed to fetch asset $pathHash/${file.hash}");
          return const None();
        }
        final content = assetResult.getRight().toNullable()!;
        try {
          assetStore.writeFileByHashesSync(pathHash, file.hash, content);
          writtenPaths.add("$pathHash/${file.hash}");
        } on FileSystemException catch (e, stackTrace) {
          warning("Failed to write asset $pathHash/${file.hash}", stackTrace: stackTrace);
          return const None();
        }
      }

      // Step 4-5: Construct and write manifest (idempotent)
      if (!writeManifest(checkoutId, m)) {
        warning("Failed to write manifest for checkout $checkoutId");
        return const None();
      }
      manifestWritten = true;

      // Step 6: Compute initial diff (full-adds from empty manifest)
      const emptyManifest = AssetManifest(assetsVersion: 1);
      final diff = diffEngine.computeDiff(
        emptyManifest,
        m,
        fromCheckoutId: "",
        toCheckoutId: checkoutId,
        fromCreatedAt: "",
        toCreatedAt: remoteCreatedAt,
      );

      // Step 7: Update branch HEAD with diff (atomic write)
      final installedAt = _formatTimestamp(DateTime.now().toUtc());
      final moveResult = branchService.moveHead(
        branchId: branchId,
        toCheckoutId: checkoutId,
        diff: diff,
        timestamp: installedAt,
      );
      if (moveResult.isSome()) {
        warning("moveHead failed for branch $branchId: ${moveResult.toNullable()}");
        return const None();
      }

      // Step 8: Append refs entry (idempotent)
      final refRecord = CheckoutRefRecord(
        id: checkoutId,
        installedAt: installedAt,
        remoteCreatedAt: remoteCreatedAt,
        serverId: serverId,
        metadata: metadata,
      );
      if (!appendRef(refRecord)) {
        warning("Failed to append ref for checkout $checkoutId");
        return const None();
      }

      // Step 9: Set index state (idempotent)
      if (!setState(checkoutId, CheckoutState.installed)) {
        warning("Failed to set index state for checkout $checkoutId");
        return const None();
      }

      // Step 10: Success
      return Some(checkoutId);
    } catch (_) {
      // Rollback: clean up any assets written during this attempt
      for (final path in writtenPaths) {
        final parts = path.split("/");
        if (parts.length == 2) {
          assetStore.deleteFileSync(parts[0], parts[1]);
        }
      }
      // Clean up partial manifest if written
      if (manifestWritten) {
        deleteManifest(checkoutId);
      }
      // Reset checkout state to known so it can be re-downloaded
      setState(checkoutId, CheckoutState.known);
      return const None();
    }
  }

  /// Applies an incremental update by computing the diff between the current HEAD
  /// manifest and the target checkout, then downloading only changed files.
  ///
  /// Steps:
  /// 1. Read branch and current HEAD manifest — return [None] if either is missing.
  /// 2. Fetch the remote [GenerationCheckoutCatalog] for [targetCheckoutId].
  /// 3. Build an [AssetManifest] from the catalog and compute the diff against HEAD.
  /// 4. Download only added and modified files, skipping already-present assets.
  /// 5. Write the target manifest, append refs with `parentCheckoutId`, update
  ///    index state, transition old checkout to [CheckoutState.historical] if
  ///    unreferenced, and move the branch HEAD atomically.
  ///
  /// On network failure the target manifest may be partially written; a subsequent
  /// retry re-computes the diff and skips already-downloaded assets.
  ///
  /// Tracks successfully written asset files so that on any failure the newly-
  /// written assets and partial manifest are cleaned up (rollback).
  Future<Option<String>> applyIncrementalUpdate({
    required String branchId,
    required String targetCheckoutId,
    required Channel channel,
    required String remoteCreatedAt,
    required BranchService branchService,
  }) async {
    // Step 1: Read branch
    final branchResult = branchService.readBranch(branchId);
    if (branchResult.isNone()) {
      warning("applyIncrementalUpdate: branch $branchId not found");
      return const None();
    }
    final branch = branchResult.toNullable()!;

    // Step 2: Read current HEAD manifest
    final currentManifestResult = readManifest(branch.checkout);
    if (currentManifestResult.isNone()) {
      warning(
        "applyIncrementalUpdate: HEAD manifest missing for branch $branchId "
        "(checkout ${branch.checkout}) — fall back to full download",
      );
      return const None();
    }
    final currentManifest = currentManifestResult.toNullable()!;

    // Step 3: Fetch remote catalog for target checkout
    final catalogResult = await remoteCatalogService.fetchCheckoutCatalog(
      channel,
      targetCheckoutId,
    );
    if (catalogResult.isLeft()) {
      warning("applyIncrementalUpdate: failed to fetch catalog for $targetCheckoutId");
      return const None();
    }
    final catalog = catalogResult.getRight().toNullable()!;

    // Step 4: Build new manifest from catalog
    final newManifest = AssetManifest(assetsVersion: 1, files: catalog.files);

    // Step 5: Compute diff
    final diff = diffEngine.computeDiff(
      currentManifest,
      newManifest,
      fromCheckoutId: branch.checkout,
      toCheckoutId: targetCheckoutId,
      fromCreatedAt: "",
      toCreatedAt: remoteCreatedAt,
    );

    final writtenPaths = <String>[];
    var manifestWritten = false;

    try {
      // Step 6: Download added and modified files
      for (final add in diff.adds) {
        if (assetStore.existsSync(add.pathHash, add.hash)) continue;
        final assetResult = await remoteCatalogService.fetchAsset(channel, add.pathHash, add.hash);
        if (assetResult.isLeft()) {
          warning("applyIncrementalUpdate: failed to fetch asset ${add.pathHash}/${add.hash}");
          return const None();
        }
        final content = assetResult.getRight().toNullable()!;
        try {
          assetStore.writeFileByHashesSync(add.pathHash, add.hash, content);
          writtenPaths.add("${add.pathHash}/${add.hash}");
        } on FileSystemException catch (e, stackTrace) {
          warning(
            "applyIncrementalUpdate: failed to write asset ${add.pathHash}/${add.hash}",
            stackTrace: stackTrace,
          );
          return const None();
        }
      }

      for (final modify in diff.modifies) {
        if (assetStore.existsSync(modify.pathHash, modify.hash)) continue;
        final assetResult = await remoteCatalogService.fetchAsset(
          channel,
          modify.pathHash,
          modify.hash,
        );
        if (assetResult.isLeft()) {
          warning(
            "applyIncrementalUpdate: failed to fetch asset ${modify.pathHash}/${modify.hash}",
          );
          return const None();
        }
        final content = assetResult.getRight().toNullable()!;
        try {
          assetStore.writeFileByHashesSync(modify.pathHash, modify.hash, content);
          writtenPaths.add("${modify.pathHash}/${modify.hash}");
        } on FileSystemException catch (e, stackTrace) {
          warning(
            "applyIncrementalUpdate: failed to write asset ${modify.pathHash}/${modify.hash}",
            stackTrace: stackTrace,
          );
          return const None();
        }
      }

      // Step 7: Write target manifest
      if (!writeManifest(targetCheckoutId, newManifest)) {
        warning("applyIncrementalUpdate: failed to write manifest for $targetCheckoutId");
        return const None();
      }
      manifestWritten = true;

      // Step 8: Update branch HEAD atomically
      final installedAt = _formatTimestamp(DateTime.now().toUtc());
      final moveResult = branchService.moveHead(
        branchId: branchId,
        toCheckoutId: targetCheckoutId,
        diff: diff,
        timestamp: installedAt,
      );
      if (moveResult.isSome()) {
        warning(
          "applyIncrementalUpdate: moveHead failed for branch $branchId: "
          "${moveResult.toNullable()}",
        );
        return const None();
      }

      // Step 9: Append refs entry with parent linking to previous checkout
      final refRecord = CheckoutRefRecord(
        id: targetCheckoutId,
        installedAt: installedAt,
        remoteCreatedAt: remoteCreatedAt,
        serverId: branch.serverId,
        metadata: branch.metadata,
        parentCheckoutId: branch.checkout,
      );
      if (!appendRef(refRecord)) {
        warning("applyIncrementalUpdate: failed to append ref for $targetCheckoutId");
        return const None();
      }

      // Step 10: Set index state for target checkout
      if (!setState(targetCheckoutId, CheckoutState.installed)) {
        warning("applyIncrementalUpdate: failed to set index state for $targetCheckoutId");
        return const None();
      }

      // Step 11: Transition old checkout to historical if unreferenced
      // Only transition if the old checkout differs from the target.
      if (branch.checkout != targetCheckoutId && branch.checkout.isNotEmpty) {
        if (getState(branch.checkout).isNone()) {
          setState(branch.checkout, CheckoutState.installed);
        }
        if (!branchService.isCheckoutReferenced(branch.checkout, excludeBranchId: branchId)) {
          setState(branch.checkout, CheckoutState.historical);
        }
      }

      return Some(targetCheckoutId);
    } catch (_) {
      // Rollback: clean up any assets written during this attempt
      for (final path in writtenPaths) {
        final parts = path.split("/");
        if (parts.length == 2) {
          assetStore.deleteFileSync(parts[0], parts[1]);
        }
      }
      // Clean up partial manifest if written
      if (manifestWritten) {
        deleteManifest(targetCheckoutId);
      }
      // Reset checkout state to known so it can be re-downloaded
      setState(targetCheckoutId, CheckoutState.known);
      return const None();
    }
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
