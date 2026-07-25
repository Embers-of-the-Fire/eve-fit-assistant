import "dart:convert";

import "package:dio/dio.dart";
import "package:dio_cache_interceptor/dio_cache_interceptor.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/market_price/models/models.dart";
import "package:eve_fit_assistant/features/remote_content/cache_manager.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";

/// Freshness window for cached price responses. The upstream API updates at
/// most every 5 minutes; the server sends no cache headers, so staleness is
/// enforced client-side by forcing cache use within this window.
const marketPriceMaxStale = Duration(minutes: 5);

/// HTTP client for market price lookups.
///
/// Owns its Dio instance internally; callers never see HTTP details. Each
/// type is fetched individually (the API has no batch endpoint), so callers
/// are expected to go through the worker pool for dedup and rate limiting.
class MarketPriceClient {
  MarketPriceClient({required MarketServer server, Dio? dio})
    : _server = server,
      _dio = dio ?? createRemoteDio();

  final MarketServer _server;
  final Dio _dio;

  /// Builds the request URI for [typeId].
  Uri priceUriFor(int typeId) => Uri.parse("${_server.apiBase}$typeId.json");

  /// Fetches the estimated unit price for [typeId].
  ///
  /// Returns `null` on any network, HTTP, or parse failure — price data is
  /// best-effort and individual failures must never propagate.
  Future<double?> fetchPrice(int typeId) async {
    final uri = priceUriFor(typeId);
    try {
      final response = await _dio.getUri<String>(
        uri,
        options: RemoteCache.options
            .copyWith(
              policy: CachePolicy.forceCache,
              maxStale: marketPriceMaxStale,
              hitCacheOnNetworkFailure: true,
            )
            .toOptions()
            .copyWith(responseType: ResponseType.plain),
      );
      final data = response.data;
      if (data == null) return null;
      // The upstream API serves HTML error pages (e.g. for unknown types)
      // with a 200 status; those are simply "no price", not failures.
      if (!data.trimLeft().startsWith("{")) return null;
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) return null;
      return extractEstimatedPrice(decoded);
    } on FormatException {
      return null;
    } on Object catch (e, stackTrace) {
      debug("Market price fetch failed for type $typeId: $e", stackTrace: stackTrace);
      return null;
    }
  }

  void dispose() => _dio.close();
}
