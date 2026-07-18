import "dart:io" show Platform;

import "package:dio/dio.dart";
import "package:dio_cache_interceptor/dio_cache_interceptor.dart";
import "package:eve_fit_assistant/features/remote_content/cache_manager.dart";
import "package:package_info_plus/package_info_plus.dart";

String _userAgentVersion = "0.0.0";
Future<void>? _versionLoadFuture;

Future<String> readFullAppVersion() async {
  final info = await PackageInfo.fromPlatform();
  return "${info.version}+${info.buildNumber}";
}

void _ensureVersionLoad() {
  _versionLoadFuture ??= readFullAppVersion()
      .then((version) {
        _userAgentVersion = version;
      })
      .catchError((Object _) {
        _userAgentVersion = "0.0.0";
      });
}

String get _efaUserAgent {
  _ensureVersionLoad();
  return "EFA/$_userAgentVersion (Dart; ${_platformName()})";
}

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
/// consistent headers, timeout behavior, and shared HTTP response caching.
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

  final dio = Dio(
    BaseOptions(
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      headers: headers,
    ),
  );

  dio.interceptors.add(DioCacheInterceptor(options: RemoteCache.options));

  return dio;
}
