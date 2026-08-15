import "dart:io";

import "package:eve_fit_assistant/storage/fs/doc_store.dart";
import "package:path/path.dart" as p;

/// Native [DocStore] backed by one file per key under a root directory.
///
/// Writes go through a `.tmp` sibling file + rename for atomicity, matching
/// the persistence behavior the app historically used for user data. The I/O
/// itself is synchronous (small documents), which keeps fire-and-forget syncs
/// from racing async teardown; the interface stays async for the web backend.
///
/// This file is only reachable through the `user_store_io.dart` conditional
/// export and VM tests — it must never enter the web production compile graph
/// (dart2wasm rejects `dart:io`).
class FileDocStore implements DocStore {
  FileDocStore(this.rootPath);

  final String rootPath;

  String _path(String key) => p.join(rootPath, key);

  @override
  Future<void> init() async {
    final dir = Directory(rootPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  @override
  Future<String?> read(String key) async {
    final file = File(_path(key));
    if (!file.existsSync()) return null;
    try {
      return file.readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<bool> exists(String key) async => File(_path(key)).existsSync();

  @override
  Future<void> write(String key, String value) async {
    final path = _path(key);
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    File("$path.tmp")
      ..writeAsStringSync(value, flush: true)
      ..renameSync(path);
  }

  @override
  Future<void> delete(String key) async {
    final file = File(_path(key));
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // best-effort
    }
  }

  @override
  Future<List<String>> keys() async {
    final dir = Directory(rootPath);
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .where((name) => !name.endsWith(".tmp"))
        .toList();
  }
}
