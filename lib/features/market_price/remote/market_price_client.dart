import "dart:convert";

import "package:dio/dio.dart";
import "package:dio_cache_interceptor/dio_cache_interceptor.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/market_price/models/models.dart";
import "package:eve_fit_assistant/features/remote_content/cache_manager.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";

/// Freshness window for cached price responses. The upstream API updates at
/// most every 5 minutes; the server sends no cache headers, so staleness is
/// enforced client-side against the entry's fetch time.
const marketPriceMaxStale = Duration(minutes: 5);

/// HTTP client for market price lookups.
///
/// Owns its Dio instance internally; callers never see HTTP details. Each
/// type is fetched individually (the API has no batch endpoint), so callers
/// are expected to go through the worker pool for dedup and rate limiting.
class MarketPriceClient {
  MarketPriceClient({required MarketServer server, Dio? dio, CacheOptions? cacheOptions})
    : _server = server,
      _dio = dio ?? createRemoteDio(),
      _cacheOptionsOverride = cacheOptions;

  final MarketServer _server;
  final Dio _dio;
  final CacheOptions? _cacheOptionsOverride;

  /// Resolved lazily so constructing a client never touches [RemoteCache].
  CacheOptions get _cacheOptions => _cacheOptionsOverride ?? RemoteCache.options;

  /// Builds the request URI for [typeId].
  Uri priceUriFor(int typeId) => Uri.parse("${_server.apiBase}$typeId.json");

  /// Fetches the estimated unit price for [typeId].
  ///
  /// A cached entry younger than [marketPriceMaxStale] — measured from when
  /// it was fetched, never extended by reads — is served without touching the
  /// network. Older entries trigger a refresh; on network failure the stale
  /// entry is used as a fallback. Returns `null` on any network, HTTP, or
  /// parse failure — price data is best-effort and individual failures must
  /// never propagate.
  Future<double?> fetchPrice(int typeId) async {
    final uri = priceUriFor(typeId);
    try {
      final fresh = await _readFreshCache(uri);
      if (fresh != null) return fresh;

      final response = await _dio.getUri<String>(
        uri,
        options: _cacheOptions
            .copyWith(policy: CachePolicy.refreshForceCache, hitCacheOnNetworkFailure: true)
            .toOptions()
            .copyWith(responseType: ResponseType.plain),
      );
      final data = response.data;
      if (data == null) return null;
      return _parseBody(data);
    } on FormatException {
      return null;
    } on Object catch (e, stackTrace) {
      debug("Market price fetch failed for type $typeId: $e", stackTrace: stackTrace);
      return null;
    }
  }

  /// Returns the cached price for [uri] when the entry is younger than
  /// [marketPriceMaxStale], or `null` when missing, stale, or unreadable.
  ///
  /// The age is anchored to the entry's fetch time (`responseDate`), so
  /// repeated reads can never extend the freshness window.
  Future<double?> _readFreshCache(Uri uri) async {
    final store = _cacheOptions.store;
    if (store == null) return null;
    try {
      final key = _cacheOptions.keyBuilder(url: uri);
      final cached = await store.get(key);
      if (cached == null) return null;
      final age = DateTime.now().toUtc().difference(cached.responseDate);
      if (age >= marketPriceMaxStale) return null;
      final content = (await cached.readContent(
        _cacheOptions,
        readHeaders: false,
        readBody: true,
      )).content;
      if (content == null) return null;
      return _parseBody(utf8.decode(content));
    } on FormatException {
      return null;
    } on Object catch (e, stackTrace) {
      debug("Market price cache read failed for $uri: $e", stackTrace: stackTrace);
      return null;
    }
  }

  /// Parses a response body. The upstream API serves HTML error pages (e.g.
  /// for unknown types) with a 200 status; those are simply "no price", not
  /// failures.
  double? _parseBody(String data) {
    if (!data.trimLeft().startsWith("{")) return null;
    final decoded = jsonDecode(data);
    if (decoded is! Map<String, dynamic>) return null;
    return extractEstimatedPrice(decoded);
  }

  void dispose() => _dio.close();
}
