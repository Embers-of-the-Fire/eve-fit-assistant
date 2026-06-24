import "dart:convert";
import "dart:io";
import "dart:isolate";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/feedback/feedback_state.dart";
import "package:path/path.dart" as p;

class FeedbackStateStore {
  FeedbackStateStore._();

  static const int _currentVersion = 1;
  static const String _fileName = "feedback_state.json";
  static late FeedbackState _state;
  static Future<void> _pendingSync = Future<void>.value();

  static File get _file => File(p.join(PathProvider.settingsPath, _fileName));

  static void init() {
    _state = _readFromDisk();
    _state = _state.copyWith(
      launchCount: _state.launchCount + 1,
      firstLaunchDate: _state.firstLaunchDate ?? DateTime.now(),
    );
    _sync();
  }

  static FeedbackState get state => _state;

  static void markFeedbackGiven() {
    if (_state.feedbackGiven) return;
    _state = _state.copyWith(feedbackGiven: true, lastPromptDate: DateTime.now());
    _sync();
  }

  static void dismiss() {
    _state = _state.copyWith(feedbackGiven: true, lastPromptDate: DateTime.now());
    _sync();
  }

  static void remindLater() {
    _state = _state.copyWith(
      remindedCount: _state.remindedCount + 1,
      lastPromptDate: DateTime.now(),
    );
    _sync();
  }

  static void setLastPromptDate(DateTime date) {
    _state = _state.copyWith(lastPromptDate: date);
    _sync();
  }

  static void resetForTesting() {
    _state = _state.copyWith(
      launchCount: 5,
      firstLaunchDate: DateTime.now().subtract(const Duration(days: 3)),
      lastPromptDate: null,
      remindedCount: 0,
      feedbackGiven: false,
    );
    _sync();
  }

  static Future<void> get ensureSynced => _pendingSync;

  static FeedbackState _readFromDisk() {
    try {
      if (_file.existsSync()) {
        final text = _file.readAsStringSync();
        final json = jsonDecode(text) as Map<String, dynamic>;
        final state = FeedbackState.fromJson(json);
        if (state.schemaVersion < _currentVersion) {
          return _migrate(state);
        }
        return state;
      }
      return FeedbackState.initial();
    } on Object {
      return FeedbackState.initial();
    }
  }

  static FeedbackState _migrate(FeedbackState old) => old.copyWith(schemaVersion: _currentVersion);

  static void _sync() {
    final filePath = _file.path;
    final state = _state;
    _pendingSync = _pendingSync
        .catchError((Object _, StackTrace _) {})
        .then((_) => Isolate.run(() => _syncToDisk(filePath, state)));
  }

  static void _syncToDisk(String filePath, FeedbackState state) {
    final file = File(filePath);
    final text = jsonEncode(state.toJson());
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    file.writeAsStringSync(text);
  }
}
