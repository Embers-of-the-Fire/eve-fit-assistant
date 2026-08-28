import "package:dio/dio.dart";

/// Web variant: the browser manages connection pooling and proxying, so
/// there is nothing to configure. Dio's default browser adapter is used
/// as-is.
void configureConnectionPool(
  Dio dio, {
  required int maxConnectionsPerHost,
  required Duration idleTimeout,
}) {}

/// Web variant: no-op (the browser applies its own proxy settings).
void configureSystemProxy(Dio dio) {}
