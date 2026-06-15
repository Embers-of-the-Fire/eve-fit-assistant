import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/models/missing_files.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";
import "package:path/path.dart" as p;

/// Content-addressed file I/O with atomic writes.
class AssetStore {
  const AssetStore();

  /// Writes [content] for logical [path] to the asset store.
  ///
  /// Computes [RepoHash.hashPath] and [RepoHash.hashContent], resolves the
  /// asset filesystem path via [RepoPaths.assetPath], creates parent directories,
  /// writes to a temp file, then atomically renames to the final path.
  /// Returns the path hash and content hash pair.
  ({String pathHash, String contentHash}) writeFileSync(String path, Uint8List content) {
    final pathHash = RepoHash.hashPath(path);
    final contentHash = RepoHash.hashContent(content);
    final assetPath = RepoPaths.assetPath(pathHash, contentHash);
    final file = File(assetPath);
    if (file.existsSync()) return (pathHash: pathHash, contentHash: contentHash);

    if (!file.parent.existsSync()) file.parent.createSync(recursive: true);

    final tmp = File("$assetPath.tmp");
    try {
      tmp
        ..writeAsBytesSync(content, flush: true)
        ..renameSync(assetPath);
    } on PathNotFoundException catch (e, stackTrace) {
      warning("Asset write failed (path not found): $assetPath", stackTrace: stackTrace);
      rethrow;
    } on FileSystemException catch (e, stackTrace) {
      warning("Asset write failed: $assetPath", stackTrace: stackTrace);
      try {
        if (tmp.existsSync()) tmp.deleteSync();
      } on FileSystemException {
        // best-effort cleanup
      }
      rethrow;
    }

    return (pathHash: pathHash, contentHash: contentHash);
  }

  /// Reads the asset file identified by [pathHash] and [contentHash].
  ///
  /// Returns [None] if the file does not exist on disk.
  Option<Uint8List> readFileSync(String pathHash, String contentHash) {
    final assetPath = RepoPaths.assetPath(pathHash, contentHash);
    final file = File(assetPath);
    if (!file.existsSync()) return const None();
    try {
      return Some(file.readAsBytesSync());
    } on FileSystemException catch (e, stackTrace) {
      warning("Asset read failed: $assetPath", stackTrace: stackTrace);
      return const None();
    }
  }

  /// Writes [content] for the given [pathHash] and [contentHash] to the asset store
  /// atomically (write-to-temp-then-rename). Idempotent: returns early if the file
  /// already exists.
  void writeFileByHashesSync(String pathHash, String contentHash, Uint8List content) {
    final assetPath = RepoPaths.assetPath(pathHash, contentHash);
    final file = File(assetPath);
    if (file.existsSync()) return;

    if (!file.parent.existsSync()) file.parent.createSync(recursive: true);

    final tmp = File("$assetPath.tmp");
    try {
      tmp
        ..writeAsBytesSync(content, flush: true)
        ..renameSync(assetPath);
    } on PathNotFoundException catch (e, stackTrace) {
      warning("Asset write failed (path not found): $assetPath", stackTrace: stackTrace);
      rethrow;
    } on FileSystemException catch (e, stackTrace) {
      warning("Asset write failed: $assetPath", stackTrace: stackTrace);
      try {
        if (tmp.existsSync()) tmp.deleteSync();
      } on FileSystemException {
        // best-effort cleanup
      }
      rethrow;
    }
  }

  /// Returns `true` if the asset file for [pathHash] and [contentHash] exists on disk.
  bool existsSync(String pathHash, String contentHash) {
    final assetPath = RepoPaths.assetPath(pathHash, contentHash);
    return File(assetPath).existsSync();
  }

  /// Deletes the asset file for [pathHash] and [contentHash].
  void deleteFileSync(String pathHash, String contentHash) {
    final assetPath = RepoPaths.assetPath(pathHash, contentHash);
    final file = File(assetPath);
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException catch (e, stackTrace) {
      warning("Asset delete failed: $assetPath", stackTrace: stackTrace);
    }
  }

  /// Verifies that every file in [manifest] exists on disk with the correct content hash.
  ///
  /// Returns [Right] with [unit] on success, or [Left] with a [MissingFiles] report
  /// listing any missing files and hash mismatches.
  Either<MissingFiles, Unit> verifyManifestSync(AssetManifest manifest) {
    final missing = <String>[];
    final hashMismatches = <String>[];

    for (final entry in manifest.files.entries) {
      final pathHash = entry.key;
      final file = entry.value;
      final assetPath = RepoPaths.assetPath(pathHash, file.hash);
      final diskFile = File(assetPath);

      if (!diskFile.existsSync()) {
        missing.add(pathHash);
        continue;
      }

      final diskHash = RepoHash.hashContent(diskFile.readAsBytesSync());
      if (diskHash != file.hash) {
        hashMismatches.add(pathHash);
      }
    }

    if (missing.isEmpty && hashMismatches.isEmpty) {
      return const Right(unit);
    }

    return Left(MissingFiles(missing: missing.toIList(), hashMismatches: hashMismatches.toIList()));
  }

  /// Lists all stored content hashes for the given [pathHash].
  ///
  /// Scans `assets/<2c prefix>/<pathHash>/` and returns the filenames (each is a
  /// content hash). Returns an empty list if the directory does not exist.
  IList<String> listContentHashes(String pathHash) {
    final dir = Directory(RepoPaths.assetContentDir(pathHash));
    if (!dir.existsSync()) return const IList.empty();
    try {
      return dir.listSync().whereType<File>().map((f) => p.basename(f.path)).toIList();
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to list content hashes for $pathHash", stackTrace: stackTrace);
      return const IList.empty();
    }
  }

  /// Scans the assets directory and deletes files not referenced by any
  /// [activeManifests]. Returns the number of files deleted.
  int pruneSync(IList<AssetManifest> activeManifests) {
    final referenced = <String>{};
    for (final manifest in activeManifests) {
      for (final entry in manifest.files.entries) {
        final pathHash = entry.key;
        final contentHash = entry.value.hash;
        referenced.add(RepoPaths.assetPath(pathHash, contentHash));
      }
    }

    final assetsDir = Directory(RepoPaths.assetsPath);
    if (!assetsDir.existsSync()) return 0;

    final toDelete = <String>[];
    for (final prefixDir in assetsDir.listSync().whereType<Directory>()) {
      for (final entity in prefixDir.listSync(recursive: true).whereType<File>()) {
        if (!referenced.contains(entity.path)) {
          toDelete.add(entity.path);
        }
      }
    }

    for (final path in toDelete) {
      try {
        File(path).deleteSync();
      } on FileSystemException catch (e, stackTrace) {
        warning("Asset prune failed: $path", stackTrace: stackTrace);
      }
    }

    _removeEmptyPrefixDirs(assetsDir);

    return toDelete.length;
  }

  void _removeEmptyPrefixDirs(Directory assetsDir) {
    for (final prefixDir in assetsDir.listSync().whereType<Directory>()) {
      for (final pathDir in prefixDir.listSync().whereType<Directory>()) {
        if (pathDir.listSync().isEmpty) {
          try {
            pathDir.deleteSync();
          } on FileSystemException {
            /* best-effort */
          }
        }
      }
      if (prefixDir.listSync().isEmpty) {
        try {
          prefixDir.deleteSync();
        } on FileSystemException {
          /* best-effort */
        }
      }
    }
  }
}
