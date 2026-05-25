import "dart:io" show Platform;

import "package:dio/dio.dart";

String get _efaUserAgent => "EFA/0.0.1+1 (Dart; ${_platformName()})";

String _platformName() {
  try {
    return "${Platform.operatingSystem} ${Platform.operatingSystemVersion}";
  } on Object {
    return "unknown";
  }
}

/// Creates a [Dio] instance pre-configured for remote content fetches.
///
/// All remote content HTTP clients should use this factory to ensure
/// consistent headers, timeout behavior, and future interceptor additions.
Dio createRemoteDio({
  Duration connectTimeout = const Duration(seconds: 30),
  Duration sendTimeout = const Duration(seconds: 30),
  Duration receiveTimeout = const Duration(minutes: 2),
  Map<String, String>? extraHeaders,
}) {
  final headers = <String, String>{
    "User-Agent": _efaUserAgent,
    "Accept-Encoding": "gzip, deflate",
    if (extraHeaders != null) ...extraHeaders,
  };

  return Dio(
    BaseOptions(
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      headers: headers,
    ),
  );
}
