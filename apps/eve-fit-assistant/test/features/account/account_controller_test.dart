@TestOn("vm")
library;

import "dart:convert";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/features/account/account_api.dart";
import "package:eve_fit_assistant/features/account/account_controller.dart";
import "package:eve_fit_assistant/features/account/token_store.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

class _FakeAccountTokenStore extends AccountTokenStore {
  AccountSession? session;
  String cfAccessToken = "";

  @override
  Future<AccountSession?> readSession() async => session;

  @override
  Future<void> writeSession(AccountSession value) async => session = value;

  @override
  Future<void> clearSession() async => session = null;

  @override
  Future<String> readCfAccessToken() async => cfAccessToken;
}

class _FakeAccountApiClient extends AccountApiClient {
  _FakeAccountApiClient() : super(origin: "https://test.invalid", dio: Dio());

  Object? loginError;
  AuthTokenPair? loginResult;
  Object? refreshError;
  AuthTokenPair? refreshResult;
  String? loggedOutRefreshToken;
  String? deregisterBearer;
  String? deregisterPassword;
  int refreshCalls = 0;

  @override
  Future<AuthTokenPair> login({required String email, required String password}) async {
    final error = loginError;
    if (error != null) throw error;
    return loginResult!;
  }

  @override
  Future<AuthTokenPair> refresh({required String refreshToken}) async {
    refreshCalls++;
    final error = refreshError;
    if (error != null) throw error;
    return refreshResult!;
  }

  @override
  Future<void> logout({required String refreshToken}) async => loggedOutRefreshToken = refreshToken;

  @override
  Future<void> deregister({required String accessToken, required String password}) async {
    deregisterBearer = accessToken;
    deregisterPassword = password;
  }
}

class _TestAppSettingService extends AppSettingService {
  _TestAppSettingService(this._initial);

  final AppSetting _initial;

  @override
  AppSetting build() => _initial;

  @override
  void update(AppSetting Function(AppSetting) updater) => state = updater(state);
}

AppSetting _setting() => const AppSetting(
  locale: Locale.en,
  enableDebugLog: false,
  shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
  showCheckoutImpactWarnings: true,
  typeListReturnBehavior: TypeListReturnBehavior.previousPage,
  developerMode: false,
);

String _jwt(String subject) {
  String segment(Object value) => base64Url.encode(utf8.encode(jsonEncode(value)));
  return "${segment({"alg": "HS256", "typ": "JWT"})}.${segment({"sub": subject, "tv": 0})}.sig";
}

AuthTokenPair _pair(String suffix) => AuthTokenPair(
  accessToken: _jwt("user-$suffix"),
  refreshToken: "refresh-$suffix",
  expiresIn: 900,
);

