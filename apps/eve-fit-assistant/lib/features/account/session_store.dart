import "dart:convert";

import "package:efa_platform_client/efa_platform_client.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "session_store.g.dart";

/// Stores the platform session and the developer-only Cloudflare Access
/// service token in platform secure storage (Keychain/Keystore-backed on
/// native, encrypted on web) instead of the plain settings document.
///
/// The whole session lives under a single key holding one JSON document, so
/// persisting a rotated pair is a single atomic write: a failure mid-rotation
/// can never leave a partially updated (mixed-generation) credential set
/// behind. Two older layouts are still honored on read: the pre-identity
/// single-key blob (no email/user id; the user id is recovered from the JWT
/// subject and the email from the legacy settings profile cache) and the
/// per-field triple (migrated on the next write).
class SecurePlatformSessionStore implements PlatformSessionStore {
  SecurePlatformSessionStore({this._legacyEmail});

  /// Reads the email cached in app settings by logins predating the session
  /// record's email field; only consulted while migrating old blobs.
  final String? Function()? _legacyEmail;

  static const String _sessionKey = "account_session";

  // Legacy layout (pre single-key), read-only fallback for existing installs.
  static const String _legacyAccessTokenKey = "account_access_token";
  static const String _legacyAccessTokenExpiryKey = "account_access_token_expiry_ms";
  static const String _legacyRefreshTokenKey = "account_refresh_token";

  static const String _cfAccessServiceTokenKey = "account_cf_access_service_token";

  // Legacy layout (pre service-token), deleted on the next write/clear: a
  // `cloudflared access token` user JWT cannot stand in for a service token.
  static const String _legacyCfAccessTokenKey = "account_cf_access_token";

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<StoredPlatformSession?> read() async {
    final serialized = await _storage.read(key: _sessionKey);
    if (serialized != null) {
      try {
        return _sessionFromJson(jsonDecode(serialized) as Map<String, dynamic>);
      } on Object {
        // Corrupt blob: report no session instead of falling back to the
        // legacy keys, which would resurrect an older, server-side-dead pair.
        return null;
      }
    }
    return _readLegacySession();
  }

  StoredPlatformSession? _sessionFromJson(Map<String, dynamic> json) {
    final accessToken = json["accessToken"] as String;
    final refreshToken = json["refreshToken"] as String;
    final expiresAtMs = json["accessTokenExpiresAtMs"] as int;
    // Blobs written before email/user id joined the record: recover the user
    // id from the JWT subject and the email from the legacy settings cache.
    final userId = json["userId"] as String? ?? decodeJwtSubject(accessToken);
    if (userId == null || userId.isEmpty) return null;
    return StoredPlatformSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMs),
      email: json["email"] as String? ?? _legacyEmail?.call() ?? "",
      userId: userId,
    );
  }

  Future<StoredPlatformSession?> _readLegacySession() async {
    final accessToken = await _storage.read(key: _legacyAccessTokenKey);
    final refreshToken = await _storage.read(key: _legacyRefreshTokenKey);
    final expiryMs = int.tryParse(await _storage.read(key: _legacyAccessTokenExpiryKey) ?? "");
    if (accessToken == null || refreshToken == null || expiryMs == null) {
      return null;
    }
    final userId = decodeJwtSubject(accessToken);
    if (userId == null || userId.isEmpty) return null;
    return StoredPlatformSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiryMs),
      email: _legacyEmail?.call() ?? "",
      userId: userId,
    );
  }

  /// Persists [session] as one atomic write, then removes the legacy layout
  /// best-effort (a leftover legacy triple is shadowed by the new key).
  @override
  Future<void> write(StoredPlatformSession session) async {
    await _storage.write(
      key: _sessionKey,
      value: jsonEncode({
        "accessToken": session.accessToken,
        "refreshToken": session.refreshToken,
        "accessTokenExpiresAtMs": session.expiresAt.millisecondsSinceEpoch,
        "email": session.email,
        "userId": session.userId,
      }),
    );
    try {
      await _deleteLegacyKeys();
    } on Object {
      // Shadowed by the new key; retried on the next write or clear.
    }
  }

  @override
  Future<void> clear() async {
    // Delete the legacy layout first: a surviving legacy triple would be
    // resurrected by the read fallback once the current key is gone. The
    // current key is only removed after the legacy deletion succeeded, so a
    // failure here still leaves a readable session (and clear can be retried).
    await _deleteLegacyKeys();
    await _storage.delete(key: _sessionKey);
  }

  Future<void> _deleteLegacyKeys() async {
    await _storage.delete(key: _legacyAccessTokenKey);
    await _storage.delete(key: _legacyAccessTokenExpiryKey);
    await _storage.delete(key: _legacyRefreshTokenKey);
  }

  /// The Cloudflare Access service token (Client ID + Client Secret) sent as
  /// the `CF-Access-Client-Id`/`CF-Access-Client-Secret` headers to pass the
  /// Access gate of the preview environment. The pair lives under a single
  /// key holding one JSON document, so persisting it is one atomic write;
  /// empty fields mean "no token".
  Future<({String clientId, String clientSecret})> readCfAccessServiceToken() async {
    final serialized = await _storage.read(key: _cfAccessServiceTokenKey);
    if (serialized == null) return (clientId: "", clientSecret: "");
    try {
      final json = jsonDecode(serialized) as Map<String, dynamic>;
      return (
        clientId: (json["clientId"] as String).trim(),
        clientSecret: (json["clientSecret"] as String).trim(),
      );
    } on Object {
      // Corrupt blob: report no token.
      return (clientId: "", clientSecret: "");
    }
  }

  Future<void> writeCfAccessServiceToken({
    required String clientId,
    required String clientSecret,
  }) async {
    final trimmedId = clientId.trim();
    final trimmedSecret = clientSecret.trim();
    if (trimmedId.isEmpty || trimmedSecret.isEmpty) {
      await clearCfAccessServiceToken();
      return;
    }
    await _storage.write(
      key: _cfAccessServiceTokenKey,
      value: jsonEncode({"clientId": trimmedId, "clientSecret": trimmedSecret}),
    );
    await _storage.delete(key: _legacyCfAccessTokenKey);
  }

  Future<void> clearCfAccessServiceToken() async {
    await _storage.delete(key: _cfAccessServiceTokenKey);
    await _storage.delete(key: _legacyCfAccessTokenKey);
  }

  Future<void> clearAll() async {
    await clear();
    await clearCfAccessServiceToken();
  }
}

@riverpodSingleton
SecurePlatformSessionStore securePlatformSessionStore(Ref ref) => SecurePlatformSessionStore(
  legacyEmail: () => ref.read(appSettingServiceProvider).account.email,
);
