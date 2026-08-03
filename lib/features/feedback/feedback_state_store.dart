import "dart:async";
import "dart:convert";

import "package:eve_fit_assistant/features/feedback/feedback_state.dart";
import "package:eve_fit_assistant/storage/fs/doc_store.dart";
import "package:eve_fit_assistant/storage/fs/user_store.dart";

class FeedbackStateStore {
  FeedbackStateStore._();

  static const int _currentVersion = 1;
  static const String _key = "feedback_state.json";
  static FeedbackState _state = FeedbackState.initial();
  static Future<void> _pendingSync = Future<void>.value();
  static DocStore? _store;

  static Future<void> init() async {
    final store = createUserDocStore(UserDataDomain.settings);
    await store.init();
    _store = store;
    _state = await _readFromStore();
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

  static Future<FeedbackState> _readFromStore() async {
    try {
      final text = await _store?.read(_key);
      if (text != null) {
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
    final store = _store;
    if (store == null) return;
    final state = _state;
    _pendingSync = _pendingSync
        .catchError((Object _, StackTrace _) {})
        .then((_) => store.write(_key, jsonEncode(state.toJson())));
  }
}
