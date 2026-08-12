import "dart:async";
import "dart:convert";

import "package:eve_fit_assistant/features/announcements/models/announcement_state.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_store.dart";
import "package:eve_fit_assistant/storage/fs/doc_store.dart";

/// Legacy fields extracted from an older `announcement_state.json` that now
/// live in `AppVersionState`. Returned from [AnnouncementStateStore.init] so
/// the caller can apply them to the new [AppVersionStateStore].
typedef AnnouncementStateMigration = ({
  String? lastSeenAppVersion,
  String? lastAcknowledgedReleaseId,
});

class AnnouncementStateStore {
  // ignore: prefer_initializing_formals
  AnnouncementStateStore({required DocStore store}) : _store = store;

  static const int _currentVersion = 3;
  static const String _key = "announcement_state.json";
  static const String _legacyKey = "document_storage.json";

  final DocStore _store;
  late AnnouncementState _state = AnnouncementState.initial();
  Future<void> _pendingSync = Future<void>.value();

  /// Load state from the store. Returns a non-null [AnnouncementStateMigration]
  /// when the stored document contained version fields that must be applied to
  /// the new `AppVersionStateStore` (one-time, in-place migration).
  Future<AnnouncementStateMigration?> init() async {
    final result = await _readFromStore();
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

  Future<({AnnouncementState state, AnnouncementStateMigration? migration})>
  _readFromStore() async {
    try {
      final text = await _store.read(_key);
      if (text != null) {
        final json = jsonDecode(text) as Map<String, dynamic>;
        return _parseStateJson(json);
      }

      final legacy = await _tryReadLegacyState();
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

  Future<({AnnouncementState state, AnnouncementStateMigration? migration})?>
  _tryReadLegacyState() async {
    try {
      final text = await _store.read(_legacyKey);
      if (text == null) return null;

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
    final state = _state;
    _pendingSync = _pendingSync
        .catchError((Object _, StackTrace _) {})
        .then((_) => _store.write(_key, jsonEncode(state.toJson())));
  }
}
