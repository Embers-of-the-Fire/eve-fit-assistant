import "dart:convert";

import "package:eve_fit_assistant/compat/io.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:flutter/foundation.dart";
import "package:path/path.dart" as p;

/// Whether the storage root can be edited from the UI. The configured root is
/// honored on every native platform, but only Windows exposes editing.
bool get storageRootEditable => !kIsWeb && Platform.isWindows;

/// The app-owned directory names that live directly under the storage root.
const storageRootDirectories = ["settings", "resources", "runtime", "logs"];

/// Persists the user-configured storage root.
///
/// The preference is a tiny bootstrap file under the *default* application
/// support directory (never the effective, possibly overridden one), because
/// it must be readable before any storage service opens: [PathProvider.init]
/// resolves the platform default, startup then applies the configured
/// override via [PathProvider.applyStorageRootOverride].
class StorageRootPreference {
  const StorageRootPreference._();

  static const _fileName = "storage_root.json";
  static const _key = "root";

  static String get _configPath => p.join(PathProvider.defaultAppSupportPath, _fileName);

  /// The configured storage root, or null when unset, blank, or unreadable.
  static Future<String?> read() async {
    try {
      final file = File(_configPath);
      if (!file.existsSync()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return null;
      final root = json[_key];
      if (root is! String) return null;
      final trimmed = root.trim();
      return trimmed.isEmpty ? null : trimmed;
    } on Object {
      return null;
    }
  }

  /// Persists [root]; null or blank clears the preference (back to default).
  static Future<void> write(String? root) async {
    final file = File(_configPath);
    final trimmed = root?.trim() ?? "";
    if (trimmed.isEmpty) {
      if (file.existsSync()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final tmp = File("${file.path}.tmp");
    await tmp.writeAsString(jsonEncode({_key: trimmed}));
    await tmp.rename(file.path);
  }
}

/// Moves the app-owned storage directories from the current effective root to
/// [newRoot], using the same rename-then-copy strategy as
/// `StoragePathMigrator` (rename is atomic on the same volume; a copy
/// fallback covers cross-volume targets).
///
/// A directory that already exists at the destination is left untouched and
/// its source is kept as well, so previously stored data at [newRoot] is
/// never clobbered. Callers must restart the app afterwards: in-session
/// services keep using the old root until the next launch.
Future<void> migrateStorageRootContents(String newRoot) async {
  final from = PathProvider.appSupportPath;
  if (p.equals(from, newRoot)) return;
  for (final name in storageRootDirectories) {
    await _moveStorageDir(p.join(from, name), p.join(newRoot, name));
  }
}

Future<void> _moveStorageDir(String sourcePath, String targetPath) async {
  final source = Directory(sourcePath);
  final target = Directory(targetPath);
  if (p.equals(sourcePath, targetPath) || !source.existsSync() || target.existsSync()) return;

  final staging = Directory("$targetPath.migrating");
  try {
    await _deleteQuietly(staging);
    await target.parent.create(recursive: true);

    try {
      await source.rename(targetPath);
      return;
    } on FileSystemException {
      // Cross-volume or locked: fall back to copy.
    }

    await _copyRecursively(source, staging);
    await staging.rename(targetPath);
    await _deleteQuietly(source);
  } on FileSystemException catch (e) {
    debugPrint("StorageRoot: failed to move '$sourcePath' -> '$targetPath': $e");
    await _deleteQuietly(staging);
    rethrow;
  }
}

Future<void> _copyRecursively(Directory source, Directory target) async {
  await target.create(recursive: true);
  await for (final entity in source.list(followLinks: false)) {
    final targetPath = p.join(target.path, p.basename(entity.path));
    if (entity is Directory) {
      await _copyRecursively(entity, Directory(targetPath));
    } else if (entity is File) {
      await entity.copy(targetPath);
    } else if (entity is Link) {
      await Link(targetPath).create(await entity.target());
    }
  }
}

Future<void> _deleteQuietly(Directory dir) async {
  try {
    if (dir.existsSync()) await dir.delete(recursive: true);
  } on FileSystemException {
    // Best-effort cleanup; leftovers are retried on the next launch.
  }
}
