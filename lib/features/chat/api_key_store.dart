import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "api_key_store.g.dart";

class AiChatApiKeyStore {
  static const String _legacyKey = "ai_chat_api_key";

  static String _keyFor(ChatProvider provider) => "ai_chat_api_key_${provider.name}";

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> read(ChatProvider provider) async {
    final value = await _storage.read(key: _keyFor(provider));
    if (value != null) return value;
    if (provider == ChatProvider.openAiCompatible) {
      // Migrate the legacy provider-agnostic key, if any.
      final legacy = await _storage.read(key: _legacyKey);
      if (legacy != null) {
        await _storage.write(key: _keyFor(provider), value: legacy);
        await _storage.delete(key: _legacyKey);
        return legacy;
      }
    }
    return null;
  }

  Future<void> write(ChatProvider provider, String value) =>
      _storage.write(key: _keyFor(provider), value: value);

  Future<void> clear(ChatProvider provider) => _storage.delete(key: _keyFor(provider));
}

@riverpodSingleton
AiChatApiKeyStore aiChatApiKeyStore(Ref ref) => AiChatApiKeyStore();

/// The API key of the currently selected chat provider.
@riverpodSingleton
class AiChatApiKey extends _$AiChatApiKey {
  @override
  Future<String?> build() {
    final provider = ref.watch(appSettingServiceProvider.select((s) => s.aiChat.provider));
    return ref.watch(aiChatApiKeyStoreProvider).read(provider);
  }

  Future<void> set(String? value) async {
    final provider = ref.read(appSettingServiceProvider).aiChat.provider;
    final store = ref.read(aiChatApiKeyStoreProvider);
    if (value == null || value.trim().isEmpty) {
      await store.clear(provider);
      state = const AsyncData(null);
    } else {
      await store.write(provider, value.trim());
      state = AsyncData(value.trim());
    }
  }
}
