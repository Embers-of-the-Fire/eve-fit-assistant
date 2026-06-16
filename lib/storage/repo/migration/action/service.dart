import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/migrate_characters.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/migrate_fits.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/progress.dart";
import "package:eve_fit_assistant/storage/repo/schema_version.dart";
import "package:path/path.dart" as p;

class MigrateService {
  MigrateService({required this.schemaVersionService});

  final SchemaVersionService schemaVersionService;

  late final MigrateProgressStore store = const MigrateProgressStore();

  /// Runs all migration stages in dependency order asynchronously.
  ///
  /// Each stage writes a checkpoint after completion. If interrupted, calling
  /// [migrate] again resumes from the last completed stage.
  ///
  /// Returns the final [MigrateProgress] with all stages completed.
  Future<MigrateProgress> migrate() async {
    final progress = await store.load();

    if (progress.isComplete) return progress;

    return _continueAfter(progress);
  }

  Future<MigrateProgress> _continueAfter(MigrateProgress progress) async {
    // ── Stage 2: Fit migration ──────────────────────────────────────────────
    if (!progress.fitsCompleted) {
      info("Migration: migrating fits...");
      const migrater = MigrateFits();
      final result = await migrater.migrate(fittingsPath: PathProvider.fittingsPath);
      final hadErrors = result.errors > 0;
      final next = progress.copyWith(
        fitsCompleted: !hadErrors,
        fitsResult: result,
        hasError: hadErrors,
        lastError: hadErrors ? "Fit migration had ${result.errors} error(s)" : null,
      );
      if (!hadErrors) {
        _cleanFitRegistry();
      }
      await store.save(next);
      info(
        "Migration: fits done — ${result.migrated} migrated,"
        " ${result.skipped} skipped, ${result.errors} errors",
      );
      if (next.hasError) return next;
      return _continueAfter(next);
    }

    // ── Stage 3: Character migration ────────────────────────────────────────
    if (!progress.charactersCompleted) {
      info("Migration: migrating characters...");
      const migrater = MigrateCharacters();
      final result = await migrater.migrate(charactersPath: PathProvider.charactersPath);
      final hadErrors = result.errors > 0;
      final next = progress.copyWith(
        charactersCompleted: !hadErrors,
        charactersResult: result,
        hasError: hadErrors,
        lastError: hadErrors ? "Character migration had ${result.errors} error(s)" : null,
      );
      if (!hadErrors) {
        _cleanCharacterRegistry();
      }
      await store.save(next);
      info(
        "Migration: characters done — ${result.migrated} migrated,"
        " ${result.skipped} skipped, ${result.errors} errors",
      );
      if (next.hasError) return next;
      return _continueAfter(next);
    }

    // ── Stage 4: Finalize ───────────────────────────────────────────────────
    if (!progress.finalized) {
      info("Migration: finalizing...");
      _finalize();
      final next = progress.copyWith(
        finalized: true,
        completedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      await store.save(next);
      info("Migration: complete!");
      return next;
    }

    return progress;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Strips legacy fields (`bundleId`, `bundleSnapshot`) from fit registry
  /// entries so the detector won't flag them as leftover V2 data.
  void _cleanFitRegistry() {
    final file = File(p.join(PathProvider.fittingsPath, "registry.json"));
    if (!file.existsSync()) return;
    try {
      final content = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final registry = content["registry"];
      if (registry is Map<String, dynamic>) {
        final fits = registry["fits"];
        if (fits is Map<String, dynamic>) {
          for (final entry in fits.entries) {
            if (entry.value is Map<String, dynamic>) {
              (entry.value as Map<String, dynamic>)
                ..remove("bundleId")
                ..remove("bundleSnapshot");
            }
          }
        }
      }
      file.writeAsStringSync(jsonEncode(content));
      info("Migration: cleaned fit registry");
    } on Exception catch (e) {
      warning("Migration: failed to clean fit registry: $e");
    }
  }

  /// Strips legacy fields from character registry entries.
  void _cleanCharacterRegistry() {
    final file = File(p.join(PathProvider.charactersPath, "registry.json"));
    if (!file.existsSync()) return;
    try {
      final content = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final characters = content["characters"];
      if (characters is Map<String, dynamic>) {
        for (final entry in characters.entries) {
          if (entry.value is Map<String, dynamic>) {
            (entry.value as Map<String, dynamic>)
              ..remove("bundleId")
              ..remove("bundleSnapshot");
          }
        }
      }
      file.writeAsStringSync(jsonEncode(content));
      info("Migration: cleaned character registry");
    } on Exception catch (e) {
      warning("Migration: failed to clean character registry: $e");
    }
  }

  void _finalize() {
    schemaVersionService.ensure();
    _removeRuntimeDirectory();
  }

  /// Removes the stale runtime/v2/data/ directory copied by older migrations.
  void _removeRuntimeDirectory() {
    final dir = Directory(p.join(PathProvider.documentsPath, "runtime"));
    if (!dir.existsSync()) return;
    try {
      dir.deleteSync(recursive: true);
      info("Migration: removed stale runtime directory");
    } on FileSystemException catch (e) {
      warning("Migration: failed to remove runtime directory: $e");
    }
  }
}
