import "dart:convert";

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

  factory AccountSession.fromJson(Map<String, dynamic> json) => AccountSession(
    accessToken: json["accessToken"] as String,
    refreshToken: json["refreshToken"] as String,
    accessTokenExpiresAt: DateTime.fromMillisecondsSinceEpoch(
      json["accessTokenExpiresAtMs"] as int,
    ),
  );

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;

  Map<String, dynamic> toJson() => {
    "accessToken": accessToken,
    "refreshToken": refreshToken,
    "accessTokenExpiresAtMs": accessTokenExpiresAt.millisecondsSinceEpoch,
  };
}

/// Stores the platform account session and the developer-only Cloudflare
/// Access token in platform secure storage (Keychain/Keystore-backed on
/// native, encrypted on web) instead of the plain settings document.
///
/// The whole session lives under a single key holding one JSON document, so
/// persisting a rotated pair is a single atomic write: a failure mid-rotation
/// can never leave a partially updated (mixed-generation) credential set
/// behind. The pre-single-key layout (one key per field) is still honored on
/// read and migrated on the next write.
class AccountTokenStore {
  static const String _sessionKey = "account_session";

  // Legacy layout (pre single-key), read-only fallback for existing installs.
  static const String _legacyAccessTokenKey = "account_access_token";
  static const String _legacyAccessTokenExpiryKey = "account_access_token_expiry_ms";
  static const String _legacyRefreshTokenKey = "account_refresh_token";

  static const String _cfAccessTokenKey = "account_cf_access_token";

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<AccountSession?> readSession() async {
    final serialized = await _storage.read(key: _sessionKey);
    if (serialized != null) {
      try {
        return AccountSession.fromJson(jsonDecode(serialized) as Map<String, dynamic>);
      } on Object {
        // Corrupt blob: report no session instead of falling back to the
        // legacy keys, which would resurrect an older, server-side-dead pair.
        return null;
      }
    }
    return _readLegacySession();
  }

  Future<AccountSession?> _readLegacySession() async {
    final accessToken = await _storage.read(key: _legacyAccessTokenKey);
    final refreshToken = await _storage.read(key: _legacyRefreshTokenKey);
    final expiryMs = int.tryParse(await _storage.read(key: _legacyAccessTokenExpiryKey) ?? "");
    if (accessToken == null || refreshToken == null || expiryMs == null) {
      return null;
    }
    return AccountSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: DateTime.fromMillisecondsSinceEpoch(expiryMs),
    );
  }

  /// Persists [session] as one atomic write, then removes the legacy layout
  /// best-effort (a leftover legacy triple is shadowed by the new key).
  Future<void> writeSession(AccountSession session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
    try {
      await _deleteLegacyKeys();
    } on Object {
      // Shadowed by the new key; retried on the next write or clear.
    }
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
    // Must not fail silently: a surviving legacy triple would be resurrected
    // by the read fallback after the new key is gone.
    await _deleteLegacyKeys();
  }

  Future<void> _deleteLegacyKeys() async {
    await _storage.delete(key: _legacyAccessTokenKey);
    await _storage.delete(key: _legacyAccessTokenExpiryKey);
    await _storage.delete(key: _legacyRefreshTokenKey);
  }

  /// The `cf-access-token` used to pass the Cloudflare Access gate of the
  /// preview environment (`cloudflared access token -app=<origin>`).
  Future<String> readCfAccessToken() async =>
      (await _storage.read(key: _cfAccessTokenKey))?.trim() ?? "";

  Future<void> writeCfAccessToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      await clearCfAccessToken();
      return;
    }
    await _storage.write(key: _cfAccessTokenKey, value: trimmed);
  }

  Future<void> clearCfAccessToken() => _storage.delete(key: _cfAccessTokenKey);

  Future<void> clearAll() async {
    await clearSession();
    await clearCfAccessToken();
  }
}

@riverpodSingleton
AccountTokenStore accountTokenStore(Ref ref) => AccountTokenStore();
