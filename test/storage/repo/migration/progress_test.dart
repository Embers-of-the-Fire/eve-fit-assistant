import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/migrate_characters.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/migrate_fits.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/progress.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  group("MigrateProgress", () {
    group("fresh state", () {
      test("starts with all false", () {
        const progress = MigrateProgress();
        expect(progress.fitsCompleted, isFalse);
        expect(progress.charactersCompleted, isFalse);
        expect(progress.finalized, isFalse);
        expect(progress.isComplete, isFalse);
      });

      test("isComplete is false when any stage is incomplete", () {
        final progress = const MigrateProgress().copyWith(
          fitsCompleted: true,
          charactersCompleted: true,
        );
        expect(progress.isComplete, isFalse);
      });

      test("isComplete is true when all stages done", () {
        final progress = const MigrateProgress().copyWith(
          fitsCompleted: true,
          charactersCompleted: true,
          finalized: true,
        );
        expect(progress.isComplete, isTrue);
      });
    });

    group("completion methods", () {
      test("completeFits sets fitsCompleted and fitsResult", () {
        const fitsResult = MigrateFitsResult(migrated: 3, skipped: 1, errors: 0);
        final progress = const MigrateProgress().completeFits(fitsResult);
        expect(progress.fitsCompleted, isTrue);
        expect(progress.fitsResult, fitsResult);
        expect(progress.charactersCompleted, isFalse);
      });

      test("completeCharacters sets charactersCompleted and charactersResult", () {
        const charResult = MigrateCharactersResult(migrated: 2, skipped: 0, errors: 0);
        final progress = const MigrateProgress().completeCharacters(charResult);
        expect(progress.charactersCompleted, isTrue);
        expect(progress.charactersResult, charResult);
      });

      test("completeFinalized sets finalized", () {
        final progress = const MigrateProgress().completeFinalized();
        expect(progress.finalized, isTrue);
      });

      test("chain all completion methods", () {
        const fitsResult = MigrateFitsResult(migrated: 1, skipped: 0, errors: 0);
        const charResult = MigrateCharactersResult(migrated: 1, skipped: 0, errors: 0);

        final progress = const MigrateProgress()
            .completeFits(fitsResult)
            .completeCharacters(charResult)
            .completeFinalized();

        expect(progress.isComplete, isTrue);
        expect(progress.fitsResult, fitsResult);
        expect(progress.charactersResult, charResult);
      });
    });

    group("JSON serialisation", () {
      test("toJson produces valid JSON with all fields", () {
        const fitsResult = MigrateFitsResult(migrated: 3, skipped: 1, errors: 0);
        final progress = const MigrateProgress().completeFits(fitsResult);
        final json = progress.toJson();

        expect(json["fitsCompleted"], isTrue);
        expect(json["fitsResult"], isNotNull);
        expect(json["charactersCompleted"], isFalse);
        expect(json["finalized"], isFalse);
      });

      test("fromJson restores from raw map", () {
        final rawJson = <String, dynamic>{
          "fitsCompleted": true,
          "charactersCompleted": false,
          "finalized": false,
          "fitsResult": <String, dynamic>{"migrated": 5, "skipped": 0, "errors": 0},
          "startedAt": 0,
          "hasError": false,
        };

        final progress = MigrateProgress.fromJson(rawJson);
        expect(progress.fitsCompleted, isTrue);
        expect(progress.fitsResult!.migrated, 5);
        expect(progress.charactersCompleted, isFalse);
      });

      test("fromJson handles missing optional fields with defaults", () {
        final rawJson = <String, dynamic>{"fitsCompleted": true};
        final progress = MigrateProgress.fromJson(rawJson);
        expect(progress.fitsCompleted, isTrue);
        expect(progress.charactersCompleted, isFalse);
        expect(progress.finalized, isFalse);
        expect(progress.fitsResult, isNull);
      });
    });
  });

  group("MigrateProgressStore", () {
    late String tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync("efa_mig_progress_test_").path;
      PathProvider.documentsPath = tempDir;
      PathProvider.appSupportPath = tempDir;
    });

    tearDown(() {
      final dir = Directory(tempDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test("load returns default when checkpoint file does not exist", () async {
      const store = MigrateProgressStore();
      final progress = await store.load();
      expect(progress.fitsCompleted, isFalse);
      expect(progress.charactersCompleted, isFalse);
      expect(progress.finalized, isFalse);
      expect(progress.isComplete, isFalse);
      expect(progress.startedAt, greaterThan(0));
    });

    test("save and load round-trip all fields", () async {
      const store = MigrateProgressStore();

      const fitsResult = MigrateFitsResult(migrated: 3, skipped: 1, errors: 0);
      const charResult = MigrateCharactersResult(migrated: 2, skipped: 0, errors: 0);

      final progress = const MigrateProgress()
          .completeFits(fitsResult)
          .completeCharacters(charResult)
          .completeFinalized();

      await store.save(progress);

      final loaded = await store.load();
      expect(loaded.isComplete, isTrue);
      expect(loaded.fitsCompleted, isTrue);
      expect(loaded.charactersCompleted, isTrue);
      expect(loaded.finalized, isTrue);
      expect(loaded.fitsResult!.migrated, 3);
      expect(loaded.charactersResult!.migrated, 2);
    });

    test("partial progress save and load", () async {
      const store = MigrateProgressStore();

      const fitsResult = MigrateFitsResult(migrated: 1, skipped: 0, errors: 0);
      final progress = const MigrateProgress().completeFits(fitsResult);
      await store.save(progress);

      final loaded = await store.load();
      expect(loaded.fitsCompleted, isTrue);
      expect(loaded.charactersCompleted, isFalse);
      expect(loaded.finalized, isFalse);
    });

    test("load returns default on corrupt JSON without throwing", () async {
      const store = MigrateProgressStore();
      final v2Dir = p.join(PathProvider.documentsPath, "resources", "v2");
      Directory(v2Dir).createSync(recursive: true);
      final checkpointFile = File(p.join(v2Dir, ".migration_progress.json"));
      checkpointFile.writeAsStringSync("not valid json");

      final progress = await store.load();
      expect(progress.fitsCompleted, isFalse);
      expect(progress.startedAt, greaterThan(0));
    });

    test("save creates parent directories", () async {
      const store = MigrateProgressStore();
      final v2Dir = p.join(PathProvider.documentsPath, "resources", "v2");
      expect(Directory(v2Dir).existsSync(), isFalse);

      const progress = MigrateProgress();
      await store.save(progress);

      expect(Directory(v2Dir).existsSync(), isTrue);
      expect(File(p.join(v2Dir, ".migration_progress.json")).existsSync(), isTrue);
    });

    test("atomic write does not leave tmp file", () async {
      const store = MigrateProgressStore();
      await store.save(const MigrateProgress());

      final v2Dir = p.join(PathProvider.documentsPath, "resources", "v2");
      final tmpFile = File(p.join(v2Dir, ".migration_progress.json.tmp"));
      expect(tmpFile.existsSync(), isFalse);

      final checkpointFile = File(p.join(v2Dir, ".migration_progress.json"));
      expect(checkpointFile.existsSync(), isTrue);
    });

    test("isComplete returns false for incomplete progress", () async {
      const store = MigrateProgressStore();
      expect(await store.isComplete(), isFalse);

      final progress = const MigrateProgress(
        fitsCompleted: true,
        charactersCompleted: true,
        finalized: true,
      );
      await store.save(progress);
      expect(await store.isComplete(), isTrue);
    });

    test("startedAt timestamp is set on fresh load", () async {
      const store = MigrateProgressStore();
      final v2Dir = p.join(PathProvider.documentsPath, "resources", "v2");
      final checkpointFile = File(p.join(v2Dir, ".migration_progress.json"));
      if (checkpointFile.existsSync()) checkpointFile.deleteSync();

      final progress = await store.load();
      expect(progress.startedAt, greaterThan(0));
      expect(progress.startedAt, lessThanOrEqualTo(DateTime.now().toUtc().millisecondsSinceEpoch));
    });
  });
}
