/// Placeholder file for exported remote content utilities.
///
/// The conditional fetch helpers and ETag cache have been removed in favor of
/// `dio_cache_interceptor` with a Hive-backed store. This file is kept as a
/// hook for future shared remote-content helpers without breaking imports.
///
/// If you need to fetch JSON, use `dio.getUri<String>` directly and decode the
/// response. The cache interceptor handles ETag/Last-Modified validation.
library;
