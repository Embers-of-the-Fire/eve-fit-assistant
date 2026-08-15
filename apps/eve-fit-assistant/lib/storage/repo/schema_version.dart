import "dart:convert";
import "dart:typed_data";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/fs/blob_store.dart";
import "package:eve_fit_assistant/storage/fs/repo_store.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/repo_version.dart";
import "package:fpdart/fpdart.dart";

/// Schema version marker for the repo storage system.
///
/// Writes `resources/v2/schema_version.json` with the current schema version
/// from [currentSchemaVersion] (auto-generated from project configuration).
/// The [ensure] method creates the file if absent.
class SchemaVersionService {
  SchemaVersionService([BlobStore? store]) : _store = store ?? createRepoBlobStore();

  final BlobStore _store;

  static const int _defaultSchemaVersion = currentSchemaVersion;

  /// Creates `schema_version.json` with the current schema version if it does not exist.
  ///
  /// The write is atomic and idempotent — calling this multiple times writes
  /// the file only once.
  Future<void> ensure() async {
    final path = RepoPaths.schemaVersionPath;
    if (await _store.exists(path)) return;

    try {
      await _store.write(
        path,
        Uint8List.fromList(utf8.encode(jsonEncode({"schemaVersion": _defaultSchemaVersion}))),
      );
    } catch (e, stackTrace) {
      warning("Failed to write schema_version.json", stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Returns `true` when `schema_version.json` is present in the store
  /// regardless of whether its contents are valid.
  Future<bool> exists() => _store.exists(RepoPaths.schemaVersionPath);

  /// Parses `schema_version.json` and returns the schemaVersion, or [None] if
  /// the file is missing or unreadable.
  Future<Option<int>> read() async {
    final bytes = await _store.read(RepoPaths.schemaVersionPath);
    if (bytes == null) return const None();
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final version = json["schemaVersion"];
      if (version is int) return Some(version);
      return const None();
    } on Exception catch (e, stackTrace) {
      warning("Failed to read schema_version.json", stackTrace: stackTrace);
      return const None();
    }
  }
}
