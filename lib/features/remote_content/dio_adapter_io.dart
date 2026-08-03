import "dart:io" show HttpClient;

import "package:dio/dio.dart";
import "package:dio/io.dart";

/// Applies the IO-specific connection pool tuning to [dio].
void configureConnectionPool(
  Dio dio, {
  required int maxConnectionsPerHost,
  required Duration idleTimeout,
}) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient()
      ..maxConnectionsPerHost = maxConnectionsPerHost
      ..idleTimeout = idleTimeout,
  );
}
