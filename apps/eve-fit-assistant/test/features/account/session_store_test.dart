@TestOn("vm")
library;

import "dart:convert";

import "package:efa_platform_client/efa_platform_client.dart";
import "package:eve_fit_assistant/features/account/session_store.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

/// In-memory mock of the flutter_secure_storage method channel, so the real
/// [SecurePlatformSessionStore] (including its on-disk layout) runs in VM
/// tests.
class _FakeSecureStorageChannel {
  final Map<String, String> backing = {};
  final List<String> writes = [];

  /// Keys whose "delete" call throws, to exercise storage failure paths.
  final Set<String> failDeletesOn = {};

  static const MethodChannel channel = MethodChannel(
    "plugins.it_nomads.com/flutter_secure_storage",
  );

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        final args = (call.arguments as Map?)!.cast<String, Object?>();
        final key = args["key"] as String?;
        switch (call.method) {
          case "read":
            return backing[key];
          case "write":
            final writtenKey = key!;
            writes.add(writtenKey);
            backing[writtenKey] = args["value"]! as String;
            return null;
          case "delete":
            if (failDeletesOn.contains(key)) {
              throw PlatformException(code: "delete-failed", message: "injected failure");
            }
            backing.remove(key);
            return null;
          case "deleteAll":
            backing.clear();
            return null;
          case "readAll":
            return Map<String, String>.of(backing);
          case "containsKey":
            return backing.containsKey(key);
        }
        return null;
      },
    );
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  }
}

String _jwt(String subject) {
  String segment(Object value) => base64Url.encode(utf8.encode(jsonEncode(value)));
  return "${segment({"alg": "HS256", "typ": "JWT"})}.${segment({"sub": subject, "tv": 0})}.sig";
}

StoredPlatformSession _session(String suffix) => StoredPlatformSession(
  accessToken: _jwt("user-$suffix"),
  refreshToken: "refresh-$suffix",
  expiresAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
  email: "user-$suffix@example.com",
  userId: "user-$suffix",
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSecureStorageChannel storage;
  late SecurePlatformSessionStore store;

  setUp(() {
    storage = _FakeSecureStorageChannel()..install();
    store = SecurePlatformSessionStore();
  });

  tearDown(() => storage.uninstall());

  test("write persists the whole session under one key", () async {
    await store.write(_session("1"));

    expect(storage.writes, ["account_session"]);
    final stored = jsonDecode(storage.backing["account_session"]!) as Map<String, dynamic>;
    expect(stored["refreshToken"], "refresh-1");
    expect(stored["accessTokenExpiresAtMs"], 1700000000000);
    expect(stored["email"], "user-1@example.com");
    expect(stored["userId"], "user-1");

    final read = await store.read();
    expect(read?.refreshToken, "refresh-1");
    expect(read?.expiresAt.millisecondsSinceEpoch, 1700000000000);
    expect(read?.email, "user-1@example.com");
    expect(read?.userId, "user-1");
  });

  test("read falls back to the legacy per-field layout, deriving the identity", () async {
    storage.backing["account_access_token"] = _jwt("user-legacy");
    storage.backing["account_refresh_token"] = "refresh-legacy";
    storage.backing["account_access_token_expiry_ms"] = "1700000000000";

    final legacyEmailStore = SecurePlatformSessionStore(legacyEmail: () => "legacy@example.com");
    final read = await legacyEmailStore.read();

    expect(read?.refreshToken, "refresh-legacy");
    expect(read?.expiresAt.millisecondsSinceEpoch, 1700000000000);
    expect(read?.userId, "user-legacy");
    expect(read?.email, "legacy@example.com");
  });

  test("read migrates the pre-identity single-key blob", () async {
    storage.backing["account_session"] = jsonEncode({
      "accessToken": _jwt("user-1"),
      "refreshToken": "refresh-1",
      "accessTokenExpiresAtMs": 1700000000000,
    });

    final legacyEmailStore = SecurePlatformSessionStore(legacyEmail: () => "legacy@example.com");
    final read = await legacyEmailStore.read();

    expect(read?.refreshToken, "refresh-1");
    expect(read?.userId, "user-1");
    expect(read?.email, "legacy@example.com");
  });

  test("write migrates and removes the legacy layout", () async {
    storage.backing["account_access_token"] = _jwt("user-legacy");
    storage.backing["account_refresh_token"] = "refresh-legacy";
    storage.backing["account_access_token_expiry_ms"] = "1700000000000";

    await store.write(_session("1"));

    expect(storage.backing.containsKey("account_session"), isTrue);
    expect(storage.backing.containsKey("account_access_token"), isFalse);
    expect(storage.backing.containsKey("account_refresh_token"), isFalse);
    expect(storage.backing.containsKey("account_access_token_expiry_ms"), isFalse);
  });

  test("a corrupt session blob reads as no session, not as the legacy fallback", () async {
    storage.backing["account_session"] = "not-json";
    storage.backing["account_access_token"] = _jwt("user-legacy");
    storage.backing["account_refresh_token"] = "refresh-legacy";
    storage.backing["account_access_token_expiry_ms"] = "1700000000000";

    expect(await store.read(), isNull);
  });

  test("clear removes both the current and the legacy layout", () async {
    await store.write(_session("1"));
    storage.backing["account_access_token"] = _jwt("user-legacy");

    await store.clear();

    expect(storage.backing, isEmpty);
    expect(await store.read(), isNull);
  });

  test("clear keeps the current session when the legacy deletion fails", () async {
    await store.write(_session("1"));
    storage.failDeletesOn.add("account_access_token");

    await expectLater(store.clear(), throwsA(isA<PlatformException>()));

    // The current session key must survive the failed legacy deletion, so the
    // read fallback cannot resurrect a surviving legacy pair after a logout.
    final read = await store.read();
    expect(read?.userId, "user-1");
  });

  test("the Cloudflare Access service token persists as one JSON document", () async {
    await store.writeCfAccessServiceToken(
      clientId: " cf-id-1.access ",
      clientSecret: " cf-secret-1 ",
    );

    final stored =
        jsonDecode(storage.backing["account_cf_access_service_token"]!) as Map<String, dynamic>;
    expect(stored, {"clientId": "cf-id-1.access", "clientSecret": "cf-secret-1"});

    final read = await store.readCfAccessServiceToken();
    expect(read.clientId, "cf-id-1.access");
    expect(read.clientSecret, "cf-secret-1");
  });

  test("writing the service token drops the legacy cf-access-token key", () async {
    storage.backing["account_cf_access_token"] = "legacy-user-jwt";

    await store.writeCfAccessServiceToken(clientId: "cf-id-1.access", clientSecret: "cf-secret-1");

    expect(storage.backing.containsKey("account_cf_access_token"), isFalse);
  });

  test("an incomplete service token clears the stored pair", () async {
    await store.writeCfAccessServiceToken(clientId: "cf-id-1.access", clientSecret: "cf-secret-1");
    await store.writeCfAccessServiceToken(clientId: "cf-id-1.access", clientSecret: "");

    expect(storage.backing.containsKey("account_cf_access_service_token"), isFalse);
    final read = await store.readCfAccessServiceToken();
    expect(read.clientId, isEmpty);
    expect(read.clientSecret, isEmpty);
  });

  test("clearAll removes the session and the service token", () async {
    await store.write(_session("1"));
    await store.writeCfAccessServiceToken(clientId: "cf-id-1.access", clientSecret: "cf-secret-1");
    storage.backing["account_cf_access_token"] = "legacy-user-jwt";

    await store.clearAll();

    expect(storage.backing, isEmpty);
  });
}
