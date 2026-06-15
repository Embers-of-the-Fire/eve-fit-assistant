import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/migrate_characters.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

Map<String, dynamic> _v2CharacterJson(
  String characterId, {
  String? bundleId,
  String? bundleSnapshot,
}) {
  final json = <String, dynamic>{
    "characterId": characterId,
    "name": "V2 Character",
    "description": "",
    "lastModified": 100,
    "skills": <String, dynamic>{"123": 5},
  };
  if (bundleId != null) json["bundleId"] = bundleId;
  if (bundleSnapshot != null) json["bundleSnapshot"] = bundleSnapshot;
  return json;
}

Map<String, dynamic> _v3CharacterJson(String characterId) => <String, dynamic>{
  "characterId": characterId,
  "name": "V3 Character",
  "description": "",
  "lastModified": 200,
  "checkoutRef": <String, dynamic>{
    "checkoutId": "checkout-xyz",
    "serverId": "Serenity",
    "metadata": <String, dynamic>{
      "gameServer": "Serenity",
      "gameBuild": "21.06",
      "gameVersion": "EQUINOX",
    },
  },
  "skills": <String, dynamic>{"456": 3},
};

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_mig_char_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  group("MigrateCharacters", () {
    late String tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync("efa_mig_char_test_").path;
    });

    tearDown(() {
      final dir = Directory(tempDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test("migrates v2 character files to v3", () async {
      final charFile = File(p.join(tempDir, "char-1.json"));
      charFile.createSync(recursive: true);
      charFile.writeAsStringSync(
        jsonEncode(
          _v2CharacterJson("char-1", bundleId: "Serenity-21.06-EQUINOX", bundleSnapshot: "abc123"),
        ),
      );

      const migrater = MigrateCharacters();
      final result = await migrater.migrate(charactersPath: tempDir);

      expect(result.migrated, 1);
      expect(result.skipped, 0);
      expect(result.errors, 0);

      final content = jsonDecode(charFile.readAsStringSync()) as Map<String, dynamic>;
      final cr = content["checkoutRef"] as Map<String, dynamic>;
      expect(cr["checkoutId"], "abc123");
      expect(content.containsKey("bundleId"), isFalse);
      expect(content.containsKey("bundleSnapshot"), isFalse);
    });

    test("skips v3 character files", () async {
      final charFile = File(p.join(tempDir, "char-v3.json"));
      charFile.createSync(recursive: true);
      charFile.writeAsStringSync(jsonEncode(_v3CharacterJson("char-v3")));

      const migrater = MigrateCharacters();
      final result = await migrater.migrate(charactersPath: tempDir);

      expect(result.migrated, 0);
      expect(result.skipped, 1);
      expect(result.errors, 0);
    });

    test("skips non-json files", () async {
      final textFile = File(p.join(tempDir, "notes.txt"));
      textFile.createSync(recursive: true);
      textFile.writeAsStringSync("not a character");

      const migrater = MigrateCharacters();
      final result = await migrater.migrate(charactersPath: tempDir);

      expect(result.migrated, 0);
      expect(result.skipped, 0);
      expect(result.errors, 0);
    });

    test("skips registry.json", () async {
      final regFile = File(p.join(tempDir, "registry.json"));
      regFile.createSync(recursive: true);
      final originalJson = jsonEncode(_v2CharacterJson("reg-char", bundleSnapshot: "should-skip"));
      regFile.writeAsStringSync(originalJson);

      const migrater = MigrateCharacters();
      final result = await migrater.migrate(charactersPath: tempDir);

      expect(result.migrated, 0);
      expect(result.skipped, 0);
      expect(result.errors, 0);

      // registry.json must remain untouched on disk
      expect(regFile.readAsStringSync(), originalJson);
    });

    test("returns zero for non-existent directory", () async {
      const migrater = MigrateCharacters();
      final result = await migrater.migrate(charactersPath: p.join(tempDir, "nonexistent"));

      expect(result.migrated, 0);
      expect(result.skipped, 0);
      expect(result.errors, 0);
    });

    test("migrates multiple v2 files", () async {
      for (var i = 0; i < 3; i++) {
        final f = File(p.join(tempDir, "char-$i.json"));
        f.createSync(recursive: true);
        f.writeAsStringSync(jsonEncode(_v2CharacterJson("char-$i", bundleSnapshot: "snap-$i")));
      }

      const migrater = MigrateCharacters();
      final result = await migrater.migrate(charactersPath: tempDir);

      expect(result.migrated, 3);
      expect(result.skipped, 0);
      expect(result.errors, 0);
    });

    test("mixed v2 and v3 files", () async {
      File(
        p.join(tempDir, "char-old.json"),
      ).writeAsStringSync(jsonEncode(_v2CharacterJson("old", bundleSnapshot: "old-snap")));
      File(p.join(tempDir, "char-new.json")).writeAsStringSync(jsonEncode(_v3CharacterJson("new")));

      const migrater = MigrateCharacters();
      final result = await migrater.migrate(charactersPath: tempDir);

      expect(result.migrated, 1);
      expect(result.skipped, 1);
      expect(result.errors, 0);
    });
  });
}
