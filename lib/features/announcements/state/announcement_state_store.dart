import "dart:async";
import "dart:convert";
import "package:eve_fit_assistant/compat/io.dart";
import "package:eve_fit_assistant/compat/isolate.dart";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/announcements/models/announcement_state.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_store.dart";
import "package:path/path.dart" as p;

/// Legacy fields extracted from an older `announcement_state.json` that now
/// live in `AppVersionState`. Returned from [AnnouncementStateStore.init] so
/// the caller can apply them to the new [AppVersionStateStore].
typedef AnnouncementStateMigration = ({
  String? lastSeenAppVersion,
  String? lastAcknowledgedReleaseId,
});

class AnnouncementStateStore {
  AnnouncementStateStore({required String settingsPath})
    : _filePath = p.join(settingsPath, _fileName),
      _legacyFilePath = p.join(settingsPath, "document_storage.json");

  static const int _currentVersion = 3;
  static const String _fileName = "announcement_state.json";

  final String _filePath;
  final String _legacyFilePath;
  late AnnouncementState _state = AnnouncementState.initial();
  Future<void> _pendingSync = Future<void>.value();

  File get _file => File(_filePath);

  /// Load state from disk. Returns a non-null [AnnouncementStateMigration]
  /// when the on-disk file contained version fields that must be applied to
  /// the new `AppVersionStateStore` (one-time, in-place migration).
  Future<AnnouncementStateMigration?> init() async {
    final filePath = _filePath;
    final legacyFilePath = _legacyFilePath;
    final result = await Isolate.run(() => _readFromDisk(filePath, legacyFilePath));
    _state = result.state;
    _sync();
    return result.migration;
  }

  AnnouncementState get state => _state;

  bool isRead(String id) => _state.readIds.contains(id);

  bool isDismissed(String id) => _state.dismissedIds.contains(id);

  void markRead(String id) {
    if (_state.readIds.contains(id)) return;
    _state = _state.copyWith(readIds: [..._state.readIds, id]);
    _sync();
  }

  void markAllRead(Iterable<String> ids) {
    final newIds = {..._state.readIds, ...ids};
    if (newIds.length == _state.readIds.length) return;
    _state = _state.copyWith(readIds: newIds.toList());
    _sync();
  }

  void markUnread(Iterable<String> ids) {
    final idSet = ids.toSet();
    if (!_state.readIds.any(idSet.contains)) return;
    _state = _state.copyWith(readIds: _state.readIds.where((id) => !idSet.contains(id)).toList());
    _sync();
  }

  void dismiss(String id) {
    if (_state.dismissedIds.contains(id)) return;
    _state = _state.copyWith(dismissedIds: [..._state.dismissedIds, id]);
    _sync();
  }

  Future<void> get ensureSynced => _pendingSync;

  void replaceState(AnnouncementState newState) {
    _state = newState;
    _sync();
  }

  /// Remove IDs from `readIds`/`dismissedIds` that are not in [activeIds].
  /// Called after a feed sync to keep state bounded.
  void pruneStaleIds({required Set<String> activeIds}) {
    final prunedRead = _state.readIds.where(activeIds.contains).toList();
    final prunedDismissed = _state.dismissedIds.where(activeIds.contains).toList();
    if (prunedRead.length == _state.readIds.length &&
        prunedDismissed.length == _state.dismissedIds.length) {
      return;
    }
    _state = _state.copyWith(readIds: prunedRead, dismissedIds: prunedDismissed);
    _sync();
  }

  static ({AnnouncementState state, AnnouncementStateMigration? migration}) _readFromDisk(
    String filePath,
    String legacyFilePath,
  ) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        final text = file.readAsStringSync();
        final json = jsonDecode(text) as Map<String, dynamic>;
        return _parseStateJson(json);
      }

      final legacy = _tryReadLegacyState(legacyFilePath);
      if (legacy != null) return legacy;

      return (
        state: AnnouncementState.initial().copyWith(schemaVersion: _currentVersion),
        migration: null,
      );
    } on Object {
      return (
        state: AnnouncementState.initial().copyWith(schemaVersion: _currentVersion),
        migration: null,
      );
    }
  }

  static ({AnnouncementState state, AnnouncementStateMigration? migration}) _parseStateJson(
    Map<String, dynamic> json,
  ) {
    final readIds =
        (json["readIds"] as List<dynamic>?)?.map((e) => e as String).toList() ?? <String>[];
    final dismissedIds =
        (json["dismissedIds"] as List<dynamic>?)?.map((e) => e as String).toList() ?? <String>[];
    final lastSeenAppVersion = json["lastSeenAppVersion"] as String?;
    final lastAcknowledgedReleaseId = json["lastAcknowledgedReleaseId"] as String?;

    final migration = (lastSeenAppVersion == null && lastAcknowledgedReleaseId == null)
        ? null
        : (
            lastSeenAppVersion: lastSeenAppVersion,
            lastAcknowledgedReleaseId: lastAcknowledgedReleaseId,
          );

    final state = AnnouncementState(
      schemaVersion: _currentVersion,
      readIds: readIds,
      dismissedIds: dismissedIds,
    );
    return (state: state, migration: migration);
  }

  static ({AnnouncementState state, AnnouncementStateMigration? migration})? _tryReadLegacyState(
    String legacyFilePath,
  ) {
    try {
      final legacyFile = File(legacyFilePath);
      if (!legacyFile.existsSync()) return null;

      final text = legacyFile.readAsStringSync();
      final json = jsonDecode(text) as Map<String, dynamic>;

      final readTimestamps = json["readTimestamps"] as Map<String, dynamic>?;
      final readIds = readTimestamps?.keys.toList() ?? <String>[];

      final dismissedIds =
          (json["dismissedStartupAnnouncementIds"] as List?)?.cast<String>().toList() ?? <String>[];

      final lastSeenAppVersion = json["lastSeenAppVersion"] as String?;

      final state = AnnouncementState(
        schemaVersion: _currentVersion,
        readIds: readIds,
        dismissedIds: dismissedIds,
      );
      final migration = lastSeenAppVersion == null
          ? null
          : (lastSeenAppVersion: lastSeenAppVersion, lastAcknowledgedReleaseId: null);
      return (state: state, migration: migration);
    } on Object {
      return null;
    }
  }

  void _sync() {
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

/// Default settings-path resolver used by `announcementStateStoreProvider`.
String defaultAnnouncementStateSettingsPath() => PathProvider.settingsPath;
