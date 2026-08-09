@TestOn("vm")
library;

import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/storage_root.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  late Directory tempRoot;
  late String sourceRoot;
  late String targetRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp("efa_storage_root_test_");
    sourceRoot = p.join(tempRoot.path, "source");
    targetRoot = p.join(tempRoot.path, "target");
    PathProvider.documentsPath = p.join(tempRoot.path, "documents");
    PathProvider.tempPath = p.join(tempRoot.path, "temp");
    PathProvider.appSupportPath = sourceRoot;
    PathProvider.defaultAppSupportPath = sourceRoot;
    PathProvider.downloadsPath = null;
    PathProvider.cachesPath = p.join(tempRoot.path, "cache");
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Future<void> seedFile(String root, String name, String fileName, String content) async {
    final file = File(p.join(root, name, fileName));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  test("moves all storage directories to the new root", () async {
    for (final name in storageRootDirectories) {
      await seedFile(sourceRoot, name, "data.txt", name);
    }

    await migrateStorageRootContents(targetRoot);

    for (final name in storageRootDirectories) {
      expect(
        File(p.join(targetRoot, name, "data.txt")).readAsStringSync(),
        name,
        reason: "$name should be moved",
      );
      expect(Directory(p.join(sourceRoot, name)).existsSync(), isFalse);
    }
  });

  test("aborts with a conflict exception when a destination directory already exists", () async {
    await seedFile(sourceRoot, "settings", "settings.json", "source");
    await seedFile(sourceRoot, "logs", "app.log", "source");
    await seedFile(targetRoot, "settings", "settings.json", "target");

    await expectLater(
      migrateStorageRootContents(targetRoot),
      throwsA(
        isA<StorageRootMigrationConflictException>().having(
          (e) => e.conflictingPaths,
          "conflictingPaths",
          [p.join(targetRoot, "settings")],
        ),
      ),
    );

    // Nothing was moved: source data stays at the old root, destination data
    // is never clobbered.
    expect(File(p.join(sourceRoot, "settings", "settings.json")).readAsStringSync(), "source");
    expect(File(p.join(sourceRoot, "logs", "app.log")).existsSync(), isTrue);
    expect(File(p.join(targetRoot, "settings", "settings.json")).readAsStringSync(), "target");
    expect(Directory(p.join(targetRoot, "logs")).existsSync(), isFalse);
  });

  test("ignores destination directories without a source counterpart", () async {
    await seedFile(targetRoot, "logs", "app.log", "target");
    await seedFile(sourceRoot, "settings", "settings.json", "source");

    await migrateStorageRootContents(targetRoot);

    expect(File(p.join(targetRoot, "logs", "app.log")).readAsStringSync(), "target");
    expect(File(p.join(targetRoot, "settings", "settings.json")).readAsStringSync(), "source");
  });

  test("is a no-op when the new root equals the current root", () async {
    await migrateStorageRootContents(sourceRoot);
    expect(Directory(targetRoot).existsSync(), isFalse);
  });
}
