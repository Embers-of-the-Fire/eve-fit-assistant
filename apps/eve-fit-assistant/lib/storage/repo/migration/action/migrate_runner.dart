import "dart:convert";
import "package:eve_fit_assistant/compat/io.dart";

import "package:eve_fit_assistant/storage/repo/utils.dart";
import "package:path/path.dart" as p;

const _defaultBatchSize = 10;

typedef NeedsUpgrade = bool Function(Map<String, dynamic> json);
typedef Upgrade = Map<String, dynamic> Function(Map<String, dynamic> json);
typedef OnError = void Function(Object exception, String filePath);

/// Aggregated counts returned by [MigrateRunner].
typedef MigrateRunnerResult = ({int migrated, int skipped, int errors});

/// Shared async file-by-file migration runner.
///
/// Reads from sourceDirectory, writes migrated files to
/// destinationDirectory. Files that do not need upgrading are not copied.
///
/// Both `MigrateCharacters` and `MigrateFits` delegate I/O orchestration here
/// so that file listing, reads, and writes all run on the event loop without
/// synchronous stalls.
class MigrateRunner {
  const MigrateRunner._();

  /// Processes every JSON file (except `registry.json`) in [sourceDirectory].
  ///
  /// For each file:
  /// 1. Reads and parses JSON.
  /// 2. Calls [needsUpgrade] — returns `true` when the record should be
  ///    transformed.
  /// 3. When needed, calls [upgrade] to produce the new JSON and writes it
  ///    to the corresponding path under [destinationDirectory].
  ///
  /// Files that do not need upgrading are not copied to the destination.
  ///
  /// Yields to the event loop after every [batchSize] files (default 10) so
  /// that the UI stays responsive even with hundreds of files.
  static Future<MigrateRunnerResult> run({
    required String sourceDirectory,
    required String destinationDirectory,
    required NeedsUpgrade needsUpgrade,
    required Upgrade upgrade,
    OnError? onError,
    int batchSize = _defaultBatchSize,
  }) async {
    final dir = Directory(sourceDirectory);
    if (!dir.existsSync()) {
      return (migrated: 0, skipped: 0, errors: 0);
    }

    var migrated = 0;
    var skipped = 0;
    var errors = 0;

    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File &&
          p.extension(entity.path) == ".json" &&
          p.basename(entity.path) != "registry.json") {
        files.add(entity);
      }
    }

    for (var i = 0; i < files.length; i++) {
      final file = files[i];

      try {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;

        if (needsUpgrade(json)) {
          final upgraded = upgrade(json);
          final destFile = File(p.join(destinationDirectory, p.basename(file.path)));
          if (!destFile.parent.existsSync()) {
            destFile.parent.createSync(recursive: true);
          }
          await atomicWriteJson(destFile, upgraded);
          migrated++;
        } else {
          skipped++;
        }
      } on Exception catch (exception) {
        onError?.call(exception, file.path);
        errors++;
      }

      // Yield to the event loop after every batch to keep the UI responsive.
      if ((i + 1) % batchSize == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    return (migrated: migrated, skipped: skipped, errors: errors);
  }
}
