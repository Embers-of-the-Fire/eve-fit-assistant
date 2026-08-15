@TestOn("vm")
library;

import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/migrate_fits.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

Map<String, dynamic> _legacyFitJson(String fitId, {String? bundleId, String? bundleSnapshot}) {
  final metadata = <String, dynamic>{
    "fitId": fitId,
    "shipTypeId": 1234,
    "name": "Legacy Fit",
    "lastModified": 100,
    "description": "",
  };
  if (bundleId != null) metadata["bundleId"] = bundleId;
  if (bundleSnapshot != null) metadata["bundleSnapshot"] = bundleSnapshot;

  return <String, dynamic>{
    "version": 2,
    "fit": <String, dynamic>{
      "metadata": metadata,
      "body": <String, dynamic>{
        "shipTypeId": 1234,
        "characterId": "predefined_all_5",
        "damageProfile": <String, dynamic>{
          "em": 0.25,
          "explosive": 0.25,
          "kinetic": 0.25,
          "thermal": 0.25,
        },
        "slots": <String, dynamic>{
          "high": <Map<String, dynamic>>[],
          "medium": <Map<String, dynamic>>[],
          "low": <Map<String, dynamic>>[],
          "rig": <Map<String, dynamic>>[],
          "subsystem": <Map<String, dynamic>>[],
          "service": <Map<String, dynamic>>[],
        },
        "drones": <Map<String, dynamic>>[],
        "fighters": <Map<String, dynamic>>[],
        "implants": <Map<String, dynamic>>[],
        "boosters": <Map<String, dynamic>>[],
      },
      "dynamicRegistry": <String, dynamic>{"dynamicItems": <String, dynamic>{}},
    },
  };
}

