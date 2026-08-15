import "package:dio/dio.dart";
import "package:dio_cache_interceptor/dio_cache_interceptor.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:flutter/foundation.dart";
import "package:http_cache_hive_store/http_cache_hive_store.dart";

/// Shared HTTP cache configuration used by all remote Dio clients.
///
/// Backed by `dio_cache_interceptor` with a Hive CE store. Blobs are fetched
/// with `CachePolicy.noCache` so they remain non-managed; everything else is
/// cached and validated with the origin's ETag/Last-Modified headers.
class RemoteCache {
  RemoteCache._();

  static late final CacheStore _store;
  static late final CacheOptions _options;
  static var _initialized = false;

  /// The global cache options to attach to remote Dio instances.
  static CacheOptions get options {
    _ensureInit();
    return _options;
  }

  /// The underlying cache store. Exposed so callers can clear the cache.
  static CacheStore get store {
    _ensureInit();
    return _store;
  }

  /// Initializes the Hive-backed cache store.
  ///
  /// On web the directory must be null because Hive uses IndexedDB there.
  /// On other platforms the cache lives under the app cache directory.
  static Future<void> init() async {
    if (_initialized) return;
    final directory = kIsWeb ? null : PathProvider.cachesPath;
    _store = HiveCacheStore(directory, hiveBoxName: "efa_http_cache");
    _options = CacheOptions(store: _store);
    _initialized = true;
  }

  /// Clears all cached HTTP responses.
  static Future<void> clear() async {
    _ensureInit();
    await _store.clean();
  }

  static void _ensureInit() {
    if (!_initialized) {
      throw StateError("RemoteCache not initialized. Call RemoteCache.init() first.");
    }
  }
}

/// The cache policy used for non-managed (content-addressed) resources such as
/// blobs and APK artifacts. It bypasses cache lookup, avoids conditional
/// headers, and does not save the response.
const CachePolicy nonManagedCachePolicy = CachePolicy.noCache;

/// Extension to apply a `CachePolicy` to a request's extra options.
extension CachePolicyOptions on CachePolicy {
  Options toRequestOptions() => RemoteCache.options.copyWith(policy: this).toOptions();
}
