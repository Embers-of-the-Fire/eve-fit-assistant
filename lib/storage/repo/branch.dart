import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/checkout.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/models/branch.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_index.dart" show CheckoutState;
import "package:eve_fit_assistant/storage/repo/models/diff.dart";
import "package:eve_fit_assistant/storage/repo/models/models.dart" show CheckoutState;
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/repo.dart" show CheckoutState;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";
import "package:uuid/uuid.dart";

/// Debounces a [source] stream by [duration] — only the last event within the
/// window is forwarded.
Stream<T> _debounce<T>(Stream<T> source, Duration duration) {
  Timer? timer;
  StreamSubscription<T>? subscription;
  late final StreamController<T> controller;
  controller = StreamController<T>(
    onCancel: () {
      timer?.cancel();
      unawaited(subscription?.cancel());
    },
  );

  subscription = source.listen(
    (data) {
      timer?.cancel();
      timer = Timer(duration, () {
        if (!controller.isClosed) controller.add(data);
      });
    },
    onError: controller.addError,
    onDone: controller.close,
    cancelOnError: true,
  );

  return controller.stream;
}

/// Branch lifecycle management: CRUD, HEAD movement, reflog, diffs, and revert.
class BranchService {
  const BranchService({
    required this.checkoutService,
    required this.diffEngine,
    required this.assetStore,
    required this.remoteCatalogService,
  });

  final CheckoutService checkoutService;

  final DiffEngine diffEngine;

  final AssetStore assetStore;

  final RemoteCatalogService remoteCatalogService;

  // ── Discovery ──────────────────────────────────────────────────────────────────

  /// Scans the [branches/] directory and parses every `.json` file into a [Branch].
  IList<Branch> discoverBranches() {
    final dir = Directory(RepoPaths.branchesPath);
    if (!dir.existsSync()) return const IList<Branch>.empty();

    final branches = <Branch>[];
    for (final entity in dir.listSync().whereType<File>()) {
      if (!entity.path.endsWith(".json")) continue;
      try {
        final json = jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;
        branches.add(Branch.fromJson(json));
      } on Exception catch (e, stackTrace) {
        warning("Failed to parse branch file ${entity.path}", stackTrace: stackTrace);
      }
    }
    return branches.toIList();
  }

  /// Returns a stream that emits the current branch list whenever a branch file is
  /// created, deleted, or modified inside the [branches/] directory. The stream is
  /// debounced to avoid transient emissions during atomic writes.
  Stream<IList<Branch>> watchBranches() {
    final dir = Directory(RepoPaths.branchesPath);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final dirStream = dir.watch();

    return _debounce(
      dirStream,
      const Duration(milliseconds: 200),
    ).asyncMap((_) async => discoverBranches());
  }

  // ── Single-branch I/O ──────────────────────────────────────────────────────────

