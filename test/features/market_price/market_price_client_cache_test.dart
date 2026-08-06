@TestOn("vm")
library;

import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:dio_cache_interceptor/dio_cache_interceptor.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/market_price/models/models.dart";
import "package:eve_fit_assistant/features/market_price/remote/remote.dart";
import "package:flutter_test/flutter_test.dart";

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;
  var callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    callCount++;
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body) => ResponseBody.fromString(
  body,
  200,
  headers: {
    Headers.contentTypeHeader: ["application/json"],
  },
);

const _rifterJson = '{"sell":{"min":100.0,"max":200.0,"volume":10}}';
const _rifterJsonUpdated = '{"sell":{"min":150.0,"max":250.0,"volume":12}}';

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_market_price_client_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  group("MarketPriceClient cache freshness", () {
    late MemCacheStore store;
    late CacheOptions cacheOptions;
    late _StubAdapter adapter;
    late MarketPriceClient client;
    late Uri rifterUri;

    setUp(() {
      store = MemCacheStore();
      cacheOptions = CacheOptions(store: store);
      adapter = _StubAdapter((_) async => _json(_rifterJson));
      final dio = Dio()
        ..interceptors.add(DioCacheInterceptor(options: cacheOptions))
        ..httpClientAdapter = adapter;
      client = MarketPriceClient(
        server: MarketServer.tranquility,
        dio: dio,
        cacheOptions: cacheOptions,
      );
      rifterUri = client.priceUriFor(587);
    });

    tearDown(() => client.dispose());

    /// Rewrites the stored entry's fetch time to simulate time passing.
    Future<void> ageCacheEntry(Duration age) async {
      final key = cacheOptions.keyBuilder(url: rifterUri);
      final cached = await store.get(key);
      expect(cached, isNotNull, reason: "expected a cached entry to age");
      await store.set(cached!.copyWith(responseDate: DateTime.now().toUtc().subtract(age)));
    }

    test("serves fresh entries from cache and refreshes across the boundary", () async {
      // First fetch: network.
      expect(await client.fetchPrice(587), 100.0);
      expect(adapter.callCount, 1);

      // Immediately after: cache hit.
      expect(await client.fetchPrice(587), 100.0);
      expect(adapter.callCount, 1);

      // 4 minutes old: still fresh, still no network.
      await ageCacheEntry(const Duration(minutes: 4));
      expect(await client.fetchPrice(587), 100.0);
      expect(adapter.callCount, 1);

      // Regression: reads must not slide the freshness window. The entry is
      // now 5 minutes past its *fetch* time despite having been read 1 minute
      // ago, so this read must hit the network.
      await ageCacheEntry(marketPriceMaxStale + const Duration(seconds: 1));
      expect(await client.fetchPrice(587), 100.0);
      expect(adapter.callCount, 2);

      // The refreshed entry restarts the window from its own fetch time.
      expect(await client.fetchPrice(587), 100.0);
      expect(adapter.callCount, 2);
    });

    test("repeated reads across the boundary never extend freshness", () async {
      expect(await client.fetchPrice(587), 100.0);
      expect(adapter.callCount, 1);

      // Repeatedly read the entry while aging it toward the boundary; each
      // read is within the window, but the window must stay anchored to the
      // original fetch time.
      for (final minutes in [1, 2, 3, 4]) {
        await ageCacheEntry(Duration(minutes: minutes));
        expect(await client.fetchPrice(587), 100.0, reason: "read at $minutes min");
        expect(adapter.callCount, 1, reason: "no network at $minutes min");
      }

      // With sliding freshness the previous reads would have pushed expiry
      // out to ~9 minutes; anchored freshness forces a refresh here.
      await ageCacheEntry(marketPriceMaxStale + const Duration(seconds: 30));
      expect(await client.fetchPrice(587), 100.0);
      expect(adapter.callCount, 2);
    });

    test("serves updated content after a refresh", () async {
      expect(await client.fetchPrice(587), 100.0);

      final dio = Dio();
      // Swap the handler by rebuilding the client with an updated body.
      final updatingAdapter = _StubAdapter((_) async => _json(_rifterJsonUpdated));
      dio
        ..interceptors.add(DioCacheInterceptor(options: cacheOptions))
        ..httpClientAdapter = updatingAdapter;
      final updatingClient = MarketPriceClient(
        server: MarketServer.tranquility,
        dio: dio,
        cacheOptions: cacheOptions,
      );

      // Within the window the old cached value is served...
      expect(await updatingClient.fetchPrice(587), 100.0);
      expect(updatingAdapter.callCount, 0);

      // ...and past the window the refreshed value replaces it.
      await ageCacheEntry(marketPriceMaxStale + const Duration(seconds: 1));
      expect(await updatingClient.fetchPrice(587), 150.0);
      expect(updatingAdapter.callCount, 1);
      updatingClient.dispose();
    });

    test("falls back to a stale cached entry on network failure", () async {
      expect(await client.fetchPrice(587), 100.0);
      expect(adapter.callCount, 1);

      await ageCacheEntry(marketPriceMaxStale + const Duration(minutes: 1));

      final failingDio = Dio()
        ..interceptors.add(DioCacheInterceptor(options: cacheOptions))
        ..httpClientAdapter = _StubAdapter(
          (options) async => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: "offline",
          ),
        );
      final offlineClient = MarketPriceClient(
        server: MarketServer.tranquility,
        dio: failingDio,
        cacheOptions: cacheOptions,
      );

      expect(await offlineClient.fetchPrice(587), 100.0);
      offlineClient.dispose();
    });

    test("returns null when the network fails and nothing is cached", () async {
      final failingDio = Dio()
        ..interceptors.add(DioCacheInterceptor(options: cacheOptions))
        ..httpClientAdapter = _StubAdapter(
          (options) async => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: "offline",
          ),
        );
      final offlineClient = MarketPriceClient(
        server: MarketServer.tranquility,
        dio: failingDio,
        cacheOptions: cacheOptions,
      );

      expect(await offlineClient.fetchPrice(587), isNull);
      offlineClient.dispose();
    });

    test("treats HTML error pages as no price", () async {
      final htmlDio = Dio()
        ..interceptors.add(DioCacheInterceptor(options: cacheOptions))
        ..httpClientAdapter = _StubAdapter(
          (_) async => ResponseBody.fromString(
            "<!doctype html><title>error</title>",
            200,
            headers: {
              Headers.contentTypeHeader: ["text/html"],
            },
          ),
        );
      final htmlClient = MarketPriceClient(
        server: MarketServer.tranquility,
        dio: htmlDio,
        cacheOptions: cacheOptions,
      );

      expect(await htmlClient.fetchPrice(587), isNull);
      htmlClient.dispose();
    });
  });
}
