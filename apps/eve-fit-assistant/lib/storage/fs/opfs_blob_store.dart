import "dart:async";
import "dart:js_interop";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/fs/blob_store.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:flutter/foundation.dart";
import "package:web/web.dart" as web;

/// Web [BlobStore] backed by the Origin Private File System (OPFS).
///
/// Paths arrive in the same absolute-shaped form produced by `RepoPaths`
/// (rooted at the `resources/v2` placeholder prefix); the prefix is stripped
/// and the remainder navigated as OPFS directory segments. Writes use
/// `createWritable()`, whose swap-file semantics make each file write atomic
/// on stream close.
///
/// This file is only reachable through the `repo_store_web.dart` conditional
/// export and web tests — it must never enter the native compile graph.
class OpfsBlobStore implements BlobStore {
  OpfsBlobStore._();

  /// Fresh instance for web tests that need isolated state.
  @visibleForTesting
  factory OpfsBlobStore.forTest() => OpfsBlobStore._();

  /// Shared instance. Verification "isolates" run inline on web and must
  /// observe the same OPFS state, so all app code goes through this singleton.
  static final OpfsBlobStore instance = OpfsBlobStore._();

  web.FileSystemDirectoryHandle? _root;
  Future<void>? _initFuture;
  final Map<String, web.FileSystemDirectoryHandle> _dirCache = {};

  static final _separatorPattern = RegExp(r"[/\\]");

  @override
  Future<void> init() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    final storage = web.window.navigator.storage;
    _root = await storage.getDirectory().toDart;
    // Best-effort: ask the browser not to evict stored data under pressure.
    unawaited(
      storage.persist().toDart.then(
        (_) {},
        onError: (Object _) {
          debug("OPFS: storage.persist() request failed");
        },
      ),
    );
  }

  Future<web.FileSystemDirectoryHandle> get _rootReady async {
    await init();
    final root = _root;
    if (root == null) throw StateError("OPFS root directory unavailable");
    return root;
  }

  /// Splits [path] into OPFS-relative segments, stripping the well-known
  /// `resources/v2` prefix when present.
  ///
  /// The prefix is only stripped at a path boundary: a path like
  /// `/resources/v2foo/...` merely shares a string prefix and must not be
  /// remapped.
  List<String> _segments(String path) {
    var rel = path;
    final prefix = RepoPaths.schemaResourcesPath;
    if (rel == prefix || rel.startsWith("$prefix/")) {
      rel = rel.substring(prefix.length);
    }
    return rel.split(_separatorPattern).where((s) => s.isNotEmpty).toList();
  }

  static String _cacheKey(List<String> segments) => segments.join("/");

  /// Navigates to the directory at [segments] below the OPFS root.
  ///
  /// Returns `null` when any segment is missing and [create] is false.
  Future<web.FileSystemDirectoryHandle?> _getDir(
    List<String> segments, {
    required bool create,
  }) async {
    var current = await _rootReady;
    final walked = <String>[];
    for (final segment in segments) {
      walked.add(segment);
      final key = _cacheKey(walked);
      final cached = _dirCache[key];
      if (cached != null) {
        current = cached;
        continue;
      }
      try {
        current = await current
            .getDirectoryHandle(segment, web.FileSystemGetDirectoryOptions(create: create))
            .toDart;
      } catch (e) {
        if (_isNotFound(e)) return null;
        rethrow;
      }
      _dirCache[key] = current;
    }
    return current;
  }

  void _evictCacheUnder(List<String> segments) {
    final prefix = _cacheKey(segments);
    _dirCache.removeWhere(
      (key, _) => key == prefix || (prefix.isEmpty || key.startsWith("$prefix/")),
    );
  }

  @override
  Future<Uint8List?> read(String path) async {
    final segments = _segments(path);
    if (segments.isEmpty) return null;
    final dir = await _getDir(segments.sublist(0, segments.length - 1), create: false);
    if (dir == null) return null;
    final web.FileSystemFileHandle handle;
    try {
      handle = await dir.getFileHandle(segments.last).toDart;
    } catch (e) {
      if (_isNotFound(e)) return null;
      rethrow;
    }
    final file = await handle.getFile().toDart;
    final buffer = await file.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  @override
  Future<bool> exists(String path) async {
    final segments = _segments(path);
    if (segments.isEmpty) return false;
    final dir = await _getDir(segments.sublist(0, segments.length - 1), create: false);
    if (dir == null) return false;
    try {
      await dir.getFileHandle(segments.last).toDart;
      return true;
    } catch (e) {
      if (_isNotFound(e)) return false;
      rethrow;
    }
  }

  /// Returns the byte size of the file at [path], or `null` when it does not
  /// exist.
  ///
  /// Not part of the [BlobStore] contract; used by callers that must validate
  /// an existing OPFS copy without reading it.
  Future<int?> fileSize(String path) async {
    final segments = _segments(path);
    if (segments.isEmpty) return null;
    final dir = await _getDir(segments.sublist(0, segments.length - 1), create: false);
    if (dir == null) return null;
    final web.FileSystemFileHandle handle;
    try {
      handle = await dir.getFileHandle(segments.last).toDart;
    } catch (e) {
      if (_isNotFound(e)) return null;
      rethrow;
    }
    final file = await handle.getFile().toDart;
    return file.size;
  }

  @override
  Future<void> write(String path, Uint8List bytes) async {
    final segments = _segments(path);
    if (segments.isEmpty) {
      throw ArgumentError.value(path, "path", "Cannot write to the OPFS root");
    }
    final dir = await _getDir(segments.sublist(0, segments.length - 1), create: true);
    // create: true never returns null.
    final handle = await dir!
        .getFileHandle(segments.last, web.FileSystemGetFileOptions(create: true))
        .toDart;
    final writable = await handle.createWritable().toDart;
    try {
      await writable.write(bytes.toJS).toDart;
    } finally {
      await writable.close().toDart;
    }
  }

  @override
  Future<void> delete(String path) async {
    final segments = _segments(path);
    if (segments.isEmpty) return;
    final dir = await _getDir(segments.sublist(0, segments.length - 1), create: false);
    if (dir == null) return;
    try {
      await dir.removeEntry(segments.last).toDart;
    } catch (e) {
      if (!_isNotFound(e)) rethrow;
    }
  }

  @override
  Future<List<String>> list(String prefix) async {
    final segments = _segments(prefix);
    final dir = await _getDir(segments, create: false);
    if (dir == null) return const [];
    final result = <String>[];
    await _walk(dir, prefix, result);
    return result;
  }

  Future<void> _walk(web.FileSystemDirectoryHandle dir, String prefix, List<String> out) async {
    await for (final handle in _directoryEntries(dir)) {
      final childPath = "$prefix/${handle.name}";
      if (handle.kind == "directory") {
        await _walk(handle as web.FileSystemDirectoryHandle, childPath, out);
      } else {
        out.add(childPath);
      }
    }
  }

  @override
  Future<void> deleteTree(String path) async {
    final segments = _segments(path);
    if (segments.isEmpty) {
      throw ArgumentError.value(path, "path", "Cannot delete the OPFS root");
    }
    final parent = await _getDir(segments.sublist(0, segments.length - 1), create: false);
    if (parent == null) return;
    try {
      await parent.removeEntry(segments.last, web.FileSystemRemoveOptions(recursive: true)).toDart;
    } catch (e) {
      if (!_isNotFound(e)) rethrow;
    }
    _evictCacheUnder(segments);
  }
}

