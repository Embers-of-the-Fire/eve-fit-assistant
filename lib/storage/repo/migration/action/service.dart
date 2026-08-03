import "dart:convert";
import "package:eve_fit_assistant/compat/io.dart";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/legacy_utils.dart";
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
  /// Stage 1 — Fit migration: reads from [{PathProvider.oldFittingsPath}],
  /// writes migrated files to [{PathProvider.fittingsPath}], then cleans the
  /// fit registry from the old path and writes the cleaned registry to the
  /// new path.
  ///
  /// Stage 2 — Character migration: same pattern for characters.
  ///
  /// Stage 3 — Finalize: writes `schema_version.json` via ensure, then
  /// recursively deletes old `fittings/` and `characters/` directories.
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
    // ── Stage 1: Fit migration ──────────────────────────────────────────────
    if (!progress.fitsCompleted) {
      info("Migration: migrating fits...");
      const migrater = MigrateFits();
      final result = await migrater.migrate(
        sourceFittingsPath: PathProvider.oldFittingsPath,
        destinationFittingsPath: PathProvider.fittingsPath,
      );
      final hadErrors = result.errors > 0;
      final next = progress.copyWith(
        fitsCompleted: !hadErrors,
        fitsResult: result,
        hasError: hadErrors,
        lastError: hadErrors ? "Fit migration had ${result.errors} error(s)" : null,
      );
      if (!hadErrors) {
        _cleanMigrateFitRegistry();
      }
      await store.save(next);
      info(
        "Migration: fits done — ${result.migrated} migrated,"
        " ${result.skipped} skipped, ${result.errors} errors",
      );
      if (next.hasError) return next;
      return _continueAfter(next);
    }

    // ── Stage 2: Character migration ────────────────────────────────────────
    if (!progress.charactersCompleted) {
      info("Migration: migrating characters...");
      const migrater = MigrateCharacters();
      final result = await migrater.migrate(
        sourceCharactersPath: PathProvider.oldCharactersPath,
        destinationCharactersPath: PathProvider.charactersPath,
      );
      final hadErrors = result.errors > 0;
      final next = progress.copyWith(
        charactersCompleted: !hadErrors,
        charactersResult: result,
        hasError: hadErrors,
        lastError: hadErrors ? "Character migration had ${result.errors} error(s)" : null,
      );
      if (!hadErrors) {
        _cleanMigrateCharacterRegistry();
      }
      await store.save(next);
      info(
        "Migration: characters done — ${result.migrated} migrated,"
        " ${result.skipped} skipped, ${result.errors} errors",
      );
      if (next.hasError) return next;
      return _continueAfter(next);
    }

    // ── Stage 3: Finalize ───────────────────────────────────────────────────
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

  // ── Registry cleaning ──────────────────────────────────────────────────────

  /// Reads the fit registry from the old path, injects a CheckoutRef, strips
  /// legacy fields, and writes to the new path.
  void _cleanMigrateFitRegistry() {
    final oldFile = File(p.join(PathProvider.oldFittingsPath, "registry.json"));
    if (!oldFile.existsSync()) return;
    try {
      final content = jsonDecode(oldFile.readAsStringSync()) as Map<String, dynamic>;
      final registry = content["registry"];
      if (registry is Map<String, dynamic>) {
        final fits = registry["fits"];
        if (fits is Map<String, dynamic>) {
          for (final entry in fits.entries) {
            if (entry.value is Map<String, dynamic>) {
              final record = entry.value as Map<String, dynamic>;
              if (record["checkoutRef"] == null &&
                  (record.containsKey("bundleSnapshot") || record.containsKey("bundleId"))) {
                final bundleSnapshot = record["bundleSnapshot"];
                final checkoutId = bundleSnapshot is String ? bundleSnapshot : "";
                final bundleId = record["bundleId"];
                final serverId = bundleId is String ? serverIdFromBundleId(bundleId) : "";
                record["checkoutRef"] = <String, dynamic>{
                  "checkoutId": checkoutId,
                  "serverId": serverId,
                };
              }
              record
                ..remove("bundleId")
                ..remove("bundleSnapshot");
            }
          }
        }
      }
      final newFile = File(p.join(PathProvider.fittingsPath, "registry.json"));
      newFile.parent.createSync(recursive: true);
      newFile.writeAsStringSync(jsonEncode(content));
      info("Migration: cleaned fit registry and wrote to new path");
    } on Exception catch (e) {
      warning("Migration: failed to clean fit registry: $e");
    }
  }

  /// Reads the character registry from the old path, injects a CheckoutRef,
  /// strips legacy fields, and writes to the new path.
  void _cleanMigrateCharacterRegistry() {
    final oldFile = File(p.join(PathProvider.oldCharactersPath, "registry.json"));
    if (!oldFile.existsSync()) return;
    try {
      final content = jsonDecode(oldFile.readAsStringSync()) as Map<String, dynamic>;
      final characters = content["characters"];
      if (characters is Map<String, dynamic>) {
        for (final entry in characters.entries) {
          if (entry.value is Map<String, dynamic>) {
            final record = entry.value as Map<String, dynamic>;
            if (record["checkoutRef"] == null &&
                (record.containsKey("bundleSnapshot") || record.containsKey("bundleId"))) {
              final bundleSnapshot = record["bundleSnapshot"];
              final checkoutId = bundleSnapshot is String ? bundleSnapshot : "";
              final bundleId = record["bundleId"];
              final serverId = bundleId is String ? serverIdFromBundleId(bundleId) : "";
              record["checkoutRef"] = <String, dynamic>{
                "checkoutId": checkoutId,
                "serverId": serverId,
              };
            }
            record
              ..remove("bundleId")
              ..remove("bundleSnapshot");
          }
        }
      }
      final newFile = File(p.join(PathProvider.charactersPath, "registry.json"));
      newFile.parent.createSync(recursive: true);
      newFile.writeAsStringSync(jsonEncode(content));
      info("Migration: cleaned character registry and wrote to new path");
    } on Exception catch (e) {
      warning("Migration: failed to clean character registry: $e");
    }
  }

  // ── Finalization ───────────────────────────────────────────────────────────

  void _finalize() {
    schemaVersionService.ensure();
    _deleteOldDirectories();
  }

  void _deleteOldDirectories() {
    for (final oldPath in [PathProvider.oldFittingsPath, PathProvider.oldCharactersPath]) {
      final dir = Directory(oldPath);
      if (!dir.existsSync()) continue;
      try {
        dir.deleteSync(recursive: true);
        info("Migration: removed old directory $oldPath");
      } on FileSystemException catch (e) {
        warning("Migration: failed to remove old directory $oldPath: $e");
      }
    }
  }
}
