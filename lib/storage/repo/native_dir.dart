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

  /// Suffix of the marker file recording the blob root a native directory was
  /// materialized against. The marker is stored as a sibling of the native
  /// directory (`<nativeRoot>.efa_blob_root`), never inside the materialized
  /// tree, so it cannot collide with a resource index entry.
  static const _markerFileSuffix = "efa_blob_root";

  static String _markerPath(String nativeRoot) => "$nativeRoot.$_markerFileSuffix";

  /// Computes the expected native directory path for [snapshotHash]
  /// without I/O.
  ///
  /// Shared by [prepareNativeDir] and the `assetStaticRootProvider`. The returned
  /// path is deterministic given the same snapshot hash.
  String resolvePathFromSnapshot(String snapshotHash) =>
      p.join(PathProvider.tempPath, "efa", "native", snapshotHash);

  /// Creates a temporary native directory populated with all files referenced by
  /// [resourceIndex], and returns the root path of the native directory.
  ///
  /// A native directory is only reused when its marker file matches the current
  /// blob root. Directories materialized before a storage relocation (e.g. the
  /// documents → application support migration) contain absolute symlinks into
  /// the old blob root and are rebuilt instead.
  Future<String> prepareNativeDir(String snapshotHash, ResourceIndex resourceIndex) async {
    final nativeRoot = resolvePathFromSnapshot(snapshotHash);
    final dir = Directory(nativeRoot);

    if (dir.existsSync()) {
      if (!_isStale(nativeRoot)) return nativeRoot;
      dir.deleteSync(recursive: true);
    }

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

      File(_markerPath(nativeRoot)).writeAsStringSync(RepoPaths.assetsPath);
      return nativeRoot;
    } on FileSystemException {
      dir.deleteSync(recursive: true);
      rethrow;
    }
  }

  /// Returns `true` when the native directory at [nativeRoot] was materialized
  /// against a different blob root than the current one (or has no marker,
  /// e.g. it predates the marker mechanism).
  static bool _isStale(String nativeRoot) {
    final marker = File(_markerPath(nativeRoot));
    try {
      return marker.readAsStringSync() != RepoPaths.assetsPath;
    } on FileSystemException {
      return true;
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
  /// ResourceIndex_Entry.
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

  /// Removes native directories for snapshots not in [activeSnapshotHashes],
  /// along with their marker files.
  void cleanup(Iterable<String> activeSnapshotHashes) {
    final nativeBase = p.join(PathProvider.tempPath, "efa", "native");
    final baseDir = Directory(nativeBase);
    if (!baseDir.existsSync()) return;

    final activeSet = activeSnapshotHashes.toSet();

    for (final entity in baseDir.listSync()) {
      final name = p.basename(entity.path);
      final isOrphan =
          entity is Directory && !activeSet.contains(name) ||
          entity is File &&
              name.endsWith(".$_markerFileSuffix") &&
              !activeSet.contains(name.substring(0, name.length - _markerFileSuffix.length - 1));
      if (!isOrphan) continue;
      try {
        entity.deleteSync(recursive: true);
      } on FileSystemException catch (e, stackTrace) {
        warning(
          "Failed to remove stale native directory artifact: ${entity.path}",
          stackTrace: stackTrace,
        );
      }
    }
  }
}
