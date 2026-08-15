import "dart:typed_data";

import "package:eve_fit_assistant/storage/fs/blob_store.dart";

/// In-memory [BlobStore] backed by a map, for tests.
///
/// Paths are normalized (`\` → `/`) so Windows-style and POSIX-style keys
/// compare equal.
class MemoryBlobStore implements BlobStore {
  final Map<String, Uint8List> _files = {};

  static String _normalize(String path) => path.replaceAll(r"\", "/");

  @override
  Future<void> init() async {}

  @override
  Future<Uint8List?> read(String path) async => _files[_normalize(path)];

  @override
  Future<bool> exists(String path) async => _files.containsKey(_normalize(path));

  @override
  Future<void> write(String path, Uint8List bytes) async {
    _files[_normalize(path)] = bytes;
  }

  @override
  Future<void> delete(String path) async {
    _files.remove(_normalize(path));
  }

  @override
  Future<List<String>> list(String prefix) async {
    final norm = _normalize(prefix);
    final result = _files.keys.where((k) => k == norm || k.startsWith("$norm/")).toList()..sort();
    return result;
  }

  @override
  Future<void> deleteTree(String path) async {
    final norm = _normalize(path);
    _files.removeWhere((k, _) => k == norm || k.startsWith("$norm/"));
  }
}
