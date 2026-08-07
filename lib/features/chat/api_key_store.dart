import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "api_key_store.g.dart";

class AiChatApiKeyStore {
  static const String _key = "ai_chat_api_key";

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> read() => _storage.read(key: _key);

  Future<void> write(String value) => _storage.write(key: _key, value: value);

  Future<void> clear() => _storage.delete(key: _key);
}

@riverpodSingleton
AiChatApiKeyStore aiChatApiKeyStore(Ref ref) => AiChatApiKeyStore();

@riverpodSingleton
class AiChatApiKey extends _$AiChatApiKey {
  @override
  Future<String?> build() => ref.watch(aiChatApiKeyStoreProvider).read();

  Future<void> set(String? value) async {
    final store = ref.read(aiChatApiKeyStoreProvider);
    if (value == null || value.trim().isEmpty) {
      await store.clear();
      state = const AsyncData(null);
    } else {
      await store.write(value.trim());
      state = AsyncData(value.trim());
    }
  }
}
