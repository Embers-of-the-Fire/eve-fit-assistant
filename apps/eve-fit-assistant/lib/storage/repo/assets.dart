import "dart:convert";

import "package:efa_proto/resource_index.pb.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/fs/blob_store.dart";
import "package:eve_fit_assistant/storage/fs/repo_store.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/snapshot_meta.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/resource_policy.dart";
import "package:eve_fit_assistant/utils/canonical_json.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/foundation.dart";
import "package:fpdart/fpdart.dart";

/// Content-addressed blob I/O with atomic writes.
///
/// Blobs are stored at `assets/blobs/{2c}/{ident_hash}/{content_hash}`
/// and resource snapshots at `assets/resources/{snapshot_hash}/`.
///
/// All I/O goes through a [BlobStore]: `FileBlobStore` on native platforms,
/// `OpfsBlobStore` on web. Every method is async because OPFS is async-only.
class AssetStore {
  /// Creates an asset store over the platform's repo blob store (or [store]).
  AssetStore([BlobStore? store]) : _store = store ?? createRepoBlobStore();

  /// Creates an asset store over an explicit [BlobStore] (tests).
  AssetStore.forTest(this._store);

  final BlobStore _store;

  /// The backing blob store.
  BlobStore get store => _store;

  /// Writes a blob identified by [identHash] and [content] to the asset store.
  ///
  /// The content_hash is computed as SHA-256 of [content]. Returns (identHash, contentHash).
  /// Idempotent: skips write if the file already exists.
  Future<({String identHash, String contentHash})> writeBlob(
    String identHash,
    Uint8List content,
  ) async {
    final contentHash = RepoHash.hashContent(content);
    final assetPath = RepoPaths.blobPath(identHash, contentHash);
    if (await _store.exists(assetPath)) {
      return (identHash: identHash, contentHash: contentHash);
    }
    await _writeBlobAtPath(assetPath, content);
    return (identHash: identHash, contentHash: contentHash);
  }

  /// Writes a blob directly to [assetPath] — no path resolution, no hash
  /// computation, no idempotency guard. The path and content are trusted.
  ///
  /// The canonical entry point for batch downloaders, whose paths have been
  /// pre-computed during the partition phase.
  Future<void> writeBlobUncheckedAt(String assetPath, Uint8List content) =>
      _writeBlobAtPath(assetPath, content);

