import "dart:io" show HttpClient;

import "package:dio/dio.dart";
import "package:dio/io.dart";
import "package:eve_fit_assistant/features/remote_content/system_proxy_io.dart";

/// Applies the IO-specific connection pool tuning to [dio].
void configureConnectionPool(
  Dio dio, {
  required int maxConnectionsPerHost,
  required Duration idleTimeout,
}) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient()
        ..maxConnectionsPerHost = maxConnectionsPerHost
        ..idleTimeout = idleTimeout;
      // No-op off Linux / when no proxy is configured: dart:io's default
      // env-var handling (http_proxy/https_proxy) applies then.
      configureSystemProxyHttpClient(client);
      return client;
    },
  );
}

/// Applies only the Linux desktop proxy resolution to [dio], leaving the
/// connection pool at dart:io defaults (for one-off download clients).
void configureSystemProxy(Dio dio) {
  if (systemProxyConfig == null) return;
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      configureSystemProxyHttpClient(client);
      return client;
    },
  );
}
