import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/blob_ident.dart";
import "package:eve_fit_assistant/storage/repo/models/snapshot_meta.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/utils.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";

/// Content-addressed blob I/O with atomic writes.
///
/// Blobs are stored at `assets/blobs/{2c}/{ident_hash}/{content_hash}`
/// and resource snapshots at `assets/resources/{snapshot_hash}/`.
class AssetStore {
  const AssetStore();

  /// Writes a blob identified by [identHash] and [content] to the asset store.
  ///
  /// The content_hash is computed as SHA-256 of [content]. Returns (identHash, contentHash).
  /// Idempotent: skips write if the file already exists.
  ({String identHash, String contentHash}) writeBlobSync(String identHash, Uint8List content) {
    final contentHash = RepoHash.hashContent(content);
    final assetPath = RepoPaths.blobPath(identHash, contentHash);
    return _writeBlobAtPath(assetPath, identHash, contentHash, content);
  }

  /// Writes a blob identified by [ident] and [content] to the asset store.
  ({String identHash, String contentHash}) writeBlobByIdentSync(
    BlobIdent ident,
    Uint8List content,
  ) => writeBlobSync(ident.identHash, content);

  /// Reads a blob by ident_hash and content_hash.
  ///
  /// Returns [None] if the file does not exist.
  Option<Uint8List> readBlobSync(String identHash, String contentHash) {
    final assetPath = RepoPaths.blobPath(identHash, contentHash);
    final file = File(assetPath);
    if (!file.existsSync()) return const None();
    try {
      return Some(file.readAsBytesSync());
    } on FileSystemException catch (e, stackTrace) {
      warning("Blob read failed: $assetPath", stackTrace: stackTrace);
      return const None();
    }
  }

  /// Returns `true` if the blob exists on disk.
  bool blobExistsSync(String identHash, String contentHash) {
    final assetPath = RepoPaths.blobPath(identHash, contentHash);
    return File(assetPath).existsSync();
  }

  /// Deletes a blob.
  void deleteBlobSync(String identHash, String contentHash) {
    final assetPath = RepoPaths.blobPath(identHash, contentHash);
    final file = File(assetPath);
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException catch (e, stackTrace) {
      warning("Blob delete failed: $assetPath", stackTrace: stackTrace);
    }
  }

  // ── Resource snapshot I/O ───────────────────────────────────────────────────

  /// Writes a complete resource snapshot atomically.
  ///
  /// Steps:
  /// 1. Write metadata.json and resources.pb2 to a temp directory
  /// 2. Compute snapshot_hash from the two file hashes
  /// 3. Rename temp → assets/resources/{snapshot_hash}/
  ///
  /// Returns the computed snapshot_hash. Idempotent: skips if the snapshot
  /// already exists.
  String writeResourceSnapshotSync({
    required ResourceSnapshotMeta meta,
    required ResourceIndex resourceIndex,
  }) {
    // Write to temp to compute hash
    final tempDir = Directory(_resourceTempPath());
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    tempDir.createSync(recursive: true);

    const metaPath = "metadata.json";
    const indexPath = "resources.pb2";

    // Write resources.pb2 to temp dir
    final indexFile = File("${tempDir.path}/$indexPath");
    writeProtobufSync(indexFile.path, resourceIndex);

    // Serialize metadata.json
    _writeMetadataJson("${tempDir.path}/$metaPath", meta);

    // Compute hashes
    final metaBytes = File("${tempDir.path}/$metaPath").readAsBytesSync();
    final indexBytes = File("${tempDir.path}/$indexPath").readAsBytesSync();
    final metaHash = RepoHash.hashContent(metaBytes);
    final indexHash = RepoHash.hashContent(indexBytes);
    final snapshotHash = RepoHash.hashResourceSnapshot(metaHash, indexHash);

    final targetDir = Directory(RepoPaths.resourceSnapshotPath(snapshotHash));
    if (targetDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
      return snapshotHash;
    }

    targetDir.parent.createSync(recursive: true);
    tempDir.renameSync(targetDir.path);
    return snapshotHash;
  }

  /// Reads the ResourceIndex from a resource snapshot.
  ///
  /// Returns [None] if the snapshot does not exist.
  Option<ResourceIndex> readResourceIndexSync(String snapshotHash) {
    final indexPath = RepoPaths.resourceIndexPath(snapshotHash);
    final file = File(indexPath);
    if (!file.existsSync()) return const None();
    try {
      return Some(ResourceIndex.fromBuffer(file.readAsBytesSync()));
    } on Exception catch (e, stackTrace) {
      warning("Failed to read ResourceIndex $snapshotHash", stackTrace: stackTrace);
      return const None();
    }
  }

  /// Reads the resource snapshot metadata.
  ///
  /// Returns [None] if the snapshot does not exist.
  Option<ResourceSnapshotMeta> readResourceSnapshotMetaSync(String snapshotHash) => _readJsonFile(
    RepoPaths.resourceSnapshotMetaPath(snapshotHash),
    ResourceSnapshotMeta.fromJson,
  );

  /// Reads the announcement snapshot metadata.
  Option<AnnouncementSnapshotMeta> readAnnouncementSnapshotMetaSync(String snapshotHash) =>
      _readJsonFile(
        RepoPaths.announcementSnapshotMetaPath(snapshotHash),
        AnnouncementSnapshotMeta.fromJson,
      );

