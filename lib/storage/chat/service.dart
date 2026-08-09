import "dart:async";
import "dart:convert";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/chat/models.dart";
import "package:eve_fit_assistant/storage/fs/doc_store.dart";
import "package:eve_fit_assistant/storage/fs/user_store.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "service.g.dart";

@riverpodSingleton
class ChatStorageService extends _$ChatStorageService {
  static const String _extension = ".json";
  static DocStore? _store;
  static Future<void> _pendingSync = Future<void>.value();
  static List<ChatConversation> _conversations = [];

  static Future<void> init() async {
    final store = createUserDocStore(UserDataDomain.chat);
    await store.init();
    _store = store;
    await _readFromStore();
  }

  @override
  List<ChatConversation> build() => List.unmodifiable(_conversations);

  ChatConversation? byId(String id) {
    for (final conversation in _conversations) {
      if (conversation.id == id) return conversation;
    }
    return null;
  }

  Future<void> upsert(ChatConversation conversation) async {
    _conversations = [conversation, ..._conversations.where((c) => c.id != conversation.id)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _scheduleSync(conversation);
    state = build();
  }

  Future<void> delete(String id) async {
    _conversations = _conversations.where((c) => c.id != id).toList();
    final store = _store;
    if (store != null) {
      _pendingSync = _pendingSync.then((_) => store.delete(_key(id))).catchError(_logSyncError);
    }
    state = build();
  }

  Future<void> clear() async {
    final ids = _conversations.map((c) => c.id).toList();
    _conversations = [];
    final store = _store;
    if (store != null) {
      _pendingSync = _pendingSync
          .then<void>((_) async {
            for (final id in ids) {
              await store.delete(_key(id));
            }
          })
          .catchError(_logSyncError);
    }
    state = build();
  }

  static String _key(String id) => "$id$_extension";

  static void _logSyncError(Object error, StackTrace stackTrace) {
    warning("Chat storage sync failed: $error", stackTrace: stackTrace);
  }

  static void _scheduleSync(ChatConversation conversation) {
    final store = _store;
    if (store == null) return;
    final text = jsonEncode(conversation.toJson());
    _pendingSync = _pendingSync
        .then((_) => store.write(_key(conversation.id), text))
        .catchError(_logSyncError);
  }

  static Future<void> _readFromStore() async {
    final store = _store;
    if (store == null) return;
    final conversations = <ChatConversation>[];
    for (final key in await store.keys()) {
      if (!key.endsWith(_extension)) continue;
      final content = await store.read(key);
      if (content == null) continue;
      try {
        conversations.add(ChatConversation.fromJson(jsonDecode(content) as Map<String, dynamic>));
      } on Object catch (e) {
        warning("Failed to parse chat conversation $key: $e");
      }
    }
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _conversations = conversations;
  }
}
