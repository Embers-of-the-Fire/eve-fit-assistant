import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/storage/repo/migration/action/migrate_characters.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/migrate_fits.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "progress.freezed.dart";
part "progress.g.dart";

@freezed
abstract class MigrateProgress with _$MigrateProgress {
  const factory MigrateProgress({
    @Default(false) bool fitsCompleted,
    @Default(false) bool charactersCompleted,
    @Default(false) bool finalized,

    MigrateFitsResult? fitsResult,
    MigrateCharactersResult? charactersResult,

    @Default(0) int startedAt,
    int? completedAt,
    @Default(false) bool hasError,
    String? lastError,
  }) = _MigrateProgress;

  const MigrateProgress._();

  factory MigrateProgress.fromJson(Map<String, dynamic> json) => _$MigrateProgressFromJson(json);

  bool get isComplete => fitsCompleted && charactersCompleted && finalized;

  MigrateProgress completeFits(MigrateFitsResult result) =>
      copyWith(fitsCompleted: true, fitsResult: result);

  MigrateProgress completeCharacters(MigrateCharactersResult result) =>
      copyWith(charactersCompleted: true, charactersResult: result);

  MigrateProgress completeFinalized() => copyWith(finalized: true);
}

/// Persists and loads migration progress checkpoints.
class MigrateProgressStore {
  const MigrateProgressStore();

  static String get _path => "${RepoPaths.schemaResourcesPath}/.migration_progress.json";

  /// Loads the checkpoint from disk asynchronously. Returns a fresh
  /// [MigrateProgress] if no checkpoint file exists or it is unreadable.
  Future<MigrateProgress> load() async {
    final file = File(_path);
    if (!await file.exists()) return MigrateProgress(startedAt: _now());
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return MigrateProgress.fromJson(json);
    } on Exception {
      return MigrateProgress(startedAt: _now());
    }
  }

  /// Writes [progress] to the checkpoint file atomically and asynchronously.
  Future<void> save(MigrateProgress progress) async {
    final path = _path;
    final file = File(path);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    final tmp = File("$path.tmp");
    await tmp.writeAsString(jsonEncode(progress.toJson()), flush: true);
    await tmp.rename(path);
  }

  /// Returns `true` when [load] yields a complete migration.
  Future<bool> isComplete() async {
    final progress = await load();
    return progress.isComplete;
  }

  /// Milliseconds since epoch UTC.
  static int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;
}
