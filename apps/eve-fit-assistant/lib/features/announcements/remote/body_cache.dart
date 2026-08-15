import "package:efa_compat/io.dart";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:path/path.dart" as p;

/// Disk cache for announcement markdown bodies.
///
/// Announcements are not served on web and there is no filesystem there, so
/// every operation degrades to an inert no-op instead of touching the
/// `dart:io` stub (which would throw [UnsupportedError]).
class AnnouncementBodyCache {
  AnnouncementBodyCache._();

  static Future<void> init() async {
    if (kIsWeb) return;
    final dir = Directory(_cacheDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  static Future<String?> get(String bodyHash) async {
    if (kIsWeb) return null;
    try {
      final file = File(_filePath(bodyHash));
      if (!file.existsSync()) {
        return null;
      }
      return await file.readAsString();
    } on FileSystemException catch (e) {
      warning("Failed to read cached announcement body $bodyHash: $e");
      return null;
    }
  }

  static Future<void> put(String bodyHash, String content) async {
    if (kIsWeb) return;
    try {
      final path = _filePath(bodyHash);
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    } on FileSystemException catch (e) {
      warning("Failed to cache announcement body $bodyHash: $e");
    }
  }

  static bool exists(String bodyHash) {
    if (kIsWeb) return false;
    try {
      return File(_filePath(bodyHash)).existsSync();
    } on FileSystemException {
      return false;
    }
  }

  /// Delete any cached body files whose hashes are not in [referencedHashes].
  /// Failures are logged and skipped so a single bad file does not abort the
  /// sweep.
  static Future<void> prune({required Set<String> referencedHashes}) async {
    if (kIsWeb) return;
    try {
      final root = Directory(_cacheDir);
      if (!root.existsSync()) return;
      final entities = root.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is! File) continue;
        if (!entity.path.endsWith(".md")) continue;
        final fileName = p.basenameWithoutExtension(entity.path);
        if (referencedHashes.contains(fileName)) continue;
        try {
          await entity.delete();
        } on FileSystemException catch (e) {
          warning("Failed to prune cached announcement body ${entity.path}: $e");
        }
      }
    } on FileSystemException catch (e) {
      warning("Failed to list announcement body cache for pruning: $e");
    }
  }

  static String get _cacheDir => p.join(PathProvider.cachesPath, "announcements", "bodies");

  static String _filePath(String bodyHash) {
    final prefix = bodyHash.substring(0, 2);
    return p.join(_cacheDir, prefix, "$bodyHash.md");
  }
}
