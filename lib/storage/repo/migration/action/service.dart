import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/migrate_characters.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/migrate_fits.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/progress.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
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
        await _copyFitsToRuntime();
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
        await _copyCharactersToRuntime();
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

  Future<void> _copyFitsToRuntime() async {
    final src = Directory(PathProvider.fittingsPath);
    if (!await src.exists()) return;
    final dst = Directory(RepoPaths.runtimeFittingsPath);
    await _copyDirectoryContents(src, dst);
  }

  Future<void> _copyCharactersToRuntime() async {
    final src = Directory(PathProvider.charactersPath);
    if (!await src.exists()) return;
    final dst = Directory(RepoPaths.runtimeCharactersPath);
    await _copyDirectoryContents(src, dst);
  }

  Future<void> _copyDirectoryContents(Directory src, Directory dst) async {
    if (!await dst.exists()) await dst.create(recursive: true);
    await for (final entity in src.list()) {
      if (entity is File) {
        final targetPath = p.join(dst.path, p.basename(entity.path));
        final target = File(targetPath);
        if (!await target.exists()) {
          await entity.copy(targetPath);
        }
      }
    }
  }

  void _finalize() {
    // Write new schema_version.json with schemaVersion 1
    // (matches the new EFA V2 unified storage schema)
    schemaVersionService.ensure();
  }
}
