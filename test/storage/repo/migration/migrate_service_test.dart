import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/migrate_characters.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/migrate_fits.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/progress.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/service.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/schema_version.dart";
import "package:eve_fit_assistant/storage/repo/utils.dart";
import "package:path/path.dart" as p;
import "package:test/test.dart";

Map<String, dynamic> _v2FitJson(String fitId, {String? bundleSnapshot}) {
  final metadata = <String, dynamic>{
    "fitId": fitId,
    "shipTypeId": 1234,
    "name": "V2 Fit",
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

Map<String, dynamic> _v2CharacterJson(String characterId, {String? bundleSnapshot}) {
  final json = <String, dynamic>{
    "characterId": characterId,
    "name": "V2 Character",
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
    late String tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync("efa_mig_service_test_").path;
      PathProvider.documentsPath = tempDir;
      // Clean up any stale checkpoint from prior runs.
      final checkpoint = File(p.join(tempDir, "resources", "v2", ".migration_progress.json"));
      if (checkpoint.existsSync()) checkpoint.deleteSync();
      final schemaFile = File(p.join(tempDir, "resources", "v2", "schema_version.json"));
      if (schemaFile.existsSync()) schemaFile.deleteSync();
    });

    tearDown(() {
      final dir = Directory(tempDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test("fresh migration — runs all stages, finalizes, writes schema version", () async {
      final fittingsPath = p.join(tempDir, "fittings");
      final charactersPath = p.join(tempDir, "characters");
      Directory(fittingsPath).createSync(recursive: true);
      Directory(charactersPath).createSync(recursive: true);

      final fitFile = File(p.join(fittingsPath, "fit-1.json"));
      fitFile.writeAsStringSync(jsonEncode(_v2FitJson("fit-1", bundleSnapshot: "abc123")));

      final charFile = File(p.join(charactersPath, "char-1.json"));
      charFile.writeAsStringSync(jsonEncode(_v2CharacterJson("char-1", bundleSnapshot: "abc123")));

      final service = MigrateService(schemaVersionService: const SchemaVersionService());
      final progress = await service.migrate();

      expect(progress.isComplete, isTrue);
      expect(progress.fitsCompleted, isTrue);
      expect(progress.charactersCompleted, isTrue);
      expect(progress.finalized, isTrue);
      expect(progress.completedAt, isNotNull);
      expect(progress.fitsResult!.migrated, 1);
      expect(progress.charactersResult!.migrated, 1);

      final runtimeFit = File(p.join(tempDir, "runtime", "v2", "data", "fittings", "fit-1.json"));
      expect(runtimeFit.existsSync(), isTrue);
      final runtimeChar = File(
        p.join(tempDir, "runtime", "v2", "data", "characters", "char-1.json"),
      );
      expect(runtimeChar.existsSync(), isTrue);

      final schemaFile = File(p.join(tempDir, "resources", "v2", "schema_version.json"));
      expect(schemaFile.existsSync(), isTrue);
    });

    test("resumes from checkpoint after fits completed — skips fits, runs rest", () async {
      final charactersPath = p.join(tempDir, "characters");
      Directory(charactersPath).createSync(recursive: true);

      File(
        p.join(charactersPath, "char-1.json"),
      ).writeAsStringSync(jsonEncode(_v2CharacterJson("char-1", bundleSnapshot: "abc123")));

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

      final schemaFile = File(p.join(tempDir, "resources", "v2", "schema_version.json"));
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

    test("no legacy data — empty dirs complete with zero results", () async {
      final fittingsPath = p.join(tempDir, "fittings");
      final charactersPath = p.join(tempDir, "characters");
      Directory(fittingsPath).createSync(recursive: true);
      Directory(charactersPath).createSync(recursive: true);

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
    });

    test("no data dirs at all — still completes with zero results", () async {
      final service = MigrateService(schemaVersionService: const SchemaVersionService());
      final progress = await service.migrate();

      expect(progress.isComplete, isTrue);
      expect(progress.fitsCompleted, isTrue);
      expect(progress.fitsResult!.migrated, 0);
      expect(progress.charactersResult!.migrated, 0);
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
