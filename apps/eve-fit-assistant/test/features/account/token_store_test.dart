@TestOn("vm")
library;

import "dart:convert";

import "package:eve_fit_assistant/features/account/token_store.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

/// In-memory mock of the flutter_secure_storage method channel, so the real
/// [AccountTokenStore] (including its on-disk layout) runs in VM tests.
class _FakeSecureStorageChannel {
  final Map<String, String> backing = {};
  final List<String> writes = [];

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

AccountSession _session(String suffix) => AccountSession(
  accessToken: "access-$suffix",
  refreshToken: "refresh-$suffix",
  accessTokenExpiresAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSecureStorageChannel storage;
  late AccountTokenStore store;

  setUp(() {
    storage = _FakeSecureStorageChannel()..install();
    store = AccountTokenStore();
  });

  tearDown(() => storage.uninstall());

  test("writeSession persists the whole session under one key", () async {
    await store.writeSession(_session("1"));

    expect(storage.writes, ["account_session"]);
    final stored = jsonDecode(storage.backing["account_session"]!) as Map<String, dynamic>;
    expect(stored["accessToken"], "access-1");
    expect(stored["refreshToken"], "refresh-1");
    expect(stored["accessTokenExpiresAtMs"], 1700000000000);

    final read = await store.readSession();
    expect(read?.accessToken, "access-1");
    expect(read?.refreshToken, "refresh-1");
    expect(read?.accessTokenExpiresAt.millisecondsSinceEpoch, 1700000000000);
  });

  test("readSession falls back to the legacy per-field layout", () async {
    storage.backing["account_access_token"] = "access-legacy";
    storage.backing["account_refresh_token"] = "refresh-legacy";
    storage.backing["account_access_token_expiry_ms"] = "1700000000000";

    final read = await store.readSession();

    expect(read?.accessToken, "access-legacy");
    expect(read?.refreshToken, "refresh-legacy");
    expect(read?.accessTokenExpiresAt.millisecondsSinceEpoch, 1700000000000);
  });

  test("writeSession migrates and removes the legacy layout", () async {
    storage.backing["account_access_token"] = "access-legacy";
    storage.backing["account_refresh_token"] = "refresh-legacy";
    storage.backing["account_access_token_expiry_ms"] = "1700000000000";

    await store.writeSession(_session("1"));

    expect(storage.backing.containsKey("account_session"), isTrue);
    expect(storage.backing.containsKey("account_access_token"), isFalse);
    expect(storage.backing.containsKey("account_refresh_token"), isFalse);
    expect(storage.backing.containsKey("account_access_token_expiry_ms"), isFalse);
  });

  test("a corrupt session blob reads as no session, not as the legacy fallback", () async {
    storage.backing["account_session"] = "not-json";
    storage.backing["account_access_token"] = "access-legacy";
    storage.backing["account_refresh_token"] = "refresh-legacy";
    storage.backing["account_access_token_expiry_ms"] = "1700000000000";

    expect(await store.readSession(), isNull);
  });

  test("clearSession removes both the current and the legacy layout", () async {
    await store.writeSession(_session("1"));
    storage.backing["account_access_token"] = "access-legacy";

    await store.clearSession();

    expect(storage.backing, isEmpty);
    expect(await store.readSession(), isNull);
  });
}
