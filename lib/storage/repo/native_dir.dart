import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:path/path.dart" as p;

/// Assembles a virtual native directory from a resource snapshot.
///
/// Under the repo system, resource files are stored content-addressed under
/// `assets/blobs/`. This class creates a temporary filesystem tree where each
/// asset appears at its original logical path, using a symlink-first strategy
/// with copy fallback to avoid data duplication.  Consumers that only need
/// individual files can use the static [`resolveBlobPath`] to get the
/// content-addressed blob path directly.
class NativeDirResolver {
  const NativeDirResolver({required this.assetStore});

  final AssetStore assetStore;

  /// Computes the expected native directory path for [snapshotHash] and
  /// [resourceIndex] without I/O.
  ///
  /// Shared by [prepareNativeDir] and the `assetStaticRootProvider`. The returned
  /// path is deterministic given the same snapshot hash.
  String resolvePathFromSnapshot(String snapshotHash) =>
      p.join(PathProvider.tempPath, "efa", "native", snapshotHash);

  /// Creates a temporary native directory populated with all files referenced by
  /// [resourceIndex], and returns the root path of the native directory.
  Future<String> prepareNativeDir(String snapshotHash, ResourceIndex resourceIndex) async {
    final nativeRoot = resolvePathFromSnapshot(snapshotHash);
    final dir = Directory(nativeRoot);

    if (dir.existsSync()) return nativeRoot;

    dir.createSync(recursive: true);

    try {
      for (final entry in resourceIndex.entries) {
        final logicalPath = _logicalPath(entry.resourceId);
        final blobPath = NativeDirResolver.resolveBlobPath(entry);
        final targetPath = _resolveSafeChild(nativeRoot, logicalPath);
        if (targetPath == null) {
          warning("Skipping path traversal attempt: $logicalPath");
          continue;
        }

        final targetFile = File(targetPath);
        if (targetFile.existsSync()) continue;

        final parent = targetFile.parent;
        if (!parent.existsSync()) {
          parent.createSync(recursive: true);
        }

        _linkOrCopy(blobPath, targetPath);
      }

      return nativeRoot;
    } on FileSystemException {
      dir.deleteSync(recursive: true);
      rethrow;
    }
  }

  /// Strips the `resource://` scheme prefix to recover the logical file path.
  ///
  /// Example: `"resource://static/native/types.pb2"` → `"static/native/types.pb2"`
  static String _logicalPath(String resourceId) {
    const prefix = "resource://";
    if (resourceId.startsWith(prefix)) return resourceId.substring(prefix.length);
    return resourceId;
  }

  /// Returns the content-addressed blob store path for a single
  /// [ResourceIndex.Entry].
  ///
  /// This performs the same ident-hash → content-hash → blob-path computation
  /// that [`prepareNativeDir`] uses internally for each entry, but without
  /// creating any symlinks or directory trees.  Callers that only need a
  /// handful of files can resolve their paths directly and pass them to
  /// consumers without materializing the full native directory on disk.
  static String resolveBlobPath(ResourceIndex_Entry entry) =>
      RepoPaths.blobPath(RepoHash.hashIdent(entry.resourceId), entry.contentHash);

  /// Resolves [child] relative to [root], returning the normalized path only if
  /// it does not escape [root] (e.g. via `..` or absolute paths).
  ///
  /// Returns `null` when the resolved path would traverse outside [root].
  static String? _resolveSafeChild(String root, String child) {
    final resolved = p.normalize(p.join(root, child));
    final normalizedRoot = p.normalize(root);
    if (resolved == normalizedRoot) return resolved;
    if (resolved.startsWith("$normalizedRoot${p.separator}")) return resolved;
    return null;
  }

  /// Attempts a symlink from [source] to [target]; falls back to a byte copy.
  ///
  /// Throws [FileSystemException] if both symlink and copy fail.
  void _linkOrCopy(String source, String target) {
    try {
      Link(target).createSync(source);
    } on FileSystemException {
      File(source).copySync(target);
    }
  }

  /// Removes native directories for snapshots not in [activeSnapshotHashes].
  void cleanup(Iterable<String> activeSnapshotHashes) {
    final nativeBase = p.join(PathProvider.tempPath, "efa", "native");
    final baseDir = Directory(nativeBase);
    if (!baseDir.existsSync()) return;

    final activeSet = activeSnapshotHashes.toSet();

    for (final entity in baseDir.listSync().whereType<Directory>()) {
      if (!activeSet.contains(p.basename(entity.path))) {
        try {
          entity.deleteSync(recursive: true);
        } on FileSystemException catch (e, stackTrace) {
          warning(
            "Failed to remove stale native directory: ${entity.path}",
            stackTrace: stackTrace,
          );
        }
      }
    }
  }
}
