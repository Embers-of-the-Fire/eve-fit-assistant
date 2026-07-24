import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/path_migration.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  late Directory tempRoot;
  late String documentsDir;
  late String supportDir;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp("efa_path_migration_test_");
    documentsDir = p.join(tempRoot.path, "documents");
    supportDir = p.join(tempRoot.path, "support");
    await Directory(documentsDir).create(recursive: true);
    await Directory(supportDir).create(recursive: true);
    PathProvider.documentsPath = documentsDir;
    PathProvider.appSupportPath = supportDir;
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Future<File> createLegacyFile(String dirName, String relativePath, String content) async {
    final file = File(p.join(documentsDir, dirName, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return file;
  }

  group("fresh install", () {
    test("is a no-op when no legacy directories exist", () async {
      await const StoragePathMigrator().migrateIfNeeded();

      for (final name in ["settings", "resources", "runtime", "logs"]) {
        expect(Directory(p.join(supportDir, name)).existsSync(), isFalse, reason: name);
      }
    });

    test("is a no-op when documents and support resolve to the same root", () async {
      PathProvider.appSupportPath = documentsDir;
      await createLegacyFile("settings", "settings.json", "{}");

      await const StoragePathMigrator().migrateIfNeeded();

      expect(File(p.join(documentsDir, "settings", "settings.json")).existsSync(), isTrue);
    });
  });

  group("migration", () {
    test("moves all legacy directories with contents intact", () async {
      await createLegacyFile("settings", "settings.json", "settings-content");
      await createLegacyFile("resources", "v2/schema_version.json", "schema-content");
      await createLegacyFile("resources", "v2/assets/blobs/ab/hash", "blob-content");
      await createLegacyFile("runtime", "v2/fittings/fit.json", "fit-content");
      await createLegacyFile("runtime", "v2/characters/char.json", "char-content");
      await createLegacyFile("logs", "app.log", "log-content");

      await const StoragePathMigrator().migrateIfNeeded();

      final expected = <String, String>{
        p.join(supportDir, "settings", "settings.json"): "settings-content",
        p.join(supportDir, "resources", "v2", "schema_version.json"): "schema-content",
        p.join(supportDir, "resources", "v2", "assets", "blobs", "ab", "hash"): "blob-content",
        p.join(supportDir, "runtime", "v2", "fittings", "fit.json"): "fit-content",
        p.join(supportDir, "runtime", "v2", "characters", "char.json"): "char-content",
        p.join(supportDir, "logs", "app.log"): "log-content",
      };
      for (final entry in expected.entries) {
        final file = File(entry.key);
        expect(file.existsSync(), isTrue, reason: entry.key);
        expect(await file.readAsString(), entry.value, reason: entry.key);
      }

      for (final name in ["settings", "resources", "runtime", "logs"]) {
        expect(
          Directory(p.join(documentsDir, name)).existsSync(),
          isFalse,
          reason: "legacy $name should be removed",
        );
      }
    });

    test("migrates only the directories that exist", () async {
      await createLegacyFile("settings", "settings.json", "settings-content");

      await const StoragePathMigrator().migrateIfNeeded();

      expect(File(p.join(supportDir, "settings", "settings.json")).existsSync(), isTrue);
      expect(Directory(p.join(supportDir, "resources")).existsSync(), isFalse);
      expect(Directory(p.join(supportDir, "runtime")).existsSync(), isFalse);
      expect(Directory(p.join(supportDir, "logs")).existsSync(), isFalse);
    });

    test("skips directories that already exist at the target", () async {
      await createLegacyFile("settings", "settings.json", "legacy-content");
      final existing = File(p.join(supportDir, "settings", "settings.json"));
      await existing.parent.create(recursive: true);
      await existing.writeAsString("current-content");

      await const StoragePathMigrator().migrateIfNeeded();

      expect(await existing.readAsString(), "current-content");
      expect(
        File(p.join(documentsDir, "settings", "settings.json")).existsSync(),
        isTrue,
        reason: "legacy copy is preserved when the target already exists",
      );
    });

    test("is idempotent across runs", () async {
      await createLegacyFile("settings", "settings.json", "settings-content");

      await const StoragePathMigrator().migrateIfNeeded();
      await const StoragePathMigrator().migrateIfNeeded();

      expect(
        await File(p.join(supportDir, "settings", "settings.json")).readAsString(),
        "settings-content",
      );
    });

    test("cleans up a stale staging directory from a crashed run", () async {
      await createLegacyFile("settings", "settings.json", "settings-content");
      final staleFile = File(p.join(supportDir, ".settings.migrating", "partial.json"));
      await staleFile.parent.create(recursive: true);
      await staleFile.writeAsString("partial");

      await const StoragePathMigrator().migrateIfNeeded();

      expect(
        await File(p.join(supportDir, "settings", "settings.json")).readAsString(),
        "settings-content",
      );
      expect(File(p.join(supportDir, "settings", "partial.json")).existsSync(), isFalse);
      expect(Directory(p.join(supportDir, ".settings.migrating")).existsSync(), isFalse);
    });
  });

  group("copy fallback", () {
    Future<Directory> failingRename(Directory dir, String newPath) =>
        throw const FileSystemException("cross-device link");

    test("copies via staging when rename fails", () async {
      await createLegacyFile("resources", "v2/assets/blobs/ab/hash", "blob-content");
      await createLegacyFile("resources", "v2/schema_version.json", "schema-content");

      await StoragePathMigrator(rename: failingRename).migrateIfNeeded();

      expect(
        await File(
          p.join(supportDir, "resources", "v2", "assets", "blobs", "ab", "hash"),
        ).readAsString(),
        "blob-content",
      );
      expect(
        await File(p.join(supportDir, "resources", "v2", "schema_version.json")).readAsString(),
        "schema-content",
      );
      expect(Directory(p.join(documentsDir, "resources")).existsSync(), isFalse);
      expect(Directory(p.join(supportDir, ".resources.migrating")).existsSync(), isFalse);
    });

    test("preserves directory symlinks instead of traversing them", () async {
      await createLegacyFile("resources", "v2/schema_version.json", "schema-content");
      final external = Directory(p.join(tempRoot.path, "external_blobs"));
      await external.create();
      await File(p.join(external.path, "hash")).writeAsString("blob-content");
      final linked = Link(p.join(documentsDir, "resources", "v2", "blobs"));
      await linked.parent.create(recursive: true);
      await linked.create(external.path);

      await StoragePathMigrator(rename: failingRename).migrateIfNeeded();

      final migratedLink = Link(p.join(supportDir, "resources", "v2", "blobs"));
      expect(
        FileSystemEntity.typeSync(migratedLink.path, followLinks: false),
        FileSystemEntityType.link,
      );
      expect(await migratedLink.target(), external.path);
      expect(Directory(p.join(documentsDir, "resources")).existsSync(), isFalse);
    });

    test("uses rename for directories before the failure point and copy after", () async {
      await createLegacyFile("settings", "settings.json", "settings-content");
      await createLegacyFile("resources", "v2/schema_version.json", "schema-content");

      await StoragePathMigrator(rename: failingRename).migrateIfNeeded();

      expect(File(p.join(supportDir, "settings", "settings.json")).existsSync(), isTrue);
      expect(
        File(p.join(supportDir, "resources", "v2", "schema_version.json")).existsSync(),
        isTrue,
      );
    });

    test("keeps legacy data when the copy fallback also fails", () async {
      await createLegacyFile("settings", "settings.json", "settings-content");
      await Directory(supportDir).delete(recursive: true);
      final blockingFile = File(supportDir);
      await blockingFile.writeAsString("not a directory");

      await StoragePathMigrator(rename: failingRename).migrateIfNeeded();

      expect(
        await File(p.join(documentsDir, "settings", "settings.json")).readAsString(),
        "settings-content",
      );
    });
  });
}