Map<String, dynamic> _migratedFitJson(String fitId) => <String, dynamic>{
  "version": 2,
  "fit": <String, dynamic>{
    "metadata": <String, dynamic>{
      "fitId": fitId,
      "shipTypeId": 1234,
      "name": "Migrated Fit",
      "lastModified": 200,
      "description": "",
      "checkoutRef": <String, dynamic>{"checkoutId": "checkout-xyz", "serverId": "Serenity"},
    },
    "body": <String, dynamic>{
      "shipTypeId": 1234,
      "characterId": "predefined_all_5",
      "damageProfile": <String, dynamic>{
        "em": 0.25,
        "explosive": 0.25,
        "kinetic": 0.25,
        "thermal": 0.25,
      },
      "slots": <String, dynamic>{
        "high": <Map<String, dynamic>>[],
        "medium": <Map<String, dynamic>>[],
        "low": <Map<String, dynamic>>[],
        "rig": <Map<String, dynamic>>[],
        "subsystem": <Map<String, dynamic>>[],
        "service": <Map<String, dynamic>>[],
      },
      "drones": <Map<String, dynamic>>[],
      "fighters": <Map<String, dynamic>>[],
      "implants": <Map<String, dynamic>>[],
      "boosters": <Map<String, dynamic>>[],
    },
    "dynamicRegistry": <String, dynamic>{"dynamicItems": <String, dynamic>{}},
  },
};

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_mig_fits_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  group("MigrateFits", () {
    late String sourceDir;
    late String destDir;

    setUp(() {
      final tempDir = Directory.systemTemp.createTempSync("efa_mig_fits_test_").path;
      sourceDir = p.join(tempDir, "source");
      destDir = p.join(tempDir, "dest");
    });

    tearDown(() {
      final parentDir = Directory(p.dirname(sourceDir));
      if (parentDir.existsSync()) parentDir.deleteSync(recursive: true);
    });

    test("migrates legacy fit files to version 2 with checkoutRef", () async {
      final fitFile = File(p.join(sourceDir, "fit-1.json"));
      fitFile.createSync(recursive: true);
      fitFile.writeAsStringSync(
        jsonEncode(
          _legacyFitJson("fit-1", bundleId: "Serenity-21.06-EQUINOX", bundleSnapshot: "abc123"),
        ),
      );

      const migrater = MigrateFits();
      final result = await migrater.migrate(
        sourceFittingsPath: sourceDir,
        destinationFittingsPath: destDir,
      );

      expect(result.migrated, 1);
      expect(result.skipped, 0);
      expect(result.errors, 0);

      final destFile = File(p.join(destDir, "fit-1.json"));
      expect(destFile.existsSync(), isTrue);
      final content = jsonDecode(destFile.readAsStringSync()) as Map<String, dynamic>;
      expect(content["version"], 2);
      final metadata = content["fit"]["metadata"] as Map<String, dynamic>;
      final cr = metadata["checkoutRef"] as Map<String, dynamic>;
      expect(cr["checkoutId"], "abc123");
      expect(metadata.containsKey("bundleId"), isFalse);
      expect(metadata.containsKey("bundleSnapshot"), isFalse);
    });

    test("skips files already having checkoutRef", () async {
      final fitFile = File(p.join(sourceDir, "fit-migrated.json"));
      fitFile.createSync(recursive: true);
      fitFile.writeAsStringSync(jsonEncode(_migratedFitJson("fit-migrated")));

      const migrater = MigrateFits();
      final result = await migrater.migrate(
        sourceFittingsPath: sourceDir,
        destinationFittingsPath: destDir,
      );

      expect(result.migrated, 0);
      expect(result.skipped, 1);
      expect(result.errors, 0);

      // Non-migrated file is not copied to destination
      final destFile = File(p.join(destDir, "fit-migrated.json"));
      expect(destFile.existsSync(), isFalse);
    });

    test("skips non-json files", () async {
      final textFile = File(p.join(sourceDir, "notes.txt"));
      textFile.createSync(recursive: true);
      textFile.writeAsStringSync("not a fit");

      const migrater = MigrateFits();
      final result = await migrater.migrate(
        sourceFittingsPath: sourceDir,
        destinationFittingsPath: destDir,
      );

      expect(result.migrated, 0);
      expect(result.skipped, 0);
      expect(result.errors, 0);
    });

    test("skips registry.json", () async {
      final regFile = File(p.join(sourceDir, "registry.json"));
      regFile.createSync(recursive: true);
      final originalJson = jsonEncode(_legacyFitJson("reg-fit", bundleSnapshot: "should-skip"));
      regFile.writeAsStringSync(originalJson);

      const migrater = MigrateFits();
      final result = await migrater.migrate(
        sourceFittingsPath: sourceDir,
        destinationFittingsPath: destDir,
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
      const migrater = MigrateFits();
      final result = await migrater.migrate(
        sourceFittingsPath: p.join(sourceDir, "nonexistent"),
        destinationFittingsPath: destDir,
      );

      expect(result.migrated, 0);
      expect(result.skipped, 0);
      expect(result.errors, 0);
    });

    test("migrates multiple legacy files", () async {
      for (var i = 0; i < 3; i++) {
        final f = File(p.join(sourceDir, "fit-$i.json"));
        f.createSync(recursive: true);
        f.writeAsStringSync(jsonEncode(_legacyFitJson("fit-$i", bundleSnapshot: "snap-$i")));
      }

      const migrater = MigrateFits();
      final result = await migrater.migrate(
        sourceFittingsPath: sourceDir,
        destinationFittingsPath: destDir,
      );

      expect(result.migrated, 3);
      expect(result.skipped, 0);
      expect(result.errors, 0);

      // All 3 files should be in destination
      for (var i = 0; i < 3; i++) {
        expect(File(p.join(destDir, "fit-$i.json")).existsSync(), isTrue);
      }
    });

    test("mixed legacy and migrated files", () async {
      Directory(sourceDir).createSync(recursive: true);
      File(
        p.join(sourceDir, "fit-old.json"),
      ).writeAsStringSync(jsonEncode(_legacyFitJson("old", bundleSnapshot: "old-snap")));
      File(
        p.join(sourceDir, "fit-migrated.json"),
      ).writeAsStringSync(jsonEncode(_migratedFitJson("migrated")));

      const migrater = MigrateFits();
      final result = await migrater.migrate(
        sourceFittingsPath: sourceDir,
        destinationFittingsPath: destDir,
      );

      expect(result.migrated, 1);
      expect(result.skipped, 1);
      expect(result.errors, 0);

      // Only legacy file is in destination
      expect(File(p.join(destDir, "fit-old.json")).existsSync(), isTrue);
      expect(File(p.join(destDir, "fit-migrated.json")).existsSync(), isFalse);
    });
  });
}
