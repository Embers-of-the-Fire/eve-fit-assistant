import "package:eve_fit_assistant/storage/setting/setting.dart" show AppSettingService;
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "fit_upload_token_store.g.dart";

/// Stores the fit-snapshot upload token in platform secure storage instead of
/// the plain settings document (Keychain/Keystore-backed on native, encrypted
/// on web).
class FitUploadTokenStore {
  static const String secureKey = "fit_storage_upload_token";

  /// The legacy `settings.json` field that held the token before it moved to
  /// secure storage. Migrated and scrubbed by [AppSettingService] on load.
  static const String legacySettingsKey = "fitStorageUploadToken";

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String> read() async => await _storage.read(key: secureKey) ?? "";

  Future<void> write(String value) =>
      value.isEmpty ? clear() : _storage.write(key: secureKey, value: value);

  Future<void> clear() => _storage.delete(key: secureKey);
}

@riverpodSingleton
FitUploadTokenStore fitUploadTokenStore(Ref ref) => FitUploadTokenStore();

/// Reactive view of the stored fit-snapshot upload token ("" when unset).
@riverpodSingleton
class FitUploadToken extends _$FitUploadToken {
  @override
  Future<String> build() => ref.watch(fitUploadTokenStoreProvider).read();

  Future<void> set(String value) async {
    final trimmed = value.trim();
    await ref.read(fitUploadTokenStoreProvider).write(trimmed);
    state = AsyncData(trimmed);
  }
}
