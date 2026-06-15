import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/migrate_fits.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

Map<String, dynamic> _v2FitJson(String fitId, {String? bundleId, String? bundleSnapshot}) {
  final metadata = <String, dynamic>{
    "fitId": fitId,
    "shipTypeId": 1234,
    "name": "V2 Fit",
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

Map<String, dynamic> _v3FitJson(String fitId) => <String, dynamic>{
  "version": 3,
  "fit": <String, dynamic>{
    "metadata": <String, dynamic>{
      "fitId": fitId,
      "shipTypeId": 1234,
      "name": "V3 Fit",
      "lastModified": 200,
      "description": "",
      "checkoutRef": <String, dynamic>{
        "checkoutId": "checkout-xyz",
        "serverId": "Serenity",
        "metadata": <String, dynamic>{
          "gameServer": "Serenity",
          "gameBuild": "21.06",
          "gameVersion": "EQUINOX",
        },
      },
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
    late String tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync("efa_mig_fits_test_").path;
    });

    tearDown(() {
      final dir = Directory(tempDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test("migrates v2 fit files to v3", () async {
      final fitFile = File(p.join(tempDir, "fit-1.json"));
      fitFile.createSync(recursive: true);
      fitFile.writeAsStringSync(
        jsonEncode(
          _v2FitJson("fit-1", bundleId: "Serenity-21.06-EQUINOX", bundleSnapshot: "abc123"),
        ),
      );

      const migrater = MigrateFits();
      final result = await migrater.migrate(fittingsPath: tempDir);

      expect(result.migrated, 1);
      expect(result.skipped, 0);
      expect(result.errors, 0);

      final content = jsonDecode(fitFile.readAsStringSync()) as Map<String, dynamic>;
      expect(content["version"], 3);
      final metadata = content["fit"]["metadata"] as Map<String, dynamic>;
      final cr = metadata["checkoutRef"] as Map<String, dynamic>;
      expect(cr["checkoutId"], "abc123");
      expect(metadata.containsKey("bundleId"), isFalse);
      expect(metadata.containsKey("bundleSnapshot"), isFalse);
    });

    test("skips v3 fit files", () async {
      final fitFile = File(p.join(tempDir, "fit-v3.json"));
      fitFile.createSync(recursive: true);
      fitFile.writeAsStringSync(jsonEncode(_v3FitJson("fit-v3")));

      const migrater = MigrateFits();
      final result = await migrater.migrate(fittingsPath: tempDir);

      expect(result.migrated, 0);
      expect(result.skipped, 1);
      expect(result.errors, 0);
    });

    test("skips non-json files", () async {
      final textFile = File(p.join(tempDir, "notes.txt"));
      textFile.createSync(recursive: true);
      textFile.writeAsStringSync("not a fit");

      const migrater = MigrateFits();
      final result = await migrater.migrate(fittingsPath: tempDir);

      expect(result.migrated, 0);
      expect(result.skipped, 0);
      expect(result.errors, 0);
    });

    test("skips registry.json", () async {
      final regFile = File(p.join(tempDir, "registry.json"));
      regFile.createSync(recursive: true);
      final originalJson = jsonEncode(_v2FitJson("reg-fit", bundleSnapshot: "should-skip"));
      regFile.writeAsStringSync(originalJson);

      const migrater = MigrateFits();
      final result = await migrater.migrate(fittingsPath: tempDir);

      expect(result.migrated, 0);
      expect(result.skipped, 0);
      expect(result.errors, 0);

      // registry.json must remain untouched on disk
      expect(regFile.readAsStringSync(), originalJson);
    });

    test("returns zero for non-existent directory", () async {
      const migrater = MigrateFits();
      final result = await migrater.migrate(fittingsPath: p.join(tempDir, "nonexistent"));

      expect(result.migrated, 0);
      expect(result.skipped, 0);
      expect(result.errors, 0);
    });

    test("migrates multiple v2 files", () async {
      for (var i = 0; i < 3; i++) {
        final f = File(p.join(tempDir, "fit-$i.json"));
        f.createSync(recursive: true);
        f.writeAsStringSync(jsonEncode(_v2FitJson("fit-$i", bundleSnapshot: "snap-$i")));
      }

      const migrater = MigrateFits();
      final result = await migrater.migrate(fittingsPath: tempDir);

      expect(result.migrated, 3);
      expect(result.skipped, 0);
      expect(result.errors, 0);
    });

    test("mixed v2 and v3 files", () async {
      File(
        p.join(tempDir, "fit-old.json"),
      ).writeAsStringSync(jsonEncode(_v2FitJson("old", bundleSnapshot: "old-snap")));
      File(p.join(tempDir, "fit-new.json")).writeAsStringSync(jsonEncode(_v3FitJson("new")));

      const migrater = MigrateFits();
      final result = await migrater.migrate(fittingsPath: tempDir);

      expect(result.migrated, 1);
      expect(result.skipped, 1);
      expect(result.errors, 0);
    });
  });
}
