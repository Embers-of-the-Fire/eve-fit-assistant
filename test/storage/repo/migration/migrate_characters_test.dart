@TestOn("vm")
library;

import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/migrate_characters.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

Map<String, dynamic> _legacyCharacterJson(
  String characterId, {
  String? bundleId,
  String? bundleSnapshot,
}) {
  final json = <String, dynamic>{
    "characterId": characterId,
    "name": "Legacy Character",
    "description": "",
    "lastModified": 100,
    "skills": <String, dynamic>{"123": 5},
  };
  if (bundleId != null) json["bundleId"] = bundleId;
  if (bundleSnapshot != null) json["bundleSnapshot"] = bundleSnapshot;
  return json;
}

Map<String, dynamic> _migratedCharacterJson(String characterId) => <String, dynamic>{
  "characterId": characterId,
  "name": "Migrated Character",
  "description": "",
  "lastModified": 200,
  "checkoutRef": <String, dynamic>{"checkoutId": "checkout-xyz", "serverId": "Serenity"},
  "skills": <String, dynamic>{"456": 3},
};

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_mig_char_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  group("MigrateCharacters", () {
    late String sourceDir;
    late String destDir;

    setUp(() {
      final tempDir = Directory.systemTemp.createTempSync("efa_mig_char_test_").path;
      sourceDir = p.join(tempDir, "source");
      destDir = p.join(tempDir, "dest");
    });

    tearDown(() {
      final parentDir = Directory(p.dirname(sourceDir));
      if (parentDir.existsSync()) parentDir.deleteSync(recursive: true);
    });

    test("migrates legacy character files with checkoutRef", () async {
      final charFile = File(p.join(sourceDir, "char-1.json"));
      charFile.createSync(recursive: true);
      charFile.writeAsStringSync(
        jsonEncode(
          _legacyCharacterJson(
            "char-1",
            bundleId: "Serenity-21.06-EQUINOX",
            bundleSnapshot: "abc123",
          ),
        ),
      );

      const migrater = MigrateCharacters();
      final result = await migrater.migrate(
        sourceCharactersPath: sourceDir,
        destinationCharactersPath: destDir,
      );

      expect(result.migrated, 1);
      expect(result.skipped, 0);
      expect(result.errors, 0);

      final destFile = File(p.join(destDir, "char-1.json"));
      expect(destFile.existsSync(), isTrue);
      final content = jsonDecode(destFile.readAsStringSync()) as Map<String, dynamic>;
      final cr = content["checkoutRef"] as Map<String, dynamic>;
      expect(cr["checkoutId"], "abc123");
      expect(content.containsKey("bundleId"), isFalse);
      expect(content.containsKey("bundleSnapshot"), isFalse);
    });

    test("skips files already having checkoutRef", () async {
      final charFile = File(p.join(sourceDir, "char-migrated.json"));
      charFile.createSync(recursive: true);
      charFile.writeAsStringSync(jsonEncode(_migratedCharacterJson("char-migrated")));

      const migrater = MigrateCharacters();
      final result = await migrater.migrate(
        sourceCharactersPath: sourceDir,
        destinationCharactersPath: destDir,
      );

      expect(result.migrated, 0);
      expect(result.skipped, 1);
      expect(result.errors, 0);

      // Non-migrated file is not copied to destination
      final destFile = File(p.join(destDir, "char-migrated.json"));
      expect(destFile.existsSync(), isFalse);
    });

    test("skips non-json files", () async {
      final textFile = File(p.join(sourceDir, "notes.txt"));
      textFile.createSync(recursive: true);
      textFile.writeAsStringSync("not a character");

      const migrater = MigrateCharacters();
      final result = await migrater.migrate(
        sourceCharactersPath: sourceDir,
        destinationCharactersPath: destDir,
      );

      expect(result.migrated, 0);
      expect(result.skipped, 0);
      expect(result.errors, 0);
    });

    test("skips registry.json", () async {
      final regFile = File(p.join(sourceDir, "registry.json"));
      regFile.createSync(recursive: true);
      final originalJson = jsonEncode(
        _legacyCharacterJson("reg-char", bundleSnapshot: "should-skip"),
      );
      regFile.writeAsStringSync(originalJson);

      const migrater = MigrateCharacters();
      final result = await migrater.migrate(
        sourceCharactersPath: sourceDir,
        destinationCharactersPath: destDir,
      );

      expect(result.migrated, 0);
      expect(result.skipped, 0);
      expect(result.errors, 0);

      // registry.json must remain untouched on disk in source
      expect(regFile.readAsStringSync(), originalJson);
      // registry.json is not copied to destination
      final destRegFile = File(p.join(destDir, "registry.json"));
      expect(destRegFile.existsSync(), isFalse);
    });

    test("returns zero for non-existent source directory", () async {
      const migrater = MigrateCharacters();
      final result = await migrater.migrate(
        sourceCharactersPath: p.join(sourceDir, "nonexistent"),
        destinationCharactersPath: destDir,
      );

      expect(result.migrated, 0);
      expect(result.skipped, 0);
      expect(result.errors, 0);
    });

    test("migrates multiple legacy files", () async {
      for (var i = 0; i < 3; i++) {
        final f = File(p.join(sourceDir, "char-$i.json"));
        f.createSync(recursive: true);
        f.writeAsStringSync(jsonEncode(_legacyCharacterJson("char-$i", bundleSnapshot: "snap-$i")));
      }

      const migrater = MigrateCharacters();
      final result = await migrater.migrate(
        sourceCharactersPath: sourceDir,
        destinationCharactersPath: destDir,
      );

      expect(result.migrated, 3);
      expect(result.skipped, 0);
      expect(result.errors, 0);

      // All 3 files should be in destination
      for (var i = 0; i < 3; i++) {
        expect(File(p.join(destDir, "char-$i.json")).existsSync(), isTrue);
      }
    });

    test("mixed legacy and migrated files", () async {
      Directory(sourceDir).createSync(recursive: true);
      File(
        p.join(sourceDir, "char-old.json"),
      ).writeAsStringSync(jsonEncode(_legacyCharacterJson("old", bundleSnapshot: "old-snap")));
      File(
        p.join(sourceDir, "char-migrated.json"),
      ).writeAsStringSync(jsonEncode(_migratedCharacterJson("migrated")));

      const migrater = MigrateCharacters();
      final result = await migrater.migrate(
        sourceCharactersPath: sourceDir,
        destinationCharactersPath: destDir,
      );

      expect(result.migrated, 1);
      expect(result.skipped, 1);
      expect(result.errors, 0);

      // Only legacy file is in destination
      expect(File(p.join(destDir, "char-old.json")).existsSync(), isTrue);
      expect(File(p.join(destDir, "char-migrated.json")).existsSync(), isFalse);
    });
  });
}
