import "dart:async";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/chat/api_key_store.dart";
import "package:eve_fit_assistant/native/api/chat.dart" as native_chat;
import "package:eve_fit_assistant/storage/chat/models.dart";
import "package:eve_fit_assistant/storage/chat/service.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";
import "package:uuid/uuid.dart";

part "chat_controller.freezed.dart";
part "chat_controller.g.dart";

@freezed
abstract class ChatState with _$ChatState {
  const factory ChatState({
    ChatConversation? conversation,
    @Default(false) bool sending,
    String? streamingText,
    String? error,
    String? failedText,
  }) = _ChatState;
}

@riverpodSingleton
class ChatController extends _$ChatController {
  static const _uuid = Uuid();

  native_chat.ChatSession? _session;
  String? _sessionConfigFingerprint;

  @override
  ChatState build() => const ChatState();

  void newConversation() {
    _session?.clearHistory();
    state = const ChatState();
  }

  Future<void> openConversation(String id) async {
    final conversation = ref.read(chatStorageServiceProvider.notifier).byId(id);
    if (conversation == null) return;
    _session = null;
    _sessionConfigFingerprint = null;
    state = ChatState(conversation: conversation);
  }

  Future<void> setModel(String model) async {
    ref
        .read(appSettingServiceProvider.notifier)
        .update((s) => s.copyWith(aiChat: s.aiChat.copyWith(model: model)));
    _session?.setModel(model: model);
    final conversation = state.conversation;
    if (conversation != null) {
      await _persist(conversation.copyWith(model: model));
    }
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;

    final apiKey = await ref.read(aiChatApiKeyProvider.future);
    if (apiKey == null || apiKey.isEmpty) {
      state = state.copyWith(error: "missing-api-key", failedText: trimmed);
      return;
    }

    final session = _ensureSession(apiKey);
    if (session == null) {
      state = state.copyWith(error: "session-init-failed", failedText: trimmed);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: ChatMessageRole.user,
      content: trimmed,
      timestamp: now,
    );
    final conversation = _appendMessage(
      state.conversation ??
          ChatConversation(
            id: _uuid.v4(),
            title: _makeTitle(trimmed),
            model: ref.read(appSettingServiceProvider).aiChat.model,
            createdAt: now,
            updatedAt: now,
          ),
      userMessage,
    );
    state = ChatState(conversation: conversation, sending: true, streamingText: "");
    await _persist(conversation);

    final buffer = StringBuffer();
    try {
      await for (final event in session.streamPrompt(text: trimmed)) {
        switch (event) {
          case native_chat.ChatStreamEvent_TextDelta(:final text):
            buffer.write(text);
            state = state.copyWith(streamingText: buffer.toString());
          case native_chat.ChatStreamEvent_Done(:final fullText):
            final done = DateTime.now().millisecondsSinceEpoch;
            final completed = _appendMessage(
              conversation,
              ChatMessage(
                id: _uuid.v4(),
                role: ChatMessageRole.assistant,
                content: fullText,
                timestamp: done,
              ),
            );
            state = ChatState(conversation: completed);
            await _persist(completed);
          case native_chat.ChatStreamEvent_Error(:final message):
            warning("chat: stream error: $message");
            state = ChatState(
              conversation: state.conversation,
              error: message,
              failedText: trimmed,
            );
        }
      }
    } on Object catch (e, st) {
      error("chat: stream failed", error: e, stackTrace: st);
      state = ChatState(conversation: state.conversation, error: e.toString(), failedText: trimmed);
    }
  }

  Future<void> retry() async {
    final failed = state.failedText;
    if (failed == null || state.sending) return;
    state = state.copyWith(error: null, failedText: null);
    await send(failed);
  }

  void dismissError() {
    state = state.copyWith(error: null, failedText: null);
  }

  native_chat.ChatSession? _ensureSession(String apiKey) {
    final settings = ref.read(appSettingServiceProvider).aiChat;
    final fingerprint = "${settings.baseUrl}|${settings.model}|$apiKey";
    final existing = _session;
    if (existing != null && _sessionConfigFingerprint == fingerprint) {
      return existing;
    }
    try {
      final session = native_chat.ChatSession.create(
        config: native_chat.ChatConfig(
          apiKey: apiKey,
          baseUrl: settings.baseUrl,
          model: settings.model,
        ),
      );
      final conversation = state.conversation;
      if (conversation != null && conversation.messages.isNotEmpty) {
        session.restoreHistory(
          history: [
            for (final message in conversation.messages)
              native_chat.ChatHistoryMessage(
                role: switch (message.role) {
                  ChatMessageRole.user => native_chat.ChatRole.user,
                  ChatMessageRole.assistant => native_chat.ChatRole.assistant,
                },
                content: message.content,
              ),
          ],
        );
      }
      _session = session;
      _sessionConfigFingerprint = fingerprint;
      return session;
    } on Object catch (e, st) {
      error("chat: failed to create session", error: e, stackTrace: st);
      return null;
    }
  }

  ChatConversation _appendMessage(ChatConversation conversation, ChatMessage message) =>
      conversation.copyWith(
        messages: [...conversation.messages, message],
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

  Future<void> _persist(ChatConversation conversation) =>
      ref.read(chatStorageServiceProvider.notifier).upsert(conversation);

  static String _makeTitle(String text) {
    final singleLine = text.replaceAll("\n", " ").trim();
    if (singleLine.length <= 30) return singleLine;
    return "${singleLine.substring(0, 30)}…";
  }
}
