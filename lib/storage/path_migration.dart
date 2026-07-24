import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:flutter/foundation.dart";
import "package:path/path.dart" as p;

typedef DirectoryRename = Future<Directory> Function(Directory dir, String newPath);

class StoragePathMigrator {
  const StoragePathMigrator({DirectoryRename? rename}) : _rename = rename ?? _defaultRename;

  final DirectoryRename _rename;

  static Future<Directory> _defaultRename(Directory dir, String newPath) => dir.rename(newPath);

  static const _migratedDirs = ["settings", "resources", "runtime", "logs"];

  Future<void> migrateIfNeeded() async {
    for (final name in _migratedDirs) {
      await _migrateDir(name);
    }
  }

  Future<void> _migrateDir(String name) async {
    final target = Directory(p.join(PathProvider.appSupportPath, name));
    final legacy = Directory(p.join(PathProvider.documentsPath, name));
    if (target.path == legacy.path || target.existsSync() || !legacy.existsSync()) return;

    final staging = Directory(p.join(PathProvider.appSupportPath, ".$name.migrating"));
    try {
      await _deleteQuietly(staging);
      await target.parent.create(recursive: true);

      try {
        await _rename(legacy, target.path);
        debugPrint("StoragePathMigrator: moved '$name' to application support");
        return;
      } on FileSystemException {
        debugPrint("StoragePathMigrator: rename of '$name' failed, falling back to copy");
      }

      await _copyRecursively(legacy, staging);
      await staging.rename(target.path);
      await _deleteQuietly(legacy);
      debugPrint("StoragePathMigrator: copied '$name' to application support");
    } on FileSystemException catch (e) {
      debugPrint("StoragePathMigrator: failed to migrate '$name': $e");
      await _deleteQuietly(staging);
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
}
