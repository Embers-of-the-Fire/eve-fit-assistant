import "dart:async";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/chat/api_key_store.dart";
import "package:eve_fit_assistant/features/chat/fit_context.dart";
import "package:eve_fit_assistant/features/chat/manual_corpus.dart";
import "package:eve_fit_assistant/features/chat/provider.dart";
import "package:eve_fit_assistant/features/chat/system_prompt.dart";
import "package:eve_fit_assistant/native/api/chat.dart" as native_chat;
import "package:eve_fit_assistant/native/api/server.dart" as native_server;
import "package:eve_fit_assistant/storage/chat/models.dart";
import "package:eve_fit_assistant/storage/chat/service.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
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
    List<ChatSegment>? streamingSegments,
    String? error,
    String? failedText,
  }) = _ChatState;
}

@riverpodSingleton
class ChatController extends _$ChatController {
  static const _uuid = Uuid();

  native_chat.ChatSession? _session;
  String? _sessionConfigFingerprint;
  native_server.FitEngine? _attachedEngine;
  bool _attrNamesAttached = false;
  Future<void>? _manualCorpusReady;
  Future<void>? _fitCallbacksReady;

  @override
  ChatState build() {
    ref.onDispose(cancelFitCallbacks);
    return const ChatState();
  }

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
        .update(
          (s) => s.copyWith(
            aiChat: s.aiChat.withConnection(
              s.aiChat.provider,
              (connection) => connection.copyWith(model: model),
            ),
          ),
        );
    _session?.setModel(model: model);
    final conversation = state.conversation;
    if (conversation != null) {
      await _persist(conversation.copyWith(model: model));
    }
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;

    state = state.copyWith(sending: true);

    final apiKey = await ref.read(aiChatApiKeyProvider.future);
    if (apiKey == null || apiKey.isEmpty) {
      state = state.copyWith(sending: false, error: "missing-api-key", failedText: trimmed);
      return;
    }

    final session = _ensureSession(apiKey);
    if (session == null) {
      state = state.copyWith(sending: false, error: "session-init-failed", failedText: trimmed);
      return;
    }

    await _syncFitContext(session);
    // The system prompt always advertises the manual tools, so the turn must
    // not start before the corpus is attached (failures degrade gracefully).
    await _manualCorpusReady;
    // Same for the app-state fit tools (`search_items`/`list_user_fits`/
    // `load_fit`): the callback channel must be open before the turn starts.
    await _fitCallbacksReady;

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
    state = ChatState(conversation: conversation, sending: true, streamingSegments: const []);
    await _persist(conversation);

    final segments = <ChatSegment>[];
    // A turn becomes stale when the user switches or clears the conversation
    // mid-stream; stale turns must not touch state or storage anymore.
    bool isStale() => state.conversation?.id != conversation.id;
    void publish() {
      if (isStale()) return;
      state = state.copyWith(streamingSegments: List.of(segments));
    }

