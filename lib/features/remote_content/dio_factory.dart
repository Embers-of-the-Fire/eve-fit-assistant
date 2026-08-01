import "dart:io" show HttpClient, Platform;

import "package:dio/dio.dart";
import "package:dio/io.dart";
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
  _configureConnectionPool(dio, maxConnectionsPerHost: _remoteMaxConnectionsPerHost);

  return dio;
}

/// Creates a [Dio] instance without the HTTP cache interceptor, tuned for
/// high-throughput blob downloads. Blobs are content-addressed and immutable,
/// so HTTP caching is unnecessary overhead. On Linux the pool is sized to the
/// blob download worker concurrency — a larger pool only parks extra idle
/// sockets (file descriptors), which can exhaust the fd limit on Linux
/// desktops. Other platforms keep the original, larger pool.
Dio createBlobDio({
  Duration connectTimeout = const Duration(seconds: 15),
  Duration sendTimeout = const Duration(seconds: 30),
  Duration receiveTimeout = const Duration(seconds: 30),
}) {
  final headers = <String, String>{
    "User-Agent": _efaUserAgent,
    "Accept-Encoding": "gzip, deflate",
    "Connection": "keep-alive",
  };

  final dio = Dio(
    BaseOptions(
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      headers: headers,
    ),
  );

  _configureConnectionPool(dio, maxConnectionsPerHost: _blobMaxConnectionsPerHost);

  return dio;
}

// Linux desktops often run with a low RLIMIT_NOFILE soft limit, so pool sizes
// and the idle timeout are reduced there (see utils/fd_limit.dart). Other
// platforms keep the original values (64 connections per host, 60s idle).
final int _remoteMaxConnectionsPerHost = Platform.isLinux ? 8 : 64;
final int _blobMaxConnectionsPerHost = Platform.isLinux ? 32 : 64;
final Duration _idleTimeout = Platform.isLinux
    ? const Duration(seconds: 15)
    : const Duration(seconds: 60);

void _configureConnectionPool(Dio dio, {required int maxConnectionsPerHost}) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient()
      ..maxConnectionsPerHost = maxConnectionsPerHost
      ..idleTimeout = _idleTimeout,
  );
}
