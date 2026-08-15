import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/storage/fs/blob_store.dart";

/// Native [BlobStore] backed by `dart:io` files.
///
/// Paths are used as-is (absolute filesystem paths produced by `RepoPaths`).
/// Writes go through a `.tmp` sibling file + rename for atomicity.
///
/// This file is only reachable through the `repo_store_io.dart` conditional
/// export and VM tests — it must never enter the web production compile graph
/// (dart2wasm rejects `dart:io`).
class FileBlobStore implements BlobStore {
  @override
  Future<void> init() async {}

  @override
  Future<Uint8List?> read(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      return file.readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<bool> exists(String path) async => File(path).existsSync();

  @override
  Future<void> write(String path, Uint8List bytes) async {
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final tmp = File("$path.tmp");
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(path);
  }

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // best-effort
    }
  }

  @override
  Future<List<String>> list(String prefix) async {
    final dir = Directory(prefix);
    if (!dir.existsSync()) return const [];
    final result = <String>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) result.add(entity.path);
    }
    return result;
  }

  @override
  Future<void> deleteTree(String path) async {
    final dir = Directory(path);
    try {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    } on FileSystemException {
      // best-effort
    }
    // Also handle the case where [path] is a file, not a directory.
    final file = File(path);
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // best-effort
    }
  }
}
