import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/chat/api_key_store.dart";
import "package:eve_fit_assistant/native/api/chat.dart" as native_chat;
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class ChatApiKeyMissingException implements Exception {
  const ChatApiKeyMissingException();
}

/// Minimum interval between model-list fetches, shared by every fetch entry
/// point (settings tile, chat model picker) to avoid hammering the endpoint.
const Duration chatModelListFetchCooldown = Duration(seconds: 30);

DateTime? _lastFetchTime;

/// Remaining cooldown before the next model-list fetch is allowed.
Duration modelListFetchCooldownRemaining([DateTime? now]) {
  final last = _lastFetchTime;
  if (last == null) return Duration.zero;
  final remaining = chatModelListFetchCooldown - (now ?? DateTime.now()).difference(last);
  return remaining.isNegative ? Duration.zero : remaining;
}

@visibleForTesting
set debugModelListLastFetchTime(DateTime? value) => _lastFetchTime = value;

/// Fetches the provider's model list (`GET {baseUrl}/models` via rig's raw
/// request API with lenient parsing) and persists it as the predefined model
/// choices.
Future<List<AiChatModel>> refreshAvailableModels(WidgetRef ref) async {
  final apiKey = await ref.read(aiChatApiKeyProvider.future);
  if (apiKey == null || apiKey.isEmpty) {
    throw const ChatApiKeyMissingException();
  }
  final baseUrl = ref.read(appSettingServiceProvider).aiChat.baseUrl;
  _lastFetchTime = DateTime.now();
  final List<AiChatModel> models;
  try {
    final fetched = await native_chat.listAvailableModels(apiKey: apiKey, baseUrl: baseUrl);
    models = [for (final m in fetched) AiChatModel(id: m.id, ownedBy: m.ownedBy)];
  } on Object catch (e, st) {
    error("chat: failed to fetch model list from $baseUrl", error: e, stackTrace: st);
    rethrow;
  }
  ref
      .read(appSettingServiceProvider.notifier)
      .update(
        (s) => s.copyWith(
          aiChat: s.aiChat.copyWith(
            models: models,
            model: s.aiChat.model.isEmpty && models.isNotEmpty ? models.first.id : s.aiChat.model,
          ),
        ),
      );
  return models;
}
