import "dart:convert";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";

/// Production origin of the platform auth API (`worker/efa-platform-api`,
/// mounted at `/platform/auth`).
const accountApiProductionOrigin = "https://api.efa-tech.dev";

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
/// envelope `{ "error": code, "message" }`. When a Cloudflare Access token
/// is provided it is sent as the `cf-access-token` header so the request can
/// pass the Access gate protecting the preview environment.
class AccountApiClient {
  AccountApiClient({required this.origin, String? cfAccessToken, Dio? dio})
    : _dio =
          dio ??
          createRemoteDio(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
          ) {
    if (cfAccessToken != null && cfAccessToken.isNotEmpty) {
      // An interceptor (not BaseOptions) so injected test transports get the
      // header too.
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.headers["cf-access-token"] = cfAccessToken;
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

/// Decodes the `sub` (user id) claim of an access-token JWT without
/// verifying the signature (display metadata only; the server verifies).
String? decodeJwtSubject(String token) {
  final parts = token.split(".");
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final json = jsonDecode(payload);
    if (json is Map<String, dynamic>) return json["sub"] as String?;
  } on Object {
    // Malformed token; treated as undecodable.
  }
  return null;
}