/// Whether [e] is a JS `DOMException` named `NotFoundError` (the OPFS signal
/// for a missing file or directory entry).
bool _isNotFound(Object e) {
  try {
    final js = e as JSObject;
    return js.isA<web.DOMException>() && (e as web.DOMException).name == "NotFoundError";
  } catch (_) {
    return false;
  }
}

/// Async-iterates the entries of [dir].
///
/// `package:web` 1.1.1 has no binding for `FileSystemDirectoryHandle.values()`,
/// so it is declared here on an augmenting extension type and the async
/// iterator protocol is driven manually.
Stream<web.FileSystemHandle> _directoryEntries(web.FileSystemDirectoryHandle dir) async* {
  final iterator = _OpfsIterableDirHandle(dir).values();
  while (true) {
    final result = await iterator.next().toDart;
    if (result.done.toDart) return;
    yield result.value;
  }
}

/// [web.FileSystemDirectoryHandle] augmented with the async-iterable
/// `values()` method.
extension type _OpfsIterableDirHandle(JSObject _) implements web.FileSystemDirectoryHandle {
  external _OpfsAsyncIterator values();
}

extension type _OpfsAsyncIterator._(JSObject _) implements JSObject {
  external JSPromise<_OpfsIteratorResult> next();
}

extension type _OpfsIteratorResult._(JSObject _) implements JSObject {
  external JSBoolean get done;
  external web.FileSystemHandle get value;
}