  /// Verifies every blob referenced by [resourceIndex] exists on disk with
  /// correct content hash.
  ///
  /// Returns a list of missing or mismatched resource_id values.
  IList<String> verifyResourceIndexSync(ResourceIndex resourceIndex) {
    final failures = <String>[];
    for (final entry in resourceIndex.entries) {
      final ihash = RepoHash.hashIdent(entry.resourceId);
      final assetPath = RepoPaths.blobPath(ihash, entry.contentHash);
      final file = File(assetPath);
      if (!file.existsSync()) {
        failures.add(entry.resourceId);
        continue;
      }
      try {
        final diskHash = RepoHash.hashContent(file.readAsBytesSync());
        if (diskHash != entry.contentHash) {
          failures.add(entry.resourceId);
        }
      } on FileSystemException {
        failures.add(entry.resourceId);
      }
    }
    return failures.toIList();
  }

  // ── Pruning ────────────────────────────────────────────────────────────────

  /// Scans the assets directory and deletes resource snapshots not in
  /// [activeSnapshotHashes]. Deletes blobs not referenced by any
  /// [resourceIndexes]. Deletes announcement snapshots not in
  /// [activeAnnouncementHashes] (if non-null). Removes empty directories.
  ///
  /// Returns the count of files deleted.
  int pruneSync({
    required Set<String> activeSnapshotHashes,
    required List<ResourceIndex> activeResourceIndexes,
    Set<String>? activeAnnouncementHashes,
  }) {
    var deleted = 0;

    // Collect referenced blobs
    final referencedBlobs = <String>{};
    for (final ri in activeResourceIndexes) {
      for (final entry in ri.entries) {
        final ihash = RepoHash.hashIdent(entry.resourceId);
        referencedBlobs.add(RepoPaths.blobPath(ihash, entry.contentHash));
      }
    }

    final assetsDir = Directory(RepoPaths.assetsPath);
    if (!assetsDir.existsSync()) return 0;

    // Prune resource snapshots
    final resourcesDir = Directory("${RepoPaths.assetsPath}/resources");
    if (resourcesDir.existsSync()) {
      for (final dir in resourcesDir.listSync().whereType<Directory>()) {
        final name = dir.uri.pathSegments.last;
        if (!activeSnapshotHashes.contains(name)) {
          try {
            dir.deleteSync(recursive: true);
            deleted++;
          } on FileSystemException {
            // best-effort
          }
        }
      }
    }

    // Prune blobs
    final blobsDir = Directory("${RepoPaths.assetsPath}/blobs");
    if (blobsDir.existsSync()) {
      for (final prefixDir in blobsDir.listSync().whereType<Directory>()) {
        for (final entity in prefixDir.listSync().whereType<Directory>()) {
          for (final blob in entity.listSync().whereType<File>()) {
            if (!referencedBlobs.contains(blob.path)) {
              try {
                blob.deleteSync();
                deleted++;
              } on FileSystemException {
                // best-effort
              }
            }
          }
          if (entity.listSync().isEmpty) {
            try {
              entity.deleteSync();
            } on FileSystemException {
              // best-effort
            }
          }
        }
        if (prefixDir.listSync().isEmpty) {
          try {
            prefixDir.deleteSync();
          } on FileSystemException {
            // best-effort
          }
        }
      }
    }

    // Prune temporary directories
    for (final dir in assetsDir.listSync().whereType<Directory>()) {
      final name = dir.uri.pathSegments.last;
      if (name.startsWith("tmp_") || name.endsWith("_temp")) {
        try {
          dir.deleteSync(recursive: true);
          deleted++;
        } on FileSystemException {
          // best-effort
        }
      }
    }

    // Prune announcement snapshots (spec §12.2 client)
    if (activeAnnouncementHashes != null) {
      final announcementsDir = Directory(RepoPaths.announcementsRootPath);
      if (announcementsDir.existsSync()) {
        for (final dir in announcementsDir.listSync().whereType<Directory>()) {
          final name = dir.uri.pathSegments.last;
          if (!activeAnnouncementHashes.contains(name)) {
            try {
              dir.deleteSync(recursive: true);
              deleted++;
            } on FileSystemException {
              // best-effort
            }
          }
        }
      }
    }

    return deleted;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  ({String identHash, String contentHash}) _writeBlobAtPath(
    String assetPath,
    String identHash,
    String contentHash,
    Uint8List content,
  ) {
    final file = File(assetPath);
    if (file.existsSync()) return (identHash: identHash, contentHash: contentHash);

    if (!file.parent.existsSync()) file.parent.createSync(recursive: true);

    final tmp = File("$assetPath.tmp");
    try {
      tmp
        ..writeAsBytesSync(content, flush: true)
        ..renameSync(assetPath);
    } on FileSystemException catch (e, stackTrace) {
      warning("Blob write failed: $assetPath", stackTrace: stackTrace);
      try {
        if (tmp.existsSync()) tmp.deleteSync();
      } on FileSystemException {
        // best-effort cleanup
      }
      rethrow;
    }

    return (identHash: identHash, contentHash: contentHash);
  }

  void _writeMetadataJson(String path, ResourceSnapshotMeta meta) {
    final file = File(path);
    final json = meta.toJson();
    file.writeAsStringSync(jsonEncode(json), flush: true);
  }

  String _resourceTempPath() => "${RepoPaths.assetsPath}/tmp_resource_snapshot";

  Option<T> _readJsonFile<T>(String path, T Function(Map<String, dynamic>) fromJson) {
    final file = File(path);
    if (!file.existsSync()) return const None();
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return Some(fromJson(json));
    } on Exception catch (e, stackTrace) {
      warning("Failed to read JSON: $path", stackTrace: stackTrace);
      return const None();
    }
  }
}
