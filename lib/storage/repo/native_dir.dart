import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:path/path.dart" as p;

/// Assembles a virtual native directory from a content-addressed [AssetManifest].
///
/// The Rust fitting engine expects a flat directory of protobuf database files at a
/// path passed via `FitEngineData::init(staticRootPath:)`. Under the repo system,
/// these files are stored content-addressed under `<schema root>/assets/`. This class
/// creates a temporary filesystem tree where each asset appears at its original path,
/// using a symlink-first strategy with copy fallback to avoid data duplication.
class NativeDirResolver {
  const NativeDirResolver({required this.assetStore});

  final AssetStore assetStore;

  /// Computes the expected native directory path for [manifest] without I/O.
  ///
  /// Shared by [prepareNativeDir] and `assetStaticRootProvider`. The returned
  /// path is deterministic given the same manifest.
  String resolvePathFromManifest(AssetManifest manifest) {
    final entries = manifest.files.entries.map(
      (e) => (pathHash: e.value.pathHash, contentHash: e.value.hash),
    );
    final manifestHash = RepoHash.hashCheckout(entries);
    return p.join(PathProvider.tempPath, "efa", "native", manifestHash);
  }

  /// Creates a temporary native directory populated with all files from [manifest].
  ///
  /// Returns the root path of the native directory suitable for passing to
  /// `FitEngineData.init`.
  Future<String> prepareNativeDir(AssetManifest manifest) async {
    final nativeRoot = resolvePathFromManifest(manifest);
    final dir = Directory(nativeRoot);

    if (dir.existsSync()) return nativeRoot;

    dir.createSync(recursive: true);

    try {
      for (final entry in manifest.files.entries) {
        final logicalPath = entry.key;
        final assetFile = entry.value;
        final assetPath = RepoPaths.assetPath(assetFile.pathHash, assetFile.hash);
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

        _linkOrCopy(assetPath, targetPath);
      }

      return nativeRoot;
    } on FileSystemException {
      dir.deleteSync(recursive: true);
      rethrow;
    }
  }

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

  /// Removes native directories for checkouts not referenced by any
  /// [activeManifests].
  void cleanup(Iterable<AssetManifest> activeManifests) {
    final nativeBase = p.join(PathProvider.tempPath, "efa", "native");
    final baseDir = Directory(nativeBase);
    if (!baseDir.existsSync()) return;

    final activeHashes = <String>{};
    for (final manifest in activeManifests) {
      final entries = manifest.files.entries.map(
        (e) => (pathHash: e.value.pathHash, contentHash: e.value.hash),
      );
      activeHashes.add(RepoHash.hashCheckout(entries));
    }

    for (final entity in baseDir.listSync().whereType<Directory>()) {
      if (!activeHashes.contains(p.basename(entity.path))) {
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
