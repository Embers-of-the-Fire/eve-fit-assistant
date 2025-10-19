import 'dart:io';

Future<void> copyRecursive(Directory source, Directory target) async {
  if (!await source.exists()) {
    throw Exception('Source directory does not exist: ${source.path}');
  }
  if (!await target.exists()) {
    await target.create(recursive: true);
  }

  await for (final entity in source.list(recursive: false, followLinks: false)) {
    final name = entity.uri.pathSegments.isNotEmpty ? entity.uri.pathSegments.last : entity.path;
    final destPath = '${target.path}${Platform.pathSeparator}$name';

    if (entity is File) {
      await entity.copy(destPath);
    } else if (entity is Directory) {
      await copyRecursive(entity, Directory(destPath));
    } else if (entity is Link) {
      final linkTarget = await entity.target();
      await Link(destPath).create(linkTarget);
    }
  }
}