    try {
      await for (final event in session.streamPrompt(text: trimmed)) {
        switch (event) {
          case native_chat.ChatStreamEvent_TextDelta(:final text):
            final last = segments.lastOrNull;
            if (last is ChatTextSegment) {
              segments[segments.length - 1] = ChatSegment.text(text: last.text + text);
            } else {
              segments.add(ChatSegment.text(text: text));
            }
            publish();
          case native_chat.ChatStreamEvent_ToolCallStart(:final id, :final name):
            segments.add(ChatSegment.toolCall(id: id, name: name));
            publish();
          case native_chat.ChatStreamEvent_ToolCallArgsDelta(:final id, :final delta):
            _updateToolSegment(segments, id, (s) => s.copyWith(args: s.args + delta));
            publish();
          case native_chat.ChatStreamEvent_ToolCallEnd(:final id, :final result):
            _updateToolSegment(segments, id, (s) => s.copyWith(done: true, result: result));
            publish();
          case native_chat.ChatStreamEvent_Done(:final fullText):
            if (isStale()) break;
            final done = DateTime.now().millisecondsSinceEpoch;
            final completed = _appendMessage(
              conversation,
              ChatMessage(
                id: _uuid.v4(),
                role: ChatMessageRole.assistant,
                content: fullText,
                timestamp: done,
                segments: [
                  for (final segment in segments)
                    if (segment is ChatToolCallSegment && !segment.done)
                      segment.copyWith(done: true)
                    else
                      segment,
                ],
              ),
            );
            state = ChatState(conversation: completed);
            await _persist(completed);
          case native_chat.ChatStreamEvent_Error(:final message):
            warning("chat: stream error: $message");
            if (isStale()) break;
            // The Rust session never commits a failed turn, so drop the
            // unsent user message too; retry() re-appends it via send().
            final reverted = _removeMessage(conversation, userMessage.id);
            state = ChatState(conversation: reverted, error: message, failedText: trimmed);
            await _persist(reverted);
        }
      }
    } on Object catch (e, st) {
      error("chat: stream failed", error: e, stackTrace: st);
      if (isStale()) return;
      final reverted = _removeMessage(conversation, userMessage.id);
      state = ChatState(conversation: reverted, error: e.toString(), failedText: trimmed);
      await _persist(reverted);
    }
  }

  static void _updateToolSegment(
    List<ChatSegment> segments,
    String id,
    ChatToolCallSegment Function(ChatToolCallSegment) update,
  ) {
    final index = segments.lastIndexWhere((s) => s is ChatToolCallSegment && s.id == id);
    if (index < 0) return;
    final segment = segments[index];
    if (segment is ChatToolCallSegment) {
      segments[index] = update(segment);
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
    final locale = ref.read(localeProvider).name;
    final proxy = chatProxyRoutingFor(settings.baseUrl);
    final fingerprint =
        "${settings.provider.name}|${settings.baseUrl}|${settings.model}|$apiKey|$locale|${chatProxyRoutingKey(proxy)}";
    final existing = _session;
    if (existing != null && _sessionConfigFingerprint == fingerprint) {
      return existing;
    }
    try {
      final session = native_chat.ChatSession.create(
        config: native_chat.ChatConfig(
          provider: toNativeChatProvider(settings.provider),
          apiKey: apiKey,
          baseUrl: settings.baseUrl,
          model: settings.model,
          systemPrompt: ref.read(chatSystemPromptProvider),
          language: locale,
          proxy: proxy,
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
      _attachedEngine = null;
      _attrNamesAttached = false;
      _manualCorpusReady = _attachManualCorpus(session);
      _fitCallbacksReady = registerFitCallbacks(ref, session);
      // The fit itself is re-pushed by `send()` right before each turn
      // (`await _syncFitContext`); doing it here too would only race the turn.
      return session;
    } on Object catch (e, st) {
      error("chat: failed to create session", error: e, stackTrace: st);
      return null;
    }
  }

  /// Push the bundled manual corpus into [session]; failures leave the
  /// session usable, just without the manual tools.
  Future<void> _attachManualCorpus(native_chat.ChatSession session) async {
    try {
      final docs = await ref.read(chatManualCorpusProvider.future);
      session.setManualDocs(docs: docs);
    } on Object catch (e, st) {
      warning("chat: failed to attach manual corpus: $e", stackTrace: st);
    }
  }

  /// Attach the fitting engine, the attribute-name table, and the currently
  /// attached fit to [session]. Idempotent for the engine/attribute table;
  /// the fit itself is re-pushed on every call so each turn sees fresh data.
  /// Failures leave the session usable, just without (some) fit tools.
  Future<void> _syncFitContext(native_chat.ChatSession session) async {
    try {
      final engine = ref.read(nativeFitEngineServiceProvider).engineOrNull;
      if (engine != null && !identical(engine, _attachedEngine)) {
        _attachedEngine = attachFitEngine(ref, session);
      }
      if (!_attrNamesAttached) {
        attachAttributeNames(ref, session);
        _attrNamesAttached = true;
      }
      await pushAttachedFit(ref, session);
    } on Object catch (e, st) {
      warning("chat: failed to sync fit context: $e", stackTrace: st);
    }
  }

  ChatConversation _appendMessage(ChatConversation conversation, ChatMessage message) =>
      conversation.copyWith(
        messages: [...conversation.messages, message],
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

  ChatConversation _removeMessage(ChatConversation conversation, String messageId) =>
      conversation.copyWith(
        messages: [
          for (final message in conversation.messages)
            if (message.id != messageId) message,
        ],
      );

  Future<void> _persist(ChatConversation conversation) =>
      ref.read(chatStorageServiceProvider.notifier).upsert(conversation);

  static String _makeTitle(String text) {
    final singleLine = text.replaceAll("\n", " ").trim();
    if (singleLine.length <= 30) return singleLine;
    return "${singleLine.substring(0, 30)}…";
  }
}
