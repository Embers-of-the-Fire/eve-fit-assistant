import "package:dio/dio.dart";

/// Web variant: the browser manages connection pooling, so there is nothing
/// to configure. Dio's default browser adapter is used as-is.
void configureConnectionPool(
  Dio dio, {
  required int maxConnectionsPerHost,
  required Duration idleTimeout,
}) {}
