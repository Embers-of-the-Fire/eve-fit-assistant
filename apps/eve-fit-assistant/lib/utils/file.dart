import "package:efa_compat/io.dart";

import "package:flutter/cupertino.dart";
import "package:path/path.dart" as p;

Future<void> copyRecursive(Directory source, Directory target) async {
  if (!source.existsSync()) {
    throw Exception("Source directory does not exist: ${source.path}");
  }
  if (!target.existsSync()) {
    await target.create(recursive: true);
  }

  await for (final entity in source.list(followLinks: false)) {
    // compute the path of the entity relative to the source
    final relativeName = p.relative(entity.path, from: source.path);
    final destPath = p.join(target.path, relativeName);
    debugPrint("Dest Path: $destPath");

    if (entity is File) {
      final destFile = File(destPath);
      final parent = destFile.parent;
      if (!parent.existsSync()) {
        await parent.create(recursive: true);
      }
      if (destFile.existsSync()) {
        await destFile.delete();
      }
      await entity.copy(destPath);
    } else if (entity is Directory) {
      final destDir = Directory(destPath);
      if (!destDir.existsSync()) {
        await destDir.create(recursive: true);
      }
      await copyRecursive(entity, destDir);
    } else if (entity is Link) {
      final linkTarget = await entity.target();
      final parent = Directory(p.dirname(destPath));
      if (!parent.existsSync()) {
        await parent.create(recursive: true);
      }
      await Link(destPath).create(linkTarget);
    }
  }
}

Future<void> deletePaths(Directory root, Iterable<String> relativePaths) async {
  final normalizedRootPath = p.normalize(p.absolute(root.path));

  for (final relativePath in relativePaths) {
    final normalizedPath = p.normalize(p.absolute(root.path, relativePath));
    final isWithinRoot =
        p.equals(normalizedPath, normalizedRootPath) ||
        p.isWithin(normalizedRootPath, normalizedPath);
    if (!isWithinRoot || p.equals(normalizedPath, normalizedRootPath)) {
      throw StateError("Refusing to delete path outside bundle root: $relativePath");
    }

    switch (FileSystemEntity.typeSync(normalizedPath, followLinks: false)) {
      case FileSystemEntityType.file:
        await File(normalizedPath).delete();
      case FileSystemEntityType.directory:
        await Directory(normalizedPath).delete(recursive: true);
      case FileSystemEntityType.link:
        await Link(normalizedPath).delete();
      case FileSystemEntityType.pipe:
      case FileSystemEntityType.unixDomainSock:
      case FileSystemEntityType.notFound:
        break;
    }
  }
}
