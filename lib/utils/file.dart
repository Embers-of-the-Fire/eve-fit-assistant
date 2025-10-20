import "dart:io";

Future<void> copyRecursive(Directory source, Directory target) async {
  if (!source.existsSync()) {
    throw Exception("Source directory does not exist: ${source.path}");
  }
  if (!target.existsSync()) {
    await target.create(recursive: true);
  }

  await for (final entity in source.list(followLinks: false)) {
    final name = entity.uri.pathSegments.isNotEmpty ? entity.uri.pathSegments.last : entity.path;
    final destPath = "${target.path}${Platform.pathSeparator}$name";

    switch (entity) {
      case final File file:
        await file.copy(destPath);
      case final Directory dir:
        await copyRecursive(dir, Directory(destPath));
      case final Link link:
        final target = await link.target();
        await Link(destPath).create(target);
    }
  }
}
