import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:fpdart/fpdart.dart";

/// Schema version marker for the repo storage system.
///
/// Writes `resources/v2/schema_version.json` with `{"version": 2}`.
/// The [ensure] method creates the file if absent.
class SchemaVersionService {
  const SchemaVersionService();

  static const int _defaultVersion = 2;

  /// Creates `schema_version.json` with `{ "version": 2 }` if it does not exist.
  ///
  /// The write is atomic (write-to-tmp-then-rename) and idempotent — calling this
  /// multiple times writes the file only once.
  void ensure() {
    final path = RepoPaths.schemaVersionPath;
    final file = File(path);
    if (file.existsSync()) return;

    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    final tmp = File("$path.tmp");
    try {
      tmp
        ..writeAsStringSync(jsonEncode({"version": _defaultVersion}), flush: true)
        ..renameSync(path);
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to write schema_version.json", stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Parses `schema_version.json` and returns the version, or [None] if the file is
  /// missing or unreadable.
  Option<int> read() {
    final file = File(RepoPaths.schemaVersionPath);
    if (!file.existsSync()) return const None();
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final version = json["version"];
      if (version is int) return Some(version);
      return const None();
    } on Exception catch (e, stackTrace) {
      warning("Failed to read schema_version.json", stackTrace: stackTrace);
      return const None();
    }
  }
}
