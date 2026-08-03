import "dart:async";
import "dart:convert";
import "package:eve_fit_assistant/compat/io.dart";
import "package:eve_fit_assistant/compat/isolate.dart";

import "package:eve_fit_assistant/features/app_update/models/app_version_state.dart";
import "package:path/path.dart" as p;

class AppVersionStateStore {
  AppVersionStateStore({required String settingsPath})
    : _filePath = p.join(settingsPath, _fileName);

  static const int _currentVersion = 1;
  static const String _fileName = "app_version_state.json";

  final String _filePath;
  late AppVersionState _state = AppVersionState.initial();
  Future<void> _pendingSync = Future<void>.value();

  File get _file => File(_filePath);

  Future<void> init() async {
    final filePath = _filePath;
    _state = await Isolate.run(() => _readFromDisk(filePath));
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

  static AppVersionState _readFromDisk(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        final text = file.readAsStringSync();
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
    final filePath = _file.path;
    final state = _state;
    _pendingSync = _pendingSync
        .catchError((Object _, StackTrace _) {})
        .then((_) => Isolate.run(() => _syncToDisk(filePath, state)));
  }

  static void _syncToDisk(String filePath, AppVersionState state) {
    final file = File(filePath);
    final text = jsonEncode(state.toJson());
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    file.writeAsStringSync(text);
  }
}
