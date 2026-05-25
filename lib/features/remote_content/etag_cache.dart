import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:path/path.dart" as p;

/// Persisted cache of ETag and Last-Modified values keyed by URL.
///
/// Enables conditional requests (If-None-Match / If-Modified-Since)
/// to avoid re-downloading unchanged remote content.
class EtagCache {
  EtagCache._();

  static const String _fileName = "etag_cache.json";
  static late Map<String, _EtagEntry> _entries;
  static Future<void> _pendingSync = Future<void>.value();

  static File get _file => File(p.join(PathProvider.settingsPath, _fileName));

  static void init() {
    _entries = _readFromDisk();
  }

  static String? getEtag(Uri uri) => _entries[uri.toString()]?.etag;

  static String? getLastModified(Uri uri) => _entries[uri.toString()]?.lastModified;

  static void update(Uri uri, {String? etag, String? lastModified}) {
    final key = uri.toString();
    final existing = _entries[key];
    if (existing != null &&
        existing.etag == (etag ?? existing.etag) &&
        existing.lastModified == (lastModified ?? existing.lastModified)) {
      return;
    }
    _entries[key] = _EtagEntry(
      etag: etag ?? existing?.etag,
      lastModified: lastModified ?? existing?.lastModified,
    );
    _sync();
  }

  static void remove(Uri uri) {
    if (_entries.remove(uri.toString()) != null) {
      _sync();
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
          );
        }
      }
      return entries;
    } on Object {
      return {};
    }
  }

  static void _sync() {
    final filePath = _file.path;
    final entries = Map<String, Map<String, dynamic>>.fromEntries(
      _entries.entries.map((e) => MapEntry<String, Map<String, dynamic>>(e.key, e.value.toJson())),
    );
    final text = jsonEncode(entries);
    _pendingSync = _pendingSync.catchError((Object _, StackTrace _) {}).then((_) async {
      final file = File(filePath);
      if (!file.existsSync()) {
        file.createSync(recursive: true);
      }
      await file.writeAsString(text);
    });
  }
}

class _EtagEntry {
  const _EtagEntry({this.etag, this.lastModified});

  final String? etag;
  final String? lastModified;

  Map<String, dynamic> toJson() => {
    if (etag != null) "etag": etag,
    if (lastModified != null) "lastModified": lastModified,
  };
}
