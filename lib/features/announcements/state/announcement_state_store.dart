import "dart:convert";
import "dart:io";
import "dart:isolate";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/announcements/models/announcement_state.dart";
import "package:path/path.dart" as p;

class AnnouncementStateStore {
  AnnouncementStateStore._();

  static const int _currentVersion = 2;
  static const String _fileName = "announcement_state.json";
  static late AnnouncementState _state;
  static Future<void> _pendingSync = Future<void>.value();

  static File get _file => File(p.join(PathProvider.settingsPath, _fileName));

  static void init() {
    _state = _readFromDisk();
    _sync();
  }

  static AnnouncementState get state => _state;

  static bool isRead(String id) => _state.readIds.contains(id);

  static bool isDismissed(String id) => _state.dismissedIds.contains(id);

  static String? get lastSeenAppVersion => _state.lastSeenAppVersion;

  static String? get lastAcknowledgedReleaseId => _state.lastAcknowledgedReleaseId;

  static void markRead(String id) {
    if (_state.readIds.contains(id)) return;
    _state = _state.copyWith(readIds: [..._state.readIds, id]);
    _sync();
  }

  static void markAllRead(Iterable<String> ids) {
    final newIds = {..._state.readIds, ...ids};
    if (newIds.length == _state.readIds.length) return;
    _state = _state.copyWith(readIds: newIds.toList());
    _sync();
  }

  static void markUnread(Iterable<String> ids) {
    final idSet = ids.toSet();
    if (!_state.readIds.any(idSet.contains)) return;
    _state = _state.copyWith(readIds: _state.readIds.where((id) => !idSet.contains(id)).toList());
    _sync();
  }

  static void dismiss(String id) {
    if (_state.dismissedIds.contains(id)) return;
    _state = _state.copyWith(dismissedIds: [..._state.dismissedIds, id]);
    _sync();
  }

  static void setLastSeenAppVersion(String version) {
    if (_state.lastSeenAppVersion == version) return;
    _state = _state.copyWith(lastSeenAppVersion: version);
    _sync();
  }

  static void acknowledgeRelease(String releaseId) {
    if (_state.lastAcknowledgedReleaseId == releaseId) return;
    _state = _state.copyWith(lastAcknowledgedReleaseId: releaseId);
    _sync();
  }

  static Future<void> get ensureSynced => _pendingSync;

  static void replaceState(AnnouncementState newState) {
    _state = newState;
    _sync();
  }

  static AnnouncementState _readFromDisk() {
    try {
      if (_file.existsSync()) {
        final text = _file.readAsStringSync();
        final json = jsonDecode(text) as Map<String, dynamic>;
        final state = AnnouncementState.fromJson(json);
        return _migrate(state);
      }

      final legacyState = _tryReadLegacyState();
      if (legacyState != null) {
        final migrated = _migrate(legacyState);
        _sync();
        return migrated;
      }

      return _migrate(AnnouncementState.initial());
    } on Object {
      return _migrate(AnnouncementState.initial());
    }
  }

  static AnnouncementState? _tryReadLegacyState() {
    try {
      final legacyFile = File(p.join(PathProvider.settingsPath, "document_storage.json"));
      if (!legacyFile.existsSync()) return null;

      final text = legacyFile.readAsStringSync();
      final json = jsonDecode(text) as Map<String, dynamic>;

      final readTimestamps = json["readTimestamps"] as Map<String, dynamic>?;
      final readIds = readTimestamps?.keys.toList() ?? <String>[];

      final dismissedIds =
          (json["dismissedStartupAnnouncementIds"] as List?)?.cast<String>().toList() ?? <String>[];

      final lastSeenAppVersion = json["lastSeenAppVersion"] as String?;

      return AnnouncementState(
        readIds: readIds,
        dismissedIds: dismissedIds,
        lastSeenAppVersion: lastSeenAppVersion,
      );
    } on Object {
      return null;
    }
  }

  static AnnouncementState _migrate(AnnouncementState old) {
    if (old.schemaVersion < 2) {
      return old.copyWith(schemaVersion: 2);
    }
    return old.copyWith(schemaVersion: _currentVersion);
  }

  static void _sync() {
    final filePath = _file.path;
    final state = _state;
    _pendingSync = _pendingSync
        .catchError((Object _, StackTrace _) {})
        .then((_) => Isolate.run(() => _syncToDisk(filePath, state)));
  }

  static void _syncToDisk(String filePath, AnnouncementState state) {
    final file = File(filePath);
    final text = jsonEncode(state.toJson());
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    file.writeAsStringSync(text);
  }
}
