import "package:dio/dio.dart";
import "package:dio_cache_interceptor/dio_cache_interceptor.dart";
import "package:eve_fit_assistant/features/remote_content/cache_manager.dart";
import "package:eve_fit_assistant/features/remote_content/dio_adapter_io.dart"
    if (dart.library.js_interop) "dio_adapter_stub.dart";
import "package:flutter/foundation.dart";
import "package:package_info_plus/package_info_plus.dart";

export "package:eve_fit_assistant/features/remote_content/dio_adapter_io.dart"
    if (dart.library.js_interop) "dio_adapter_stub.dart";

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
    return defaultTargetPlatform.name;
  } on Object {
    return "unknown";
  }
}

/// Base request headers.
///
/// On web, `User-Agent`, `Accept-Encoding`, and `Connection` are forbidden
/// headers that XHR silently ignores, so they are only set on native.
Map<String, String> _baseHeaders({Map<String, String>? extraHeaders}) => {
  if (!kIsWeb) "User-Agent": _efaUserAgent,
  if (!kIsWeb) "Accept-Encoding": "gzip, deflate",
  ...?extraHeaders,
};

/// Creates a [Dio] instance pre-configured for remote content fetches.
///
/// All remote content HTTP clients should use this factory to ensure
/// consistent headers, timeout behavior, and shared HTTP response caching.
///
/// On web the default browser adapter is used; downloads are plain small
/// requests (one GET per resource), so no connection-pool tuning applies.
Dio createRemoteDio({
  Duration connectTimeout = const Duration(seconds: 30),
  Duration sendTimeout = const Duration(seconds: 30),
  Duration receiveTimeout = const Duration(minutes: 2),
  Map<String, String>? extraHeaders,
}) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      headers: _baseHeaders(extraHeaders: extraHeaders),
    ),
  );

  dio.interceptors.add(DioCacheInterceptor(options: RemoteCache.options));
  configureConnectionPool(
    dio,
    maxConnectionsPerHost: _remoteMaxConnectionsPerHost,
    idleTimeout: _idleTimeout,
  );

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
  final dio = Dio(
    BaseOptions(
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      headers: _baseHeaders(extraHeaders: kIsWeb ? null : {"Connection": "keep-alive"}),
    ),
  );

  configureConnectionPool(
    dio,
    maxConnectionsPerHost: _blobMaxConnectionsPerHost,
    idleTimeout: _idleTimeout,
  );

  return dio;
}

// Linux desktops often run with a low RLIMIT_NOFILE soft limit, so pool sizes
// and the idle timeout are reduced there (see utils/fd_limit.dart). Other
// platforms keep the original values (64 connections per host, 60s idle).
// On web these values are unused (the browser manages its own pool).
final bool _isLinux = !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
final int _remoteMaxConnectionsPerHost = _isLinux ? 8 : 64;
final int _blobMaxConnectionsPerHost = _isLinux ? 32 : 64;
final Duration _idleTimeout = _isLinux ? const Duration(seconds: 15) : const Duration(seconds: 60);