  Future<void> _writeBlobAtPath(String assetPath, Uint8List content) async {
    try {
      await _store.write(assetPath, content);
    } catch (e, stackTrace) {
      warning("Blob write failed: $assetPath", stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Reads a blob by ident_hash and content_hash.
  ///
  /// Returns [None] if the file does not exist.
  Future<Option<Uint8List>> readBlob(String identHash, String contentHash) async {
    final assetPath = RepoPaths.blobPath(identHash, contentHash);
    final bytes = await _store.read(assetPath);
    if (bytes == null) return const None();
    return Some(bytes);
  }

  /// Returns `true` if the blob exists in the store.
  Future<bool> blobExists(String identHash, String contentHash) =>
      _store.exists(RepoPaths.blobPath(identHash, contentHash));

  // ── Resource snapshot I/O ───────────────────────────────────────────────────

  /// Writes a complete resource snapshot.
  ///
  /// The snapshot_hash (v4) binds the canonical metadata.json and resources.pb2
  /// bytes, computed in memory before either file is written. Each file write
  /// is atomic; a crash between the two leaves an unreferenced partial
  /// snapshot that [prune] later removes (the snapshot hash is only published
  /// to the checkout registry after this method returns).
  ///
  /// Returns the computed snapshot_hash. Idempotent: skips if the snapshot
  /// already exists (content-addressed, so existing content is identical).
  Future<String> writeResourceSnapshot({
    required ResourceSnapshotMeta meta,
    required ResourceIndex resourceIndex,
  }) async {
    final indexBytes = resourceIndex.writeToBuffer();
    final metaBytes = canonicalJsonEncode(meta.toJson());

    // Compute snapshot hash (v4) binding metadata.json + resources.pb2 (spec §7).
    final metaHash = RepoHash.hashContent(metaBytes);
    final indexHash = RepoHash.hashContent(indexBytes);
    final snapshotHash = RepoHash.hashResourceSnapshotV4(
      metadataJsonHash: metaHash,
      resourcesPb2Hash: indexHash,
    );

    final indexPath = RepoPaths.resourceIndexPath(snapshotHash);
    if (await _store.exists(indexPath)) return snapshotHash;

    await _store.write(indexPath, indexBytes);
    await _store.write(RepoPaths.resourceSnapshotMetaPath(snapshotHash), metaBytes);
    return snapshotHash;
  }

  /// Reads the ResourceIndex from a resource snapshot.
  ///
  /// Returns [None] if the snapshot does not exist or cannot be parsed.
  ///
  /// An index rejected by the platform gate (see
  /// [validateResourceIndexForPlatform]) escapes as an
  /// [UnsupportedResourceIndexError] — it is an [Error], deliberately not
  /// swallowed by the parse-failure path.
  Future<Option<ResourceIndex>> readResourceIndex(String snapshotHash) async {
    final indexPath = RepoPaths.resourceIndexPath(snapshotHash);
    final bytes = await _store.read(indexPath);
    if (bytes == null) return const None();
    try {
      return Some(decodeResourceIndex(bytes));
    } on Exception catch (e, stackTrace) {
      warning("Failed to read ResourceIndex $snapshotHash", stackTrace: stackTrace);
      return const None();
    }
  }

  /// Reads the metadata for a resource snapshot.
  ///
  /// Returns [None] if the snapshot or metadata.json does not exist, or if
  /// parsing fails.
  Future<Option<ResourceSnapshotMeta>> readResourceSnapshotMeta(String snapshotHash) async {
    final path = RepoPaths.resourceSnapshotMetaPath(snapshotHash);
    final bytes = await _store.read(path);
    if (bytes == null) return const None();
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return Some(ResourceSnapshotMeta.fromJson(json));
    } on Exception catch (e, stackTrace) {
      warning("Failed to read resource snapshot metadata $snapshotHash", stackTrace: stackTrace);
      return const None();
    }
  }

  /// Verifies every blob referenced by [resourceIndex] exists with a correct
  /// content hash.
  ///
  /// A NON_FORCE blob that was never fetched is expected to be absent — it
  /// downloads lazily on first access — so its absence is not a failure. A
  /// NON_FORCE blob that *is* present must still hash-check clean.
  ///
  /// [onProgress] receives (checked, total) blob counts as verification
  /// proceeds. The loop yields to the event loop periodically so it can run
  /// on the web main thread without janking the UI.
  ///
  /// Returns a list of missing or mismatched resource_id values.
  Future<IList<String>> verifyResourceIndex(
    ResourceIndex resourceIndex, {
    void Function(int checked, int total)? onProgress,
  }) async {
    final failures = <String>[];
    final total = resourceIndex.entries.length;
    var checked = 0;
    for (final entry in resourceIndex.entries) {
      final ihash = RepoHash.hashIdent(entry.resourceId);
      final assetPath = RepoPaths.blobPath(ihash, entry.contentHash);
      final bytes = await _store.read(assetPath);
      if (bytes == null) {
        if (shouldEagerDownload(resourceIndex, entry)) {
          failures.add(entry.resourceId);
        }
      } else if (RepoHash.hashContent(bytes) != entry.contentHash) {
        failures.add(entry.resourceId);
      }
      checked++;
      onProgress?.call(checked, total);
      if (checked % 64 == 0) {
        // Let the event loop breathe (matters on the web main thread).
        await Future<void>.delayed(Duration.zero);
      }
    }
    return failures.toIList();
  }

  // ── Pruning ────────────────────────────────────────────────────────────────

  /// Scans the assets directory and deletes resource snapshots not in
  /// [activeSnapshotHashes]. Deletes blobs not referenced by any
  /// [activeResourceIndexes]. Also removes orphaned `.tmp` files and snapshot
  /// directories left empty after pruning.
  ///
  /// [onProgress] receives (scanned, total) item counts as pruning proceeds.
  ///
  /// Returns the count of files deleted.
  Future<int> prune({
    required Set<String> activeSnapshotHashes,
    required List<ResourceIndex> activeResourceIndexes,
    void Function(int scanned, int total)? onProgress,
  }) async {
    final referencedBlobs = referencedBlobPaths(activeResourceIndexes);

    final files = await _store.list(RepoPaths.assetsPath);
    final total = files.length;
    var deleted = 0;
    var scanned = 0;

    final resourcesPrefix = "${normalizeStorePath(RepoPaths.resourcesDirPath)}/";
    final blobsPrefix = "${normalizeStorePath(RepoPaths.blobsDirPath)}/";
    final emptiedSnapshotDirs = <String>{};

    for (final file in files) {
      scanned++;
      final normalized = normalizeStorePath(file);

      var remove = false;
      if (normalized.endsWith(".tmp")) {
        remove = true;
      } else if (normalized.startsWith(resourcesPrefix)) {
        // assets/resources/{snapshotHash}/...
        final snapshotHash = normalized.substring(resourcesPrefix.length).split("/").first;
        if (!activeSnapshotHashes.contains(snapshotHash)) {
          remove = true;
          emptiedSnapshotDirs.add(normalizeStorePath(RepoPaths.resourceSnapshotPath(snapshotHash)));
        }
      } else if (normalized.startsWith(blobsPrefix)) {
        if (!referencedBlobs.contains(normalized)) remove = true;
      }

      if (remove) {
        await _store.delete(file);
        deleted++;
      }
      onProgress?.call(scanned, total);
    }

    // Remove snapshot directories whose files were all pruned. A directory
    // that still holds files (e.g. a concurrent write) is left untouched.
    for (final dir in emptiedSnapshotDirs) {
      if ((await _store.list(dir)).isEmpty) {
        await _store.deleteTree(dir);
      }
    }

    return deleted;
  }

  // ── Recovery ─────────────────────────────────────────────────────────────

  /// Cleans up orphaned temporary artifacts left behind by interrupted atomic
  /// writes.
  ///
  /// Native atomic writes use a `.tmp → rename` pattern; a crash between the
  /// temp write and the rename leaves a `.tmp` file behind. OPFS writes are
  /// atomic on stream close and never create `.tmp` files, so this is a no-op
  /// on web.
  ///
  /// Best-effort and idempotent; intended to run once at startup.
  Future<void> recover() async {
    if (kIsWeb) return;
    final List<String> files;
    try {
      files = await _store.list(RepoPaths.assetsPath);
    } catch (e, stackTrace) {
      warning("Failed to scan assets for recovery", stackTrace: stackTrace);
      return;
    }
    for (final file in files) {
      if (!file.endsWith(".tmp")) continue;
      try {
        await _store.delete(file);
      } catch (e, stackTrace) {
        warning("Failed to delete orphaned temp file $file", stackTrace: stackTrace);
      }
    }
  }
}

/// Normalizes a store path so Windows-style and POSIX-style separators
/// compare equal.
String normalizeStorePath(String path) => path.replaceAll(r"\", "/");

/// Computes the normalized store paths of every blob referenced by
/// [activeResourceIndexes].
///
/// Pure and store-agnostic: prune decisions compare these paths against the
/// scanned store listing, so the policy can be unit-tested without a blob
/// store.
Set<String> referencedBlobPaths(Iterable<ResourceIndex> activeResourceIndexes) {
  final referenced = <String>{};
  for (final ri in activeResourceIndexes) {
    for (final entry in ri.entries) {
      final ihash = RepoHash.hashIdent(entry.resourceId);
      referenced.add(normalizeStorePath(RepoPaths.blobPath(ihash, entry.contentHash)));
    }
  }
  return referenced;
}