  /// Reads [branches/<id>.json] and returns [Some] with the parsed [Branch], or
  /// [None] if the file is missing.
  Option<Branch> readBranch(String id) {
    final path = RepoPaths.branchPath(id);
    final file = File(path);
    if (!file.existsSync()) return const None();
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return Some(Branch.fromJson(json));
    } on Exception catch (e, stackTrace) {
      warning("Failed to read branch $id", stackTrace: stackTrace);
      return const None();
    }
  }

  /// Creates a new branch by writing [branch] to disk atomically.
  ///
  /// Returns [None] on success, [Some] with an error message on failure.
  Option<String> createBranch(Branch branch) {
    final path = RepoPaths.branchPath(branch.id);
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final tmp = File("$path.tmp");
    try {
      tmp
        ..writeAsStringSync(jsonEncode(branch.toJson()), flush: true)
        ..renameSync(path);
      return const None();
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to create branch ${branch.id}", stackTrace: stackTrace);
      return Some("Failed to write branch file: ${e.message}");
    }
  }

  /// Convenience factory: generates a UUID, initialises the reflog, and delegates to
  /// [createBranch]. Returns the created [Branch] so the caller can obtain the
  /// generated UUID.
  Branch create({
    required int schemaVersion,
    required String checkout,
    required IMap<String, String> name,
    required String serverId,
    required GameMetadata metadata,
    required BranchSource source,
    bool pinned = false,
  }) {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();
    final timestamp = _formatTimestamp(now);
    final diffId = _generateDiffId(checkout, checkout, timestamp);
    final branch = Branch(
      schemaVersion: schemaVersion,
      id: id,
      checkout: checkout,
      serverId: serverId,
      metadata: metadata,
      source: source,
      name: name,
      pinned: pinned,
      reflog: IList([ReflogEntry(id: diffId, timestamp: timestamp, from: checkout, to: checkout)]),
    );
    final result = createBranch(branch);
    if (result.isSome()) {
      warning("Failed to persist branch ${branch.id}: ${result.toNullable()}");
    }
    return branch;
  }

  /// Returns `true` if the branch identified by [id] is in the downloading state
  /// (`checkout == ""`). Returns `false` if the branch does not exist.
  bool isDownloading(String id) {
    final result = readBranch(id);
    if (result.isNone()) return false;
    return result.toNullable()!.checkout.isEmpty;
  }

  /// Checks whether a branch file exists on disk.
  bool branchExists(String id) => File(RepoPaths.branchPath(id)).existsSync();

  /// Returns the channel string from the branch's source, or [None] if the branch is
  /// not found.
  Option<String> sourceChannel(String id) {
    final result = readBranch(id);
    if (result.isNone()) return const None();
    return Some(result.toNullable()!.source.channel);
  }

  // ── Update discovery ────────────────────────────────────────────────────────────

  /// Checks for remote updates by comparing each unpinned branch's HEAD
  /// `remoteCreatedAt` against the latest server catalog entry.
  ///
  /// Returns a map of `branchId` → latest checkout ID (or `null` if no update is
  /// available). Pinned branches are excluded and network errors are handled
  /// gracefully (branches with errors are omitted from the result).
  Future<IMap<String, String?>> checkForUpdates({
    required String generationId,
    required Channel channel,
  }) async {
    final branches = discoverBranches();
    if (branches.isEmpty) return const IMap.empty();

    final refs = checkoutService.readRefs();
    final results = <String, String?>{};

    for (final branch in branches) {
      if (branch.pinned) continue;

      final branchHead = branch.checkout;
      if (branchHead.isEmpty) continue;

      final refRecord = refs.flatMap((r) => Option.fromNullable(r.refs[branchHead]));
      if (refRecord.isNone()) continue;

      final remoteCreatedAt = refRecord.toNullable()!.remoteCreatedAt;

      final catalogResult = await remoteCatalogService.fetchServerCatalog(
        channel,
        generationId,
        branch.serverId,
      );
      if (catalogResult.isLeft()) continue;

      final server = catalogResult.getRight().toNullable()!;
      if (server.checkouts.isEmpty) continue;

      // Find the latest checkout entry (sorted by createdAt, descending)
      final sorted = server.checkouts.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final latest = sorted.first;

      if (latest.createdAt.compareTo(remoteCreatedAt) > 0) {
        results[branch.id] = latest.id;
      } else {
        results[branch.id] = null;
      }
    }

    return results.toIMap();
  }

  /// Updates the branch at the given path, writing atomically.
  ///
  /// Returns [None] on success, [Some] with an error message on failure.
  Option<String> _writeBranch(Branch branch) {
    final path = RepoPaths.branchPath(branch.id);
    final tmp = File("$path.tmp");
    try {
      tmp
        ..writeAsStringSync(jsonEncode(branch.toJson()), flush: true)
        ..renameSync(path);
      return const None();
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to write branch ${branch.id}", stackTrace: stackTrace);
      return Some("Failed to write branch file: ${e.message}");
    }
  }

  // ── HEAD movement ──────────────────────────────────────────────────────────────

  /// Moves the branch HEAD from its current checkout to [toCheckoutId], atomically
  /// storing the reflog entry and [diff] in a single file write.
  ///
  /// Validates that `diff.from` matches `branch.checkout` and `diff.to` matches
  /// `toCheckoutId`; returns `Some(message)` with a warning if either invariant fails,
  /// or `None` on success.
  Option<String> moveHead({
    required String branchId,
    required String toCheckoutId,
    required Diff diff,
    required String timestamp,
  }) {
    final result = readBranch(branchId);
    if (result.isNone()) {
      warning("Cannot move HEAD: branch $branchId not found");
      return const None();
    }
    final branch = result.toNullable()!;

    if (diff.from != branch.checkout) {
      final msg =
          "moveHead invariant failed: diff.from (${diff.from}) does not match "
          "current branch.checkout (${branch.checkout})";
      warning(msg);
      return Some(msg);
    }
    if (diff.to != toCheckoutId) {
      final msg =
          "moveHead invariant failed: diff.to (${diff.to}) does not match "
          "toCheckoutId ($toCheckoutId)";
      warning(msg);
      return Some(msg);
    }

    final diffId = _generateDiffId(diff.from, diff.to, timestamp);
    final updated = branch.copyWith(
      checkout: toCheckoutId,
      reflog: branch.reflog.add(
        ReflogEntry(id: diffId, timestamp: timestamp, from: diff.from, to: diff.to),
      ),
      diffs: branch.diffs.add(diffId, diff),
    );
    final writeResult = _writeBranch(updated);
    if (writeResult.isSome()) {
      warning("moveHead: ${writeResult.toNullable()}");
      return writeResult;
    }
    return const None();
  }

  /// Moves the branch HEAD from its current checkout to [newCheckoutId].
  ///
  /// Appends a reflog entry recording the transition.
  @Deprecated("Use moveHead() for atomic reflog+diff writes")
  void updateBranchHead(String branchId, String newCheckoutId) {
    final result = readBranch(branchId);
    if (result.isNone()) {
      warning("Cannot update HEAD: branch $branchId not found");
      return;
    }
    final branch = result.toNullable()!;

    final now = DateTime.now().toUtc();
    final timestamp = _formatTimestamp(now);
    final diffId = _generateDiffId(branch.checkout, newCheckoutId, timestamp);

    final updated = branch.copyWith(
      checkout: newCheckoutId,
      reflog: branch.reflog.add(
        ReflogEntry(id: diffId, timestamp: timestamp, from: branch.checkout, to: newCheckoutId),
      ),
    );
    final writeResult = _writeBranch(updated);
    if (writeResult.isSome()) {
      warning("updateBranchHead: ${writeResult.toNullable()}");
    }
  }

  /// Appends [diff] to the branch identified by [branchId].
  @Deprecated("Use moveHead() for atomic reflog+diff writes")
  void appendDiff(String branchId, Diff diff) {
    final result = readBranch(branchId);
    if (result.isNone()) {
      warning("Cannot append diff: branch $branchId not found");
      return;
    }
    final branch = result.toNullable()!;

    final diffId = _generateDiffId(diff.from, diff.to, diff.toCreatedAt);
    final updated = branch.copyWith(diffs: branch.diffs.add(diffId, diff));
    final writeResult = _writeBranch(updated);
    if (writeResult.isSome()) {
      warning("appendDiff: ${writeResult.toNullable()}");
    }
  }

  // ── Pin / Unpin ────────────────────────────────────────────────────────────────

  void pinBranch(String id) {
    _setPinned(id, true);
  }

  void unpinBranch(String id) {
    _setPinned(id, false);
  }

  void _setPinned(String id, bool pinned) {
    final result = readBranch(id);
    if (result.isNone()) {
      warning("Cannot ${pinned ? "pin" : "unpin"}: branch $id not found");
      return;
    }
    final writeResult = _writeBranch(result.toNullable()!.copyWith(pinned: pinned));
    if (writeResult.isSome()) {
      warning("_setPinned: ${writeResult.toNullable()}");
    }
  }

  // ── Rename ────────────────────────────────────────────────────────────────────

  void renameBranch(String id, IMap<String, String> name) {
    final result = readBranch(id);
    if (result.isNone()) {
      warning("Cannot rename: branch $id not found");
      return;
    }
    final writeResult = _writeBranch(result.toNullable()!.copyWith(name: name));
    if (writeResult.isSome()) {
      warning("renameBranch: ${writeResult.toNullable()}");
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────────

  void deleteBranch(String id) {
    final path = RepoPaths.branchPath(id);
    final file = File(path);
    if (!file.existsSync()) return;
    try {
      file.deleteSync();
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to delete branch $id", stackTrace: stackTrace);
    }
  }

  // ── Reference check ────────────────────────────────────────────────────────────

  /// Returns `true` if [checkoutId] is referenced by any branch's HEAD or reflog.
  ///
  /// When [excludeBranchId] is provided, that branch is skipped so callers can
  /// check if a checkout is referenced by *other* branches (e.g. before
  /// transitioning a checkout to historical).
  ///
  /// Used to determine whether a checkout can be safely transitioned to
  /// [CheckoutState.historical] (only when unreferenced) or must remain installed
  /// because another branch still points to it.
  bool isCheckoutReferenced(String checkoutId, {String? excludeBranchId}) {
    final branches = discoverBranches();
    for (final branch in branches) {
      if (excludeBranchId != null && branch.id == excludeBranchId) continue;
      if (branch.checkout == checkoutId) return true;
      for (final entry in branch.reflog) {
        if (entry.from == checkoutId || entry.to == checkoutId) return true;
      }
    }
    return false;
  }

  // ── Revert ─────────────────────────────────────────────────────────────────────

  /// Reverts the branch from its current HEAD to [targetCheckoutId] by walking the
  /// reflog backwards, inverting each diff, and applying the changes to the asset
  /// store. Appends a new reflog entry and precomputes a forward diff.
  ///
  /// This method does NOT update `active.json` or the checkout index — those are the
  /// caller's responsibility.
  ///
  /// Validates that [targetCheckoutId] exists in the reflog chain and returns
  /// [Some] with an error message on failure, or [None] on success.
  Future<Option<String>> revertTo({
    required String branchId,
    required String targetCheckoutId,
    required Channel channel,
  }) async {
    final result = readBranch(branchId);
    if (result.isNone()) return const Some("branch not found");
    final branch = result.toNullable()!;

    // Find target in reflog chain
    var targetIndex = -1;
    for (var i = 0; i < branch.reflog.length; i++) {
      if (branch.reflog[i].to == targetCheckoutId) {
        targetIndex = i;
        break;
      }
    }
    if (targetIndex < 0) {
      return const Some("target checkout not in reflog chain");
    }

    // Walk backwards from HEAD to (but not past) target, invert and apply diffs.
    // Destructive operations (deletes) are recorded in undoJournal so that a
    // partial revert can be rolled back on failure.
    final undoJournal = <_UndoEntry>[];
    var committed = false;

    try {
      for (var i = branch.reflog.length - 1; i > targetIndex; i--) {
        final entry = branch.reflog[i];
        final diff = branch.diffs[entry.id];
        if (diff == null) return Some("missing diff for reflog entry ${entry.id}");

        final fromManifestResult = checkoutService.readManifest(entry.from);
        if (fromManifestResult.isNone()) {
          return Some("missing manifest for ${entry.from}");
        }
        final inverted = diffEngine.invertDiff(diff, fromManifestResult.toNullable()!);

        final applyError = await _applyInvertedDiff(inverted, channel, undoJournal);
        if (applyError.isSome()) return applyError;
      }

      // Append new reflog entry
      final now = DateTime.now().toUtc();
      final timestamp = _formatTimestamp(now);
      final newEntry = ReflogEntry(
        id: _generateDiffId(branch.checkout, targetCheckoutId, timestamp),
        timestamp: timestamp,
        from: branch.checkout,
        to: targetCheckoutId,
      );

      // Precompute forward diff from old HEAD to target (for fast forward later)
      final targetManifestResult = checkoutService.readManifest(targetCheckoutId);
      if (targetManifestResult.isNone()) {
        return const Some("missing manifest for target checkout");
      }
      final currentManifestResult = checkoutService.readManifest(branch.checkout);
      if (currentManifestResult.isNone()) {
        return const Some("missing manifest for current HEAD");
      }

      final forwardDiff = diffEngine.computeDiff(
        currentManifestResult.toNullable()!,
        targetManifestResult.toNullable()!,
        fromCheckoutId: branch.checkout,
        toCheckoutId: targetCheckoutId,
        fromCreatedAt: "",
        toCreatedAt: "",
      );

      // Write updated branch
      final updated = branch.copyWith(
        checkout: targetCheckoutId,
        reflog: branch.reflog.add(newEntry),
        diffs: branch.diffs.add(newEntry.id, forwardDiff),
      );
      final writeResult = _writeBranch(updated);
      if (writeResult.isSome()) {
        warning("revertTo: ${writeResult.toNullable()}");
        return writeResult;
      }

      committed = true;
      return const None();
    } finally {
      if (!committed) {
        _rollback(undoJournal);
      }
    }
  }

  /// Applies an [inverted] diff to the asset store: downloads and writes files for
  /// adds and modifies, and deletes files for deletes.
  ///
  /// When [DiffDelete.hash] is present, only that specific content hash is
  /// deleted. Otherwise all content hashes under the path hash are removed.
  ///
  /// Tracks all side effects in [undoJournal] so that a partial revert can be
  /// rolled back on failure:
  /// - Adds: tracked so newly-written files can be deleted on rollback.
  /// - Deletes: backed up before deletion so content can be restored on rollback.
  /// - Modifies: original content backed up before overwrite so it can be
  ///   restored on rollback.
  Future<Option<String>> _applyInvertedDiff(
    Diff inverted,
    Channel channel,
    List<_UndoEntry> undoJournal,
  ) async {
    for (final add in inverted.adds) {
      if (assetStore.existsSync(add.pathHash, add.hash)) continue;
      final assetResult = await remoteCatalogService.fetchAsset(channel, add.pathHash, add.hash);
      if (assetResult.isLeft()) {
        final error = assetResult.getLeft();
        String msg = "failed to fetch asset ${add.pathHash}/${add.hash}";
        if (error case final CatalogNetworkError e) msg += ": ${e.message}";
        return Some(msg);
      }
      final content = assetResult.getRight().toNullable()!;
      try {
        assetStore.writeFileByHashesSync(add.pathHash, add.hash, content);
      } on FileSystemException catch (e, stackTrace) {
        warning(
          "revert: failed to write asset ${add.pathHash}/${add.hash}",
          stackTrace: stackTrace,
        );
        return Some("failed to write asset ${add.pathHash}/${add.hash}");
      }
      // Track the newly-written file so it can be deleted on rollback.
      undoJournal.add(_UndoEntry(pathHash: add.pathHash, contentHash: add.hash));
    }

    for (final delete in inverted.deletes) {
      if (delete.hash != null) {
        final contentHash = delete.hash!;
        final content = assetStore.readFileSync(delete.pathHash, contentHash);
        if (content.isSome()) {
          undoJournal.add(
            _UndoEntry(
              pathHash: delete.pathHash,
              contentHash: contentHash,
              content: content.toNullable()!,
            ),
          );
        }
        assetStore.deleteFileSync(delete.pathHash, contentHash);
      } else {
        final hashes = assetStore.listContentHashes(delete.pathHash);
        for (final contentHash in hashes) {
          final content = assetStore.readFileSync(delete.pathHash, contentHash);
          if (content.isSome()) {
            undoJournal.add(
              _UndoEntry(
                pathHash: delete.pathHash,
                contentHash: contentHash,
                content: content.toNullable()!,
              ),
            );
          }
        }
        for (final contentHash in hashes) {
          assetStore.deleteFileSync(delete.pathHash, contentHash);
        }
      }
    }

    for (final modify in inverted.modifies) {
      if (assetStore.existsSync(modify.pathHash, modify.hash)) continue;

      // Backup original content before overwriting.
      final originalContent = assetStore.readFileSync(modify.pathHash, modify.hash);
      if (originalContent.isSome()) {
        undoJournal.add(
          _UndoEntry(
            pathHash: modify.pathHash,
            contentHash: modify.hash,
            content: originalContent.toNullable()!,
          ),
        );
      }

      final assetResult = await remoteCatalogService.fetchAsset(
        channel,
        modify.pathHash,
        modify.hash,
      );
      if (assetResult.isLeft()) {
        final error = assetResult.getLeft();
        String msg = "failed to fetch asset ${modify.pathHash}/${modify.hash}";
        if (error case final CatalogNetworkError e) msg += ": ${e.message}";
        return Some(msg);
      }
      final content = assetResult.getRight().toNullable()!;
      try {
        assetStore.writeFileByHashesSync(modify.pathHash, modify.hash, content);
      } on FileSystemException catch (e, stackTrace) {
        warning(
          "revert: failed to write asset ${modify.pathHash}/${modify.hash}",
          stackTrace: stackTrace,
        );
        return Some("failed to write asset ${modify.pathHash}/${modify.hash}");
      }
    }

    return const None();
  }

  /// Rolls back all side effects recorded in [journal].
  ///
  /// For add entries (content is null): deletes the file from the asset store.
  /// For delete/modify entries (content is non-null): restores the original content.
  ///
  /// Replays entries in reverse order and is best-effort (logs a warning if a
  /// restore or delete fails instead of throwing).
  void _rollback(List<_UndoEntry> journal) {
    for (final entry in journal.reversed) {
      try {
        if (entry.content == null) {
          // Add entry — file was newly written; delete it on rollback.
          assetStore.deleteFileSync(entry.pathHash, entry.contentHash);
        } else {
          // Delete or modify entry — restore original content.
          assetStore.writeFileByHashesSync(entry.pathHash, entry.contentHash, entry.content!);
        }
      } on FileSystemException catch (e, stackTrace) {
        warning(
          "revert rollback: failed to handle ${entry.pathHash}/${entry.contentHash}",
          stackTrace: stackTrace,
        );
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────────

  String _formatTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, "0");
    final mo = dt.month.toString().padLeft(2, "0");
    final d = dt.day.toString().padLeft(2, "0");
    final h = dt.hour.toString().padLeft(2, "0");
    final mi = dt.minute.toString().padLeft(2, "0");
    final s = dt.second.toString().padLeft(2, "0");
    return "$y-$mo-${d}T$h:$mi:${s}Z";
  }

  String _generateDiffId(String from, String to, String timestamp) {
    final input = "$from:$to:$timestamp";
    final hash = input.hashCode.toRadixString(16);
    return hash.padLeft(16, "0");
  }
}

// ── Undo journal entry ─────────────────────────────────────────────────────────

final class _UndoEntry {
  const _UndoEntry({required this.pathHash, required this.contentHash, this.content});

  /// The path hash of the affected asset.
  final String pathHash;

  /// The content hash of the affected asset.
  final String contentHash;

  /// The original content to restore on rollback.
  ///
  /// When `null`, this entry represents a newly-added file that should be
  /// deleted on rollback. When non-null (for delete or modify operations),
  /// the content is restored on rollback.
  final Uint8List? content;
}
