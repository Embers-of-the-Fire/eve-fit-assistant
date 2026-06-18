import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:path/path.dart" as p;

class AnnouncementBodyCache {
  AnnouncementBodyCache._();

  static Future<void> init() async {
    final dir = Directory(_cacheDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  static String? get(String bodyHash) {
    try {
      final file = File(_filePath(bodyHash));
      if (!file.existsSync()) {
        return null;
      }
      return file.readAsStringSync();
    } on FileSystemException catch (e) {
      warning("Failed to read cached announcement body $bodyHash: $e");
      return null;
    }
  }

  static Future<void> put(String bodyHash, String content) async {
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
    try {
      return File(_filePath(bodyHash)).existsSync();
    } on FileSystemException {
      return false;
    }
  }

  static String get _cacheDir => p.join(PathProvider.cachesPath, "announcements", "bodies");

  static String _filePath(String bodyHash) {
    final prefix = bodyHash.substring(0, 2);
    return p.join(_cacheDir, prefix, "$bodyHash.md");
  }
}
