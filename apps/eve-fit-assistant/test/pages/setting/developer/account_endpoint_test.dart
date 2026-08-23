@TestOn("vm")
library;

import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/features/account/providers.dart";
import "package:eve_fit_assistant/features/account/session_store.dart";
import "package:eve_fit_assistant/pages/setting/developer/page.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

import "../../../test_helpers.dart";

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._onFetch);

  final Future<ResponseBody> Function(RequestOptions options) _onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _onFetch(options);

  @override
  void close({bool force = false}) {}
}

/// In-memory secure-store stand-in; [SecurePlatformSessionStore] is the
/// provider's exposed type, so the fake extends it and replaces persistence.
class _MemorySessionStore extends SecurePlatformSessionStore {
  StoredPlatformSession? session;

  @override
  Future<StoredPlatformSession?> read() async => session;

  @override
  Future<void> write(StoredPlatformSession value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}

class _TestAppSettingService extends AppSettingService {
  _TestAppSettingService(this._initial);

  final AppSetting _initial;

  @override
  AppSetting build() => _initial;

  @override
  void update(AppSetting Function(AppSetting) updater) => state = updater(state);
}

String _jwt(String subject) {
  String segment(Object value) => base64Url.encode(utf8.encode(jsonEncode(value)));
  return "${segment({"alg": "HS256", "typ": "JWT"})}.${segment({"sub": subject, "tv": 0})}.sig";
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ["application/json"],
  },
);

/// Scriptable auth API: serves the cold-start rotation and records every
/// request URI so tests can assert which origin a call targeted.
class _Server {
  final List<String> uris = [];

  /// Overrides the logout response, e.g. to keep the revoke in flight while
  /// the endpoint dialog finishes closing.
  Future<ResponseBody> Function()? logoutResponder;

  Future<ResponseBody> fetch(RequestOptions options) async {
    uris.add(options.uri.toString());
    if (options.path.endsWith("/platform/auth/refresh")) {
      return _json({
        "accessToken": _jwt("user-old"),
        "refreshToken": "refresh-rotated",
        "expiresIn": 900,
      });
    }
    if (options.path.endsWith("/platform/auth/logout")) {
      final responder = logoutResponder;
      return responder != null ? responder() : _json({"ok": true});
    }
    throw StateError("unexpected request: ${options.uri}");
  }
}

const _previousOrigin = "https://preview.example.com";
const _nextOrigin = "https://next.example.com";

void main() {
  late _MemorySessionStore store;
  late _Server server;

  setUp(() {
    store = _MemorySessionStore();
    server = _Server();
    store.session = StoredPlatformSession(
      accessToken: _jwt("user-old"),
      refreshToken: "refresh-prev",
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      email: "capsuleer@example.com",
      userId: "user-old",
    );
  });

  Widget buildTile() => ProviderScope(
    overrides: [
      appSettingServiceProvider.overrideWith(
        () => _TestAppSettingService(
          const AppSetting(
            locale: Locale.zh,
            enableDebugLog: false,
            shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
            showCheckoutImpactWarnings: true,
            typeListReturnBehavior: TypeListReturnBehavior.previousPage,
            developerMode: true,
            account: AccountSetting(customOrigin: _previousOrigin),
          ),
        ),
      ),
      securePlatformSessionStoreProvider.overrideWithValue(store),
      // Mirrors the real provider's origin resolution (including the rebuild
      // on an endpoint switch) but routes HTTP through the fake server.
      platformSessionProvider.overrideWith((ref) async {
        final (:developerMode, :customOrigin) = ref.watch(
          appSettingServiceProvider.select<({bool developerMode, String customOrigin})>(
            (s) => (developerMode: s.developerMode, customOrigin: s.account.customOrigin),
          ),
        );
        final custom = customOrigin.trim();
        final origin = developerMode && custom.isNotEmpty ? custom : platformApiProductionOrigin;
        return PlatformSession(
          origin: origin,
          store: ref.watch(securePlatformSessionStoreProvider),
          dioFactory: () => Dio(BaseOptions())..httpClientAdapter = _FakeAdapter(server.fetch),
        );
      }),
    ],
    child: testApp(const Material(child: AccountApiEndpointTile())),
  );

  testWidgets("switching the endpoint revokes the session against the previous origin", (
    tester,
  ) async {
    // Keep the revoke in flight until the dialog has fully closed: the tile
    // disposes the dialog's text controller once the logout completes, and a
    // fast fake server would dispose it mid exit-animation.
    final logoutCompleter = Completer<ResponseBody>();
    server.logoutResponder = () => logoutCompleter.future;

    await tester.pumpWidget(buildTile());
    await tester.pump();

    await tester.tap(find.text("Account API endpoint"));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), _nextOrigin);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    logoutCompleter.complete(_json({"ok": true}));
    await tester.pumpAndSettle();

    // The revoke must target the endpoint the session was created against,
    // not the one the settings update just switched to.
    final logoutRequests = server.uris.where((uri) => uri.endsWith("/platform/auth/logout"));
    expect(logoutRequests, ["$_previousOrigin/platform/auth/logout"]);

    final context = tester.element(find.byType(AccountApiEndpointTile));
    final container = ProviderScope.containerOf(context);
    expect(container.read(appSettingServiceProvider).account.customOrigin, _nextOrigin);
    expect(await store.read(), isNull);
  });
}
