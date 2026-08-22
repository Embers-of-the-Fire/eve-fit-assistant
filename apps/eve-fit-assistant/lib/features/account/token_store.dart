import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "token_store.g.dart";

/// A locally held auth session: the token pair from the auth API plus the
/// access token's expiry instant (refresh tokens are rotated server-side on
/// every refresh, so the stored pair is always the latest).
class AccountSession {
  const AccountSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
}

/// Stores the platform account session and the developer-only Cloudflare
/// Access token in platform secure storage (Keychain/Keystore-backed on
/// native, encrypted on web) instead of the plain settings document.
class AccountTokenStore {
  static const String accessTokenKey = "account_access_token";
  static const String accessTokenExpiryKey = "account_access_token_expiry_ms";
  static const String refreshTokenKey = "account_refresh_token";
  static const String cfAccessTokenKey = "account_cf_access_token";

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<AccountSession?> readSession() async {
    final accessToken = await _storage.read(key: accessTokenKey);
    final refreshToken = await _storage.read(key: refreshTokenKey);
    final expiryMs = int.tryParse(await _storage.read(key: accessTokenExpiryKey) ?? "");
    if (accessToken == null || refreshToken == null || expiryMs == null) {
      return null;
    }
    return AccountSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: DateTime.fromMillisecondsSinceEpoch(expiryMs),
    );
  }

  Future<void> writeSession(AccountSession session) async {
    await _storage.write(key: accessTokenKey, value: session.accessToken);
    await _storage.write(key: refreshTokenKey, value: session.refreshToken);
    await _storage.write(
      key: accessTokenExpiryKey,
      value: session.accessTokenExpiresAt.millisecondsSinceEpoch.toString(),
    );
  }

  Future<void> clearSession() async {
    await _storage.delete(key: accessTokenKey);
    await _storage.delete(key: accessTokenExpiryKey);
    await _storage.delete(key: refreshTokenKey);
  }

  /// The `cf-access-token` used to pass the Cloudflare Access gate of the
  /// preview environment (`cloudflared access token -app=<origin>`).
  Future<String> readCfAccessToken() async =>
      (await _storage.read(key: cfAccessTokenKey))?.trim() ?? "";

  Future<void> writeCfAccessToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      await clearCfAccessToken();
      return;
    }
    await _storage.write(key: cfAccessTokenKey, value: trimmed);
  }

  Future<void> clearCfAccessToken() => _storage.delete(key: cfAccessTokenKey);

  Future<void> clearAll() async {
    await clearSession();
    await clearCfAccessToken();
  }
}

@riverpodSingleton
AccountTokenStore accountTokenStore(Ref ref) => AccountTokenStore();
