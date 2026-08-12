import "dart:async";
import "dart:convert";

import "package:eve_fit_assistant/features/app_update/models/app_version_state.dart";
import "package:eve_fit_assistant/storage/fs/doc_store.dart";

class AppVersionStateStore {
  // ignore: prefer_initializing_formals
  AppVersionStateStore({required DocStore store}) : _store = store;

  static const int _currentVersion = 1;
  static const String _key = "app_version_state.json";

  final DocStore _store;
  late AppVersionState _state = AppVersionState.initial();
  Future<void> _pendingSync = Future<void>.value();

  Future<void> init() async {
    _state = await _readFromStore();
    _sync();
  }

  AppVersionState get state => _state;

  String? get lastSeenAppVersion => _state.lastSeenAppVersion;

  String? get lastAcknowledgedReleaseId => _state.lastAcknowledgedReleaseId;

  void setLastSeenAppVersion(String version) {
    if (_state.lastSeenAppVersion == version) return;
    _state = _state.copyWith(lastSeenAppVersion: version);
    _sync();
  }

  void acknowledgeRelease(String releaseId) {
    if (_state.lastAcknowledgedReleaseId == releaseId) return;
    _state = _state.copyWith(lastAcknowledgedReleaseId: releaseId);
    _sync();
  }

  void clearReleaseAcknowledgment() {
    if (_state.lastAcknowledgedReleaseId == null) return;
    _state = _state.copyWith(lastAcknowledgedReleaseId: null);
    _sync();
  }

  Future<void> get ensureSynced => _pendingSync;

  void replaceState(AppVersionState newState) {
    _state = newState;
    _sync();
  }

  Future<AppVersionState> _readFromStore() async {
    try {
      final text = await _store.read(_key);
      if (text != null) {
        final json = jsonDecode(text) as Map<String, dynamic>;
        final state = AppVersionState.fromJson(json);
        return _migrate(state);
      }
      return _migrate(AppVersionState.initial());
    } on Object {
      return _migrate(AppVersionState.initial());
    }
  }

  static AppVersionState _migrate(AppVersionState old) =>
      old.copyWith(schemaVersion: _currentVersion);

  void _sync() {
    final state = _state;
    _pendingSync = _pendingSync
        .catchError((Object _, StackTrace _) {})
        .then((_) => _store.write(_key, jsonEncode(state.toJson())));
  }
}
