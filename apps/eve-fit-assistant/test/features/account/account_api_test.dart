@TestOn("vm")
library;

import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/features/account/account_api.dart";
import "package:flutter_test/flutter_test.dart";

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

AccountApiClient _clientWith(
  Future<ResponseBody> Function(RequestOptions options) onFetch, {
  String origin = accountApiProductionOrigin,
  String? cfAccessToken,
}) => AccountApiClient(
  origin: origin,
  cfAccessToken: cfAccessToken,
  dio: Dio(BaseOptions())..httpClientAdapter = _FakeAdapter(onFetch),
);

ResponseBody _json(Object body, [int status = 200, Map<String, List<String>>? headers]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ["application/json"],
        ...?headers,
      },
    );

const _pair = {"accessToken": "access-1", "refreshToken": "refresh-1", "expiresIn": 900};

void main() {
  group("endpoints", () {
    test("login posts to /platform/auth/login and decodes the token pair", () async {
      RequestOptions? captured;
      final client = _clientWith((options) async {
        captured = options;
        return _json(_pair);
      });

      final pair = await client.login(email: "Capsuleer@Example.com", password: "secret-pw");

      expect(captured?.path, "https://api.efa-tech.dev/platform/auth/login");
      expect(captured?.method, "POST");
      expect(captured?.data, {"email": "Capsuleer@Example.com", "password": "secret-pw"});
      expect(pair.accessToken, "access-1");
      expect(pair.refreshToken, "refresh-1");
      expect(pair.expiresIn, 900);
    });

    test("signup forwards the locale when set", () async {
      RequestOptions? captured;
      final client = _clientWith((options) async {
        captured = options;
        return _json({"userId": "u-1"}, 201);
      });

      await client.signup(email: "a@b.c", password: "secret-pw", locale: "zh");

      expect(captured?.path, "https://api.efa-tech.dev/platform/auth/signup");
      expect(captured?.data, {"email": "a@b.c", "password": "secret-pw", "locale": "zh"});
    });

    test("signup omits the locale when unset", () async {
      RequestOptions? captured;
      final client = _clientWith((options) async {
        captured = options;
        return _json({"userId": "u-1"}, 201);
      });

      await client.signup(email: "a@b.c", password: "secret-pw");

      expect(captured?.data, {"email": "a@b.c", "password": "secret-pw"});
    });

    test("signupResend posts to /platform/auth/signup/resend with the locale", () async {
      RequestOptions? captured;
      final client = _clientWith((options) async {
        captured = options;
        return _json({"ok": true});
      });

      await client.signupResend(email: "a@b.c", locale: "zh");

      expect(captured?.path, "https://api.efa-tech.dev/platform/auth/signup/resend");
      expect(captured?.method, "POST");
      expect(captured?.data, {"email": "a@b.c", "locale": "zh"});
    });

    test("verifyEmail decodes the token pair", () async {
      final client = _clientWith((options) async => _json(_pair));
      final pair = await client.verifyEmail(email: "a@b.c", code: "123456");
      expect(pair.refreshToken, "refresh-1");
    });

    test("deregister sends the access token as Bearer", () async {
      RequestOptions? captured;
      final client = _clientWith((options) async {
        captured = options;
        return _json({"ok": true});
      });

      await client.deregister(accessToken: "access-1", password: "secret-pw");

      expect(captured?.path, "https://api.efa-tech.dev/platform/auth/deregister");
      expect(captured?.headers["Authorization"], "Bearer access-1");
      expect(captured?.data, {"password": "secret-pw"});
    });

    test("logout posts the refresh token", () async {
      RequestOptions? captured;
      final client = _clientWith((options) async {
        captured = options;
        return _json({"ok": true});
      });

      await client.logout(refreshToken: "refresh-1");

      expect(captured?.path, "https://api.efa-tech.dev/platform/auth/logout");
      expect(captured?.data, {"refreshToken": "refresh-1"});
    });

    test("resetPasswordConfirm posts email, code and new password", () async {
      RequestOptions? captured;
      final client = _clientWith((options) async {
        captured = options;
        return _json(_pair);
      });

      await client.resetPasswordConfirm(email: "a@b.c", code: "123456", newPassword: "new-secret");

      expect(captured?.path, "https://api.efa-tech.dev/platform/auth/reset-password/confirm");
      expect(captured?.data, {"email": "a@b.c", "code": "123456", "newPassword": "new-secret"});
    });

    test("a custom origin replaces the production base", () async {
      RequestOptions? captured;
      final client = _clientWith((options) async {
        captured = options;
        return _json(_pair);
      }, origin: "https://efa-platform-api-preview.example.workers.dev");

      await client.login(email: "a@b.c", password: "pw");

      expect(
        captured?.path,
        "https://efa-platform-api-preview.example.workers.dev/platform/auth/login",
      );
    });

    test("the Cloudflare Access token is sent as the cf-access-token header", () async {
      RequestOptions? captured;
      final client = _clientWith((options) async {
        captured = options;
        return _json(_pair);
      }, cfAccessToken: "cf-token-1");

      await client.login(email: "a@b.c", password: "pw");

      expect(captured?.headers["cf-access-token"], "cf-token-1");
    });
  });

  group("errors", () {
    test("the error envelope is mapped to AccountApiException", () async {
      final client = _clientWith(
        (options) async =>
            _json({"error": "invalid_credentials", "message": "invalid email or password"}, 401),
      );

      await expectLater(
        () => client.login(email: "a@b.c", password: "wrong"),
        throwsA(
          isA<AccountApiException>()
              .having((e) => e.statusCode, "statusCode", 401)
              .having((e) => e.code, "code", "invalid_credentials")
              .having((e) => e.message, "message", "invalid email or password"),
        ),
      );
    });

    test("429 captures the Retry-After header", () async {
      final client = _clientWith(
        (options) async => _json(
          {"error": "rate_limited", "message": "too many requests"},
          429,
          {
            "retry-after": ["42"],
          },
        ),
      );

      await expectLater(
        () => client.signup(email: "a@b.c", password: "pw"),
        throwsA(
          isA<AccountApiException>()
              .having((e) => e.statusCode, "statusCode", 429)
              .having((e) => e.code, "code", "rate_limited")
              .having((e) => e.retryAfterSec, "retryAfterSec", 42),
        ),
      );
    });

    test("email_unverified is exposed for the login redirect", () async {
      final client = _clientWith(
        (options) async =>
            _json({"error": "email_unverified", "message": "email address is not verified"}, 403),
      );

      await expectLater(
        () => client.login(email: "a@b.c", password: "pw"),
        throwsA(isA<AccountApiException>().having((e) => e.isEmailUnverified, "", isTrue)),
      );
    });
  });

  group("decodeJwtSubject", () {
    String jwt(Map<String, dynamic> payload) {
      String segment(Object value) => base64Url.encode(utf8.encode(jsonEncode(value)));
      return "${segment({"alg": "HS256", "typ": "JWT"})}.${segment(payload)}.sig";
    }

    test("extracts the sub claim", () {
      expect(decodeJwtSubject(jwt({"sub": "user-1", "tv": 0})), "user-1");
    });

    test("extracts the sub claim from unpadded base64url segments", () {
      final unpadded = jwt({"sub": "user-1", "tv": 0}).replaceAll("=", "");
      expect(unpadded.contains("="), isFalse);
      expect(decodeJwtSubject(unpadded), "user-1");
    });

    test("returns null for malformed tokens", () {
      expect(decodeJwtSubject("not-a-jwt"), isNull);
      expect(decodeJwtSubject(jwt({"tv": 0})), isNull);
    });
  });
}