void main() {
  late _FakeAccountTokenStore store;
  late _FakeAccountApiClient api;
  late ProviderContainer container;

  AccountController controller() => container.read(accountControllerProvider.notifier);

  Future<AccountState> state() => container.read(accountControllerProvider.future);

  setUp(() {
    store = _FakeAccountTokenStore();
    api = _FakeAccountApiClient();
    // Default rotation result for the startup refresh in build().
    api.refreshResult = _pair("boot");
    container = ProviderContainer(
      overrides: [
        appSettingServiceProvider.overrideWith(() => _TestAppSettingService(_setting())),
        accountTokenStoreProvider.overrideWithValue(store),
        accountApiClientFactoryProvider.overrideWithValue(
          ({required origin, cfAccessToken}) => api,
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  test("starts signed out without a stored session", () async {
    expect(await state(), isA<AccountSignedOut>());
    expect(api.refreshCalls, 0);
  });

  AccountSession storedSession({bool expired = false}) => AccountSession(
    accessToken: _jwt("old"),
    refreshToken: "refresh-old",
    accessTokenExpiresAt: expired
        ? DateTime.now().subtract(const Duration(minutes: 5))
        : DateTime.now().add(const Duration(minutes: 10)),
  );

  void seedSignedIn({bool expired = false}) {
    store.session = storedSession(expired: expired);
    container
        .read(appSettingServiceProvider.notifier)
        .update(
          (s) => s.copyWith(
            account: s.account.copyWith(email: "capsuleer@example.com", userId: "user-old"),
          ),
        );
  }

  test("startup refresh rotates the stored pair once per cold start", () async {
    seedSignedIn();

    final result = await state();

    expect(result, isA<AccountSignedIn>());
    expect(api.refreshCalls, 1);
    expect(store.session?.refreshToken, "refresh-boot");
  });

  test("startup refresh keeps the session when the server is unreachable", () async {
    seedSignedIn();
    api.refreshError = Exception("offline");

    final result = await state();

    expect(result, isA<AccountSignedIn>());
    expect(store.session?.refreshToken, "refresh-old");
  });

  test("startup refresh signs out when the refresh token is dead", () async {
    seedSignedIn();
    api.refreshError = const AccountApiException(401, "invalid_token");

    final result = await state();

    expect(result, isA<AccountSignedOut>());
    expect(store.session, isNull);
    final account = container.read(appSettingServiceProvider).account;
    expect(account.email, isNull);
    expect(account.userId, isNull);
  });

  test("login stores the session and caches the profile", () async {
    api.loginResult = _pair("1");

    await controller().login("capsuleer@example.com", "secret-pw");

    final signedIn = await state();
    expect(signedIn, isA<AccountSignedIn>());
    expect((signedIn as AccountSignedIn).email, "capsuleer@example.com");
    expect(signedIn.userId, "user-1");
    expect(store.session?.refreshToken, "refresh-1");
    final account = container.read(appSettingServiceProvider).account;
    expect(account.email, "capsuleer@example.com");
    expect(account.userId, "user-1");
  });

  test("a login failure leaves the state signed out", () async {
    api.loginError = const AccountApiException(401, "invalid_credentials");

    await expectLater(
      () => controller().login("a@b.c", "wrong"),
      throwsA(isA<AccountApiException>()),
    );
    expect(await state(), isA<AccountSignedOut>());
    expect(store.session, isNull);
  });

  test("logout revokes the stored refresh token and clears the profile", () async {
    api.loginResult = _pair("1");
    await controller().login("capsuleer@example.com", "secret-pw");

    await controller().logout();

    expect(api.loggedOutRefreshToken, "refresh-1");
    expect(await state(), isA<AccountSignedOut>());
    expect(store.session, isNull);
    final account = container.read(appSettingServiceProvider).account;
    expect(account.email, isNull);
    expect(account.userId, isNull);
  });

  test("deregister reuses a valid access token without refreshing", () async {
    api.loginResult = _pair("1");
    await controller().login("capsuleer@example.com", "secret-pw");

    await controller().deregister("secret-pw");

    expect(api.refreshCalls, 0);
    expect(api.deregisterBearer, _jwt("user-1"));
    expect(api.deregisterPassword, "secret-pw");
    expect(await state(), isA<AccountSignedOut>());
  });

  test("deregister refreshes an expired access token and stores the rotated pair", () async {
    seedSignedIn(expired: true);
    api.refreshResult = _pair("new");

    await controller().deregister("secret-pw");

    // One rotation comes from the startup refresh; the deregister path adds
    // at most one more depending on the interleaving.
    expect(api.refreshCalls, greaterThanOrEqualTo(1));
    expect(api.deregisterBearer, _jwt("user-new"));
    // A successful deregistration clears the rotated pair again.
    expect(store.session, isNull);
  });

  test("a refresh rejected as invalid signs the session out", () async {
    seedSignedIn(expired: true);
    api.refreshError = const AccountApiException(401, "invalid_token");

    await expectLater(
      () => controller().deregister("secret-pw"),
      throwsA(isA<AccountApiException>()),
    );
    expect(await state(), isA<AccountSignedOut>());
    expect(store.session, isNull);
  });
}
