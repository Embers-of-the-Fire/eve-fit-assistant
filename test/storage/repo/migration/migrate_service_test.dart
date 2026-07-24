import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/legacy_utils.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/migrate_characters.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/migrate_fits.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/progress.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/service.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/schema_version.dart";
import "package:path/path.dart" as p;
import "package:test/test.dart";

Map<String, dynamic> _legacyFitJson(String fitId, {String? bundleSnapshot}) {
  final metadata = <String, dynamic>{
    "fitId": fitId,
    "shipTypeId": 1234,
    "name": "Legacy Fit",
    "lastModified": 100,
    "description": "",
    "bundleId": "Serenity-21.06-EQUINOX",
  };
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

Map<String, dynamic> _legacyCharacterJson(String characterId, {String? bundleSnapshot}) {
  final json = <String, dynamic>{
    "characterId": characterId,
    "name": "Legacy Character",
    "description": "",
    "lastModified": 100,
    "bundleId": "Serenity-21.06-EQUINOX",
    "skills": <String, dynamic>{"123": 5},
  };
  if (bundleSnapshot != null) json["bundleSnapshot"] = bundleSnapshot;
  return json;
}

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_mig_service_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  group("MigrateService", () {
    late String legacyDir;
    late String appSupportDir;

    setUp(() async {
      legacyDir = Directory.systemTemp.createTempSync("efa_mig_service_legacy_").path;
      appSupportDir = Directory.systemTemp.createTempSync("efa_mig_service_support_").path;
      PathProvider.documentsPath = legacyDir;
      PathProvider.appSupportPath = appSupportDir;
      // Clean up any stale checkpoint from prior runs.
      final checkpoint = File(p.join(RepoPaths.schemaResourcesPath, ".migration_progress.json"));
      if (checkpoint.existsSync()) checkpoint.deleteSync();
      final schemaFile = File(RepoPaths.schemaVersionPath);
      if (schemaFile.existsSync()) schemaFile.deleteSync();
    });

    tearDown(() {
      for (final path in [legacyDir, appSupportDir]) {
        final dir = Directory(path);
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });

    test("fresh migration — migrates files to runtime/v2/, deletes old dirs", () async {
      // Create legacy data in old paths
      final oldFittingsPath = PathProvider.oldFittingsPath;
      final oldCharactersPath = PathProvider.oldCharactersPath;
      expect(oldFittingsPath, startsWith(legacyDir));
      expect(oldCharactersPath, startsWith(legacyDir));
      Directory(oldFittingsPath).createSync(recursive: true);
      Directory(oldCharactersPath).createSync(recursive: true);

      final fitFile = File(p.join(oldFittingsPath, "fit-1.json"));
      fitFile.writeAsStringSync(jsonEncode(_legacyFitJson("fit-1", bundleSnapshot: "abc123")));

      final charFile = File(p.join(oldCharactersPath, "char-1.json"));
      charFile.writeAsStringSync(
        jsonEncode(_legacyCharacterJson("char-1", bundleSnapshot: "abc123")),
      );

      final service = MigrateService(schemaVersionService: const SchemaVersionService());
      final progress = await service.migrate();

      expect(progress.isComplete, isTrue);
      expect(progress.fitsCompleted, isTrue);
      expect(progress.charactersCompleted, isTrue);
      expect(progress.finalized, isTrue);
      expect(progress.completedAt, isNotNull);
      expect(progress.fitsResult!.migrated, 1);
      expect(progress.charactersResult!.migrated, 1);

      // Files written to new runtime/v2/ paths
      final newFittingsPath = PathProvider.fittingsPath;
      final newCharactersPath = PathProvider.charactersPath;
      expect(newFittingsPath, startsWith(appSupportDir));
      expect(newCharactersPath, startsWith(appSupportDir));
      expect(File(p.join(newFittingsPath, "fit-1.json")).existsSync(), isTrue);
      expect(File(p.join(newCharactersPath, "char-1.json")).existsSync(), isTrue);

      // Old directories are deleted
      expect(Directory(oldFittingsPath).existsSync(), isFalse);
      expect(Directory(oldCharactersPath).existsSync(), isFalse);

      // Schema version written
      final schemaFile = File(RepoPaths.schemaVersionPath);
      expect(schemaFile.existsSync(), isTrue);
    });

    test("fits are written with version 2 and checkoutRef at new path", () async {
      final oldFittingsPath = PathProvider.oldFittingsPath;
      Directory(oldFittingsPath).createSync(recursive: true);

      final fitFile = File(p.join(oldFittingsPath, "fit-1.json"));
      fitFile.writeAsStringSync(jsonEncode(_legacyFitJson("fit-1", bundleSnapshot: "abc123")));

      final service = MigrateService(schemaVersionService: const SchemaVersionService());
      await service.migrate();

      final newPath = File(p.join(PathProvider.fittingsPath, "fit-1.json"));
      final content = jsonDecode(newPath.readAsStringSync()) as Map<String, dynamic>;
      expect(content["version"], 2);
      final metadata = content["fit"]["metadata"] as Map<String, dynamic>;
      expect(metadata["checkoutRef"], isNotNull);
      expect(metadata.containsKey("bundleId"), isFalse);
      expect(metadata.containsKey("bundleSnapshot"), isFalse);
    });

    test("registry cleaning injects checkoutRef and writes to new path", () async {
      final oldFittingsPath = PathProvider.oldFittingsPath;
      Directory(oldFittingsPath).createSync(recursive: true);

      // Create legacy fit file
      File(
        p.join(oldFittingsPath, "fit-1.json"),
      ).writeAsStringSync(jsonEncode(_legacyFitJson("fit-1", bundleSnapshot: "abc123")));

      // Create legacy registry.json with bundleId/bundleSnapshot entries
      final legacyRegistry = <String, dynamic>{
        "version": 2,
        "registry": <String, dynamic>{
          "fits": <String, dynamic>{
            "fit-1": <String, dynamic>{
              "fitId": "fit-1",
              "shipTypeId": 1234,
              "name": "V2 Fit",
              "lastModified": 100,
              "description": "",
              "bundleId": "Serenity-21.06-EQUINOX",
              "bundleSnapshot": "abc123",
            },
          },
        },
      };
      File(p.join(oldFittingsPath, "registry.json")).writeAsStringSync(jsonEncode(legacyRegistry));

      final service = MigrateService(schemaVersionService: const SchemaVersionService());
      await service.migrate();

      // Registry cleaned and written to new path
      final newRegFile = File(p.join(PathProvider.fittingsPath, "registry.json"));
      expect(newRegFile.existsSync(), isTrue);
      final newReg = jsonDecode(newRegFile.readAsStringSync()) as Map<String, dynamic>;
      final fits = newReg["registry"]["fits"] as Map<String, dynamic>;
      final entry = fits["fit-1"] as Map<String, dynamic>;
      expect(entry["checkoutRef"], isNotNull);
      expect(entry["checkoutRef"]["checkoutId"], "abc123");
      expect(entry["checkoutRef"]["serverId"], "Serenity");
      expect(entry.containsKey("bundleId"), isFalse);
      expect(entry.containsKey("bundleSnapshot"), isFalse);
    });

    test("resumes from checkpoint after fits completed — skips fits, runs rest", () async {
      // Only create legacy characters data
      final oldCharactersPath = PathProvider.oldCharactersPath;
      Directory(oldCharactersPath).createSync(recursive: true);

      File(
        p.join(oldCharactersPath, "char-1.json"),
      ).writeAsStringSync(jsonEncode(_legacyCharacterJson("char-1", bundleSnapshot: "abc123")));

      const fitsResult = MigrateFitsResult(migrated: 99, skipped: 0, errors: 0);
      final partialProgress = const MigrateProgress(fitsCompleted: true, fitsResult: fitsResult);

      const store = MigrateProgressStore();
      await store.save(partialProgress);

      final service = MigrateService(schemaVersionService: const SchemaVersionService());
      final progress = await service.migrate();

      expect(progress.isComplete, isTrue);
      expect(progress.fitsCompleted, isTrue);
      expect(progress.fitsResult!.migrated, 99);
      expect(progress.charactersResult!.migrated, 1);
    });

    test("resumes from checkpoint after characters completed — skips to finalize", () async {
      const fitsResult = MigrateFitsResult(migrated: 1, skipped: 0, errors: 0);
      const charResult = MigrateCharactersResult(migrated: 2, skipped: 0, errors: 0);
      final partialProgress = const MigrateProgress(
        fitsCompleted: true,
        charactersCompleted: true,
        fitsResult: fitsResult,
        charactersResult: charResult,
      );

      const store = MigrateProgressStore();
      await store.save(partialProgress);

      final service = MigrateService(schemaVersionService: const SchemaVersionService());
      final progress = await service.migrate();

      expect(progress.isComplete, isTrue);
      expect(progress.fitsCompleted, isTrue);
      expect(progress.charactersCompleted, isTrue);
      expect(progress.finalized, isTrue);
      expect(progress.fitsResult!.migrated, 1);
      expect(progress.charactersResult!.migrated, 2);

      final schemaFile = File(RepoPaths.schemaVersionPath);
      expect(schemaFile.existsSync(), isTrue);
    });

    test("already complete — returns immediately without running stages", () async {
      const completeProgress = MigrateProgress(
        fitsCompleted: true,
        charactersCompleted: true,
        finalized: true,
      );
      const store = MigrateProgressStore();
      await store.save(completeProgress);

      final service = MigrateService(schemaVersionService: const SchemaVersionService());
      final progress = await service.migrate();

      expect(progress.isComplete, isTrue);
      expect(progress.fitsResult, isNull);
      expect(progress.charactersResult, isNull);
    });

    test("no legacy data — empty old dirs complete with zero results", () async {
      // Create empty old directories (but no files)
      Directory(PathProvider.oldFittingsPath).createSync(recursive: true);
      Directory(PathProvider.oldCharactersPath).createSync(recursive: true);

      final service = MigrateService(schemaVersionService: const SchemaVersionService());
      final progress = await service.migrate();

      expect(progress.isComplete, isTrue);
      expect(progress.fitsCompleted, isTrue);
      expect(progress.charactersCompleted, isTrue);
      expect(progress.finalized, isTrue);
      expect(progress.fitsResult!.migrated, 0);
      expect(progress.fitsResult!.skipped, 0);
      expect(progress.fitsResult!.errors, 0);
      expect(progress.charactersResult!.migrated, 0);
      expect(progress.charactersResult!.skipped, 0);
      expect(progress.charactersResult!.errors, 0);

      // Old empty dirs are deleted during finalize
      expect(Directory(PathProvider.oldFittingsPath).existsSync(), isFalse);
      expect(Directory(PathProvider.oldCharactersPath).existsSync(), isFalse);
    });

    test("no old data dirs at all — still completes with zero results", () async {
      final service = MigrateService(schemaVersionService: const SchemaVersionService());
      final progress = await service.migrate();

      expect(progress.isComplete, isTrue);
      expect(progress.fitsCompleted, isTrue);
      expect(progress.fitsResult!.migrated, 0);
      expect(progress.charactersResult!.migrated, 0);
    });

    test("character registry cleaning injects checkoutRef", () async {
      final oldCharactersPath = PathProvider.oldCharactersPath;
      Directory(oldCharactersPath).createSync(recursive: true);

      // Create legacy character file
      File(
        p.join(oldCharactersPath, "char-1.json"),
      ).writeAsStringSync(jsonEncode(_legacyCharacterJson("char-1", bundleSnapshot: "abc123")));

      // Create legacy character registry
      final legacyRegistry = <String, dynamic>{
        "characters": <String, dynamic>{
          "char-1": <String, dynamic>{
            "characterId": "char-1",
            "name": "V2 Character",
            "description": "",
            "lastModified": 100,
            "bundleId": "Serenity-21.06-EQUINOX",
            "bundleSnapshot": "abc123",
          },
        },
      };
      File(
        p.join(oldCharactersPath, "registry.json"),
      ).writeAsStringSync(jsonEncode(legacyRegistry));

      final service = MigrateService(schemaVersionService: const SchemaVersionService());
      await service.migrate();

      // Character registry cleaned and written to new path
      final newRegFile = File(p.join(PathProvider.charactersPath, "registry.json"));
      expect(newRegFile.existsSync(), isTrue);
      final newReg = jsonDecode(newRegFile.readAsStringSync()) as Map<String, dynamic>;
      final characters = newReg["characters"] as Map<String, dynamic>;
      final entry = characters["char-1"] as Map<String, dynamic>;
      expect(entry["checkoutRef"], isNotNull);
      expect(entry["checkoutRef"]["checkoutId"], "abc123");
      expect(entry["checkoutRef"]["serverId"], "Serenity");
      expect(entry.containsKey("bundleId"), isFalse);
      expect(entry.containsKey("bundleSnapshot"), isFalse);
    });
  });

  group("serverIdFromBundleId", () {
    test("extracts server name from bundle ID", () {
      expect(serverIdFromBundleId("Serenity-21.06-EQUINOX"), "Serenity");
    });

    test("works with multi-word server names", () {
      expect(serverIdFromBundleId("Tranquility-Test-21.06-EQUINOX"), "Tranquility-Test");
    });

    test("returns empty string for too-short input", () {
      expect(serverIdFromBundleId("short"), "");
      expect(serverIdFromBundleId("short-y"), "");
    });
  });
}
