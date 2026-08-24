import "dart:convert";

import "package:dio/dio.dart";

import "package:efa_platform_client/src/dio_options.dart";

const String _authBasePath = "/platform/auth";

/// A token pair issued by the auth API (`login`, `verify-email`, `refresh`,
/// `reset-password/confirm`).
class AuthTokenPair {
  const AuthTokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory AuthTokenPair.fromJson(Map<String, dynamic> json) => AuthTokenPair(
    accessToken: json["accessToken"] as String,
    refreshToken: json["refreshToken"] as String,
    expiresIn: json["expiresIn"] as int,
  );

  final String accessToken;
  final String refreshToken;

  /// Access-token lifetime in seconds from issuance.
  final int expiresIn;
}

/// HTTP failure from the auth API; [code] is the worker's error-envelope code
/// (`invalid_credentials`, `otp_invalid`, `email_taken`, ...) when present.
class AccountApiException implements Exception {
  const AccountApiException(this.statusCode, [this.code, this.message, this.retryAfterSec]);

  final int? statusCode;
  final String? code;
  final String? message;

  /// Value of the `Retry-After` header on `429 rate_limited` responses.
  final int? retryAfterSec;

  bool get isInvalidToken => statusCode == 401 || code == "invalid_token";

  bool get isEmailUnverified => code == "email_unverified";

  @override
  String toString() =>
      "AccountApiException(${statusCode ?? "network"}"
      "${code == null ? "" : ", $code"}${message == null ? "" : ": $message"})";
}

/// Client for the platform's email+password auth API
/// (`worker/efa-platform-api`, `{origin}/platform/auth`).
///
/// All endpoints are POST with JSON bodies; errors follow the platform
/// envelope `{ "error": code, "message" }`. When a Cloudflare Access service
/// token is provided (both Client ID and Client Secret) it is sent as the
/// `CF-Access-Client-Id`/`CF-Access-Client-Secret` header pair so the request
/// can pass the Access gate protecting the preview environment.
class AccountApiClient {
  AccountApiClient({
    required this.origin,
    String? cfAccessClientId,
    String? cfAccessClientSecret,
    Dio? dio,
  }) : _dio = dio ?? Dio(defaultBaseOptions()) {
    final clientId = cfAccessClientId ?? "";
    final clientSecret = cfAccessClientSecret ?? "";
    if (clientId.isNotEmpty && clientSecret.isNotEmpty) {
      // An interceptor (not BaseOptions) so injected test transports get the
      // headers too.
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.headers["CF-Access-Client-Id"] = clientId;
            options.headers["CF-Access-Client-Secret"] = clientSecret;
            handler.next(options);
          },
        ),
      );
    }
  }

  final String origin;
  final Dio _dio;

  /// `POST /signup`: creates a pending user and sends the verification OTP.
  /// Repeating a signup for a pending address silently resends the code.
  Future<void> signup({required String email, required String password, String? locale}) =>
      _post("/signup", {"email": email, "password": password, "locale": ?locale});

  /// `POST /signup/resend`: resends the verification OTP for a pending
  /// address without requiring the password. Always 200 for unknown or
  /// active addresses (enumeration-safe); `429 rate_limited` while the
  /// 10-minute per-address resend cooldown is active.
  Future<void> signupResend({required String email, String? locale}) =>
      _post("/signup/resend", {"email": email, "locale": ?locale});

  /// `POST /verify-email`: activates a pending user and issues a token pair.
  Future<AuthTokenPair> verifyEmail({required String email, required String code}) async =>
      AuthTokenPair.fromJson(await _postJson("/verify-email", {"email": email, "code": code}));

  /// `POST /login`: issues a token pair; `403 email_unverified` when pending.
  Future<AuthTokenPair> login({required String email, required String password}) async =>
      AuthTokenPair.fromJson(await _postJson("/login", {"email": email, "password": password}));

  /// `POST /refresh`: rotates the session and returns the successor pair.
  Future<AuthTokenPair> refresh({required String refreshToken}) async =>
      AuthTokenPair.fromJson(await _postJson("/refresh", {"refreshToken": refreshToken}));

  /// `POST /logout`: revokes the session behind [refreshToken] (idempotent).
  Future<void> logout({required String refreshToken}) =>
      _post("/logout", {"refreshToken": refreshToken});

  /// `POST /deregister`: irreversibly anonymizes the account. Requires the
  /// current access token as Bearer plus the account password.
  Future<void> deregister({required String accessToken, required String password}) =>
      _post("/deregister", {"password": password}, bearer: accessToken);

  /// `POST /reset-password`: always 200; sends a reset OTP when the address
  /// belongs to an active account.
  Future<void> resetPassword({required String email, String? locale}) =>
      _post("/reset-password", {"email": email, "locale": ?locale});

  /// `POST /reset-password/confirm`: sets the new password, revokes all
  /// sessions, and issues a fresh token pair.
  Future<AuthTokenPair> resetPasswordConfirm({
    required String email,
    required String code,
    required String newPassword,
  }) async => AuthTokenPair.fromJson(
    await _postJson("/reset-password/confirm", {
      "email": email,
      "code": code,
      "newPassword": newPassword,
    }),
  );

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    String? bearer,
  }) async {
    final data = await _post(path, body, bearer: bearer);
    if (data == null) {
      throw const AccountApiException(null, null, "empty response body");
    }
    return data;
  }

  Future<Map<String, dynamic>?> _post(
    String path,
    Map<String, dynamic> body, {
    String? bearer,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        "$origin$_authBasePath$path",
        data: body,
        options: bearer == null ? null : Options(headers: {"Authorization": "Bearer $bearer"}),
      );
      return response.data;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Exception _mapDioException(DioException e) {
    final body = _decodeErrorBody(e.response?.data);
    final retryAfter = int.tryParse(e.response?.headers.value("retry-after") ?? "");
    return AccountApiException(
      e.response?.statusCode,
      body?.error,
      body?.message ?? e.message,
      retryAfter,
    );
  }

  ({String? error, String? message})? _decodeErrorBody(Object? data) {
    final Map<String, dynamic> json;
    if (data is Map<String, dynamic>) {
      json = data;
    } else if (data is String) {
      try {
        json = jsonDecode(data) as Map<String, dynamic>;
      } on Object {
        return null;
      }
    } else {
      return null;
    }
    return (error: json["error"] as String?, message: json["message"] as String?);
  }
}
