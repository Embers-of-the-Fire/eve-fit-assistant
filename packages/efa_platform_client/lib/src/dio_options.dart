import "package:dio/dio.dart";

/// Default timeouts for the fallback Dio used when no instance is injected,
/// matching the previous `createRemoteDio` configuration so a stalled
/// connection cannot block the caller indefinitely.
BaseOptions defaultBaseOptions() => BaseOptions(
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 30),
);
