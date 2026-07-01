import "dart:async";
import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:path/path.dart" as p;

/// Persisted cache of ETag, Last-Modified, and optional JSON payload keyed by
/// URL.
///
/// Enables conditional requests (If-None-Match / If-Modified-Since)
/// to avoid re-downloading unchanged remote content. The cached JSON payload
/// lets 304 responses be satisfied even when the caller no longer holds the
/// previous payload in memory.
///
/// Persistence is debounced and crash-safe: in-memory mutations schedule a
/// single coalesced write, which lands on disk via an atomic `tmp → rename`
/// so the cache file is never observed truncated or partially written.
class EtagCache {
  EtagCache._();

  static const String _fileName = "etag_cache.json";
  static const Duration _debounce = Duration(milliseconds: 200);

  static late Map<String, _EtagEntry> _entries;
  static bool _initialized = false;
  static Timer? _debounceTimer;
  static bool _dirty = false;

  static File get _file => File(p.join(PathProvider.settingsPath, _fileName));

  /// Loads the cache from disk. Idempotent: repeated calls do not overwrite
  /// the in-memory state.
  static void init() {
    if (_initialized) return;
    _entries = _readFromDisk();
    _initialized = true;
  }

  static String? getEtag(Uri uri) {
    _ensureInit();
    return _entries[uri.toString()]?.etag;
  }

  static String? getLastModified(Uri uri) {
    _ensureInit();
    return _entries[uri.toString()]?.lastModified;
  }

  static String? getPayload(Uri uri) {
    _ensureInit();
    return _entries[uri.toString()]?.payload;
  }

  static void update(Uri uri, {String? etag, String? lastModified, String? payload}) {
    _ensureInit();
    final key = uri.toString();
    final existing = _entries[key];
    if (existing != null &&
        existing.etag == (etag ?? existing.etag) &&
        existing.lastModified == (lastModified ?? existing.lastModified) &&
        existing.payload == (payload ?? existing.payload)) {
      return;
    }
    _entries[key] = _EtagEntry(
      etag: etag ?? existing?.etag,
      lastModified: lastModified ?? existing?.lastModified,
      payload: payload ?? existing?.payload,
    );
    _scheduleSync();
  }

  static void remove(Uri uri) {
    _ensureInit();
    if (_entries.remove(uri.toString()) != null) {
      _scheduleSync();
    }
  }

  static void clearAll() {
    _ensureInit();
    _entries.clear();
    _scheduleSync();
  }

  /// Forces any pending write to disk immediately and waits for it to complete.
  ///
  /// Callers that need to guarantee persistence (e.g. on app lifecycle pause)
  /// should await this.
  static Future<void> flush() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _flushNow();
  }

  static void _ensureInit() {
    if (!_initialized) {
      throw StateError("EtagCache not initialized. Call EtagCache.init() first.");
    }
  }

  static Map<String, _EtagEntry> _readFromDisk() {
    if (!_file.existsSync()) {
      return {};
    }
    try {
      final content = _file.readAsStringSync();
      final payload = jsonDecode(content);
      if (payload is! Map<String, dynamic>) {
        return {};
      }
      final entries = <String, _EtagEntry>{};
      for (final MapEntry<String, dynamic> entry in payload.entries) {
        if (entry.value is Map<String, dynamic>) {
          final value = entry.value as Map<String, dynamic>;
          entries[entry.key] = _EtagEntry(
            etag: value["etag"] as String?,
            lastModified: value["lastModified"] as String?,
            payload: value["payload"] as String?,
          );
        }
      }
      return entries;
    } on Object {
      return {};
    }
  }

  /// Marks the cache dirty and (re)arms the debounce timer. Rapid successive
  /// mutations coalesce into a single write.
  static void _scheduleSync() {
    _dirty = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      _debounceTimer = null;
      unawaited(_flushNow());
    });
  }

  static Future<void>? _pendingFlush;

  /// Serializes flush execution so overlapping calls (timer + explicit
  /// [flush]) never perform concurrent I/O. The write loop re-checks
  /// [_dirty] after every pass so mutations that arrive during I/O are
  /// captured before returning.
  static Future<void> _flushNow() async {
    if (_pendingFlush != null) {
      await _pendingFlush;
      if (_dirty) {
        await _flushNow();
      }
      return;
    }
    _pendingFlush = _writeLoop();
    await _pendingFlush;
    _pendingFlush = null;
    if (_dirty) {
      await _flushNow();
    }
  }

  /// Repeatedly persists to disk while dirty.  Because only one instance
  /// runs at a time (guarded by [_pendingFlush]), the final rename always
  /// carries the newest available state.
  static Future<void> _writeLoop() async {
    while (_dirty) {
      _dirty = false;

      final text = _serializeEntries();
      final filePath = _file.path;
      final file = File(filePath);
      final tmp = File("$filePath.tmp");

      try {
        if (!file.parent.existsSync()) {
          file.parent.createSync(recursive: true);
        }
        await tmp.writeAsString(text, flush: true);
        await tmp.rename(filePath);
      } on FileSystemException {
        _dirty = true;
        return;
      }
    }
  }

  static String _serializeEntries() {
    final entries = Map<String, Map<String, dynamic>>.fromEntries(
      _entries.entries.map((e) => MapEntry<String, Map<String, dynamic>>(e.key, e.value.toJson())),
    );
    return jsonEncode(entries);
  }
}

class _EtagEntry {
  const _EtagEntry({this.etag, this.lastModified, this.payload});

  final String? etag;
  final String? lastModified;
  final String? payload;

  Map<String, dynamic> toJson() => {
    if (etag != null) "etag": etag,
    if (lastModified != null) "lastModified": lastModified,
    if (payload != null) "payload": payload,
  };
}
